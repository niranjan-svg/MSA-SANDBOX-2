global class MembershipExpirationBatch implements Database.Batchable<sObject>, Database.Stateful, Schedulable {
    private Date runDate;

    // Constructor - accept a date so tests can control the 'yesterday' boundary
    public MembershipExpirationBatch() {
        this.runDate = Date.today().addDays(-1);
        System.debug('yesterday.date.>'+this.runDate);
    }

    global Database.QueryLocator start(Database.BatchableContext BC) {
        // Get memberships that should be moved to Expired
        return Database.getQueryLocator([SELECT Id, Account__c, Membership_Status__c, Is_Active__c, TermEndDate__c, Grace_Period_End_Date__c FROM Memberships__c WHERE Is_Active__c = true 
                                         AND ((Membership_Status__c = 'Membership Activated' AND TermEndDate__c <= :runDate) 
                                              OR (Membership_Status__c = 'In Grace Period' AND Grace_Period_End_Date__c <= :runDate))]);
    }

    global void execute(Database.BatchableContext BC, List<sObject> scope) {
        
        List<Memberships__c> expiredMemberships = (List<Memberships__c>)scope;
        if (expiredMemberships.isEmpty()) return;
		
        // Prepare updates for memberships becoming Expired
        List<Memberships__c> membershipsToUpdate = new List<Memberships__c>();
		Set<Id> membershipId = new Set<Id>();
        
        for (Memberships__c m : expiredMemberships) {
            membershipId.add(m.Id);
        }
        Map<Id, Id> mapOfAccMembership = new Map<Id, Id>();
        for(Account acc : [select id, Membership__c from account where Membership__c IN : membershipId]){
            mapOfAccMembership.put(acc.Membership__c, acc.id);
        }
        System.debug('mapOfAccMembership..>'+mapOfAccMembership);
        /*for (Memberships__c mem : expiredMemberships) {
            if(mapOfAccMembership.containsKey(mem.Id)){
                Id accId = mapOfAccMembership.get(mem.Id);
				membershipsToUpdate.add(new Memberships__c(Id = mem.Id, Membership_Status__c = 'Expired', Is_Active__c = false, Account__c = accId));
            }
        } */
        
        // Added by Shubham - 03/17/2026
        Map<Id, List<Memberships__c>> activeMembershipsByAcc = new Map<Id, List<Memberships__c>>();
        
        for (Memberships__c m : [SELECT Id, Account__c, Membership_Status__c, TermEndDate__c FROM Memberships__c WHERE Account__c IN :mapOfAccMembership.values()
            					AND Membership_Status__c = 'Membership Activated' AND Is_Active__c = true]) {
            if (!activeMembershipsByAcc.containsKey(m.Account__c)) {
                activeMembershipsByAcc.put(m.Account__c, new List<Memberships__c>());
            }
            activeMembershipsByAcc.get(m.Account__c).add(m);
        }
		
        // Find queued memberships for these accounts (pick most recent queued per account)
        Map<Id, Memberships__c> latestQueuedByAccount = new Map<Id, Memberships__c>();
        if (!mapOfAccMembership.isEmpty()) {
            // Query queued memberships ordered by CreatedDate desc
            List<Memberships__c> queued = [SELECT Id, Account__c, CreatedDate FROM Memberships__c
                							WHERE Account__c IN :mapOfAccMembership.values() AND Membership_Status__c = 'Queued' AND Is_Active__c = false
                							ORDER BY Account__c, CreatedDate DESC];

            // Keep the first (latest) per account
            for (Memberships__c q : queued) {
                if (!latestQueuedByAccount.containsKey(q.Account__c)) {
                    latestQueuedByAccount.put(q.Account__c, q);
                }
            }
            System.debug('latestQueuedByAccount.size..>'+latestQueuedByAccount.size());
        }
        
        Set<Id> setOfAccId = new Set<Id>();
		
        // Activate queued memberships and prepare Account updates
        List<Memberships__c> queuedToActivate = new List<Memberships__c>();
        //List<Account> accountsToUpdate = new List<Account>();
        Map<Id, Account> accountsToUpdateMap = new Map<Id, Account>();
        
        // Expire only if:
        // 1) In Grace Period -> always expire
        // 2) Membership Activated -> expire ONLY when queued exists for that account
        for (Memberships__c mem : expiredMemberships) {
            //--
            if(!mapOfAccMembership.containsKey(mem.Id)) 
                continue;
            
            Id accId = mapOfAccMembership.get(mem.Id);
            
            List<Memberships__c> activeMemList = activeMembershipsByAcc.get(accId);
            
            Memberships__c bestActive;
            
            // Find highest TermEndDate Actived membership
            if (activeMemList != null) {
                for (Memberships__c act : activeMemList) {
                    if (act.Id == mem.Id) continue;
                    
                    if (act.TermEndDate__c != null && (bestActive == null || bestActive.TermEndDate__c == null || act.TermEndDate__c > bestActive.TermEndDate__c)) {
                        bestActive = act;
                    }
                }
            }
            System.debug('100..bestActive..>'+bestActive);
            // ===============================
            // CASE 1: Activated → Grace scenario
            // ===============================
            if (mem.Membership_Status__c == 'Membership Activated') {
                
                if (bestActive != null && bestActive.TermEndDate__c > mem.TermEndDate__c) {
                    
                    // Expire current membership
                    membershipsToUpdate.add(new Memberships__c(Id = mem.Id, Membership_Status__c = 'Expired', Is_Active__c = false));
                    
                    // Assign better one to account
                    accountsToUpdateMap.put(accId, new Account(Id = accId, Membership__c = bestActive.Id));
                    
                    continue; // skip old logic
                }
            }
            
            // ===============================
            // CASE 2: Grace Period Expiry
            // ===============================
            if (mem.Membership_Status__c == 'In Grace Period') {
                System.debug('122..In Grace Period condition..>');
                membershipsToUpdate.add(new Memberships__c(Id = mem.Id, Membership_Status__c = 'Expired', Is_Active__c = false));
                
                if (bestActive != null) {
                    accountsToUpdateMap.put(accId, new Account(Id = accId, Membership__c = bestActive.Id));
                }
                continue;
            }
            
            else if (mem.Membership_Status__c == 'Membership Activated') {
                 System.debug('132..Membership Activated condition..>');
                if (latestQueuedByAccount.containsKey(accId)) {
                    membershipsToUpdate.add(new Memberships__c(Id = mem.Id, Membership_Status__c = 'Expired', Is_Active__c = false));
                    setOfAccId.add(accId);
                }
            }
            
            /** 
            
            if (!mapOfAccMembership.containsKey(mem.Id)) {
                continue;
            }

            Id accId = mapOfAccMembership.get(mem.Id);

            if (mem.Membership_Status__c == 'In Grace Period') {
                membershipsToUpdate.add(new Memberships__c(Id = mem.Id, Membership_Status__c = 'Expired', Is_Active__c = false, Account__c = accId));
                setOfAccId.add(accId);
                System.debug('setOfAccId.size..>'+setOfAccId.size());
            }
            else if (mem.Membership_Status__c == 'Membership Activated') {
			
                // if no queued membership then skip expiring
                if (latestQueuedByAccount.containsKey(accId)) {
                    membershipsToUpdate.add(new Memberships__c(Id = mem.Id, Membership_Status__c = 'Expired', Is_Active__c = false, Account__c = accId));
                    setOfAccId.add(accId);
                    System.debug('setOfAccId.sizes..>'+setOfAccId.size());
                }
            } **/
        } 
        System.debug('membershipsToUpdate..>'+membershipsToUpdate);
        
        //Added by shubham - 03/11/2026
        Set<Id> membershipIdsToUpdate = new Set<Id>();

		for(Memberships__c m : membershipsToUpdate){
    		membershipIdsToUpdate.add(m.Id);
            System.debug('membershipIdsToUpdate..>'+membershipIdsToUpdate);
		}

        List<Memberships__c> membershipList = [SELECT Id, Account__c, Membership_Status__c, Is_Active__c FROM Memberships__c WHERE Account__c IN : setOfAccId 
                                               AND ((Membership_Status__c = 'Membership Activated' AND TermEndDate__c <= :runDate) 
                                              		OR (Membership_Status__c = 'In Grace Period' AND Grace_Period_End_Date__c <= :runDate))];
        for(Memberships__c member : membershipList){
             if(!membershipIdsToUpdate.contains(member.Id)){
                membershipsToUpdate.add(member);
                membershipIdsToUpdate.add(member.Id);
                System.debug('member..>'+member);
            }
        }

        for (Id accId : latestQueuedByAccount.keySet()) {
            Memberships__c toActivate = latestQueuedByAccount.get(accId);
            queuedToActivate.add(new Memberships__c(Id = toActivate.Id, Membership_Status__c = 'Membership Activated', Is_Active__c = true));
            accountsToUpdateMap.put(accId, new Account(Id = accId, Membership__c = toActivate.Id));
            System.debug('accountsToUpdateMap..>'+accountsToUpdateMap);
        }

        // Perform bulk DML updates with partial success handling
        if (!membershipsToUpdate.isEmpty()) {
            try {
                Database.update(membershipsToUpdate, false);
            } catch (Exception ex) {
                System.debug('ERROR updating expired memberships: ' + ex.getMessage());
            }
        }

        if (!queuedToActivate.isEmpty()) {
            try {
                Database.update(queuedToActivate, false);
            } catch (Exception ex) {
                System.debug('ERROR activating queued memberships: ' + ex.getMessage());
            }
        }

        if (!accountsToUpdateMap.isEmpty()) {
            try {
                Database.update(accountsToUpdateMap.values(), false);
            } catch (Exception ex) {
                System.debug('ERROR updating accounts: ' + ex.getMessage());
            }
        }
    }

    global void finish(Database.BatchableContext BC) {
        System.debug('MembershipExpirationBatch finished.');
    }
     global void execute(SchedulableContext sc) {
        // Run the batch with chunk size 200
        MembershipExpirationBatch batch = new MembershipExpirationBatch();
        Database.executeBatch(batch, 200);
    }
}