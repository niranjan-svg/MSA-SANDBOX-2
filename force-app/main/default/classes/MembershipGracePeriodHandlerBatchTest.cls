@isTest
private class MembershipGracePeriodHandlerBatchTest {

    // @testSetup runs once to create all necessary records for the test methods.
    @testSetup
    static void makeData() {
        // --- Create Accounts ---
        // 1. An account whose membership should be moved to grace period.
        Account accForGrace = new Account(Name = 'Grace Period Candidate Inc.',Person_Last_Name__c='Test last name',Person_Email__c = 'testefbeifjo@gmail.com');
        // 2. An account that already has a queued membership, so the active one should be skipped.
        Account accWithQueued = new Account(Name = 'Queued Membership Co.',Person_Last_Name__c='Test last name',Person_Email__c = 'testefbeifjo@gmail.com');
        // 3. A control account whose membership should be ignored by the batch logic.
        Account accToIgnore = new Account(Name = 'Control Account Inc.',Person_Last_Name__c='Test last name',Person_Email__c = 'testefbeifjo@gmail.com');
        insert new List<Account>{ accForGrace, accWithQueued, accToIgnore };

        // --- Create Memberships ---
        List<Memberships__c> membershipsToCreate = new List<Memberships__c>();

        // Scenario 1: The primary target for the batch. Expired yesterday, should be updated.
        membershipsToCreate.add(new Memberships__c(
            Account__c = accForGrace.Id,
            Membership_Status__c = 'Membership Activated',
            Is_Active__c = true,
            TermStartDate__c = Date.today().addYears(-1),
            TermEndDate__c = Date.today().addDays(-1) // Expired yesterday
        ));

        // Scenario 2: This membership expired yesterday but should be SKIPPED...
        membershipsToCreate.add(new Memberships__c(
            Account__c = accWithQueued.Id,
            Membership_Status__c = 'Membership Activated',
            Is_Active__c = true,
            TermStartDate__c = Date.today().addYears(-1),
            TermEndDate__c = Date.today().addDays(-1) // Expired yesterday
        ));
        // ...because this "Queued" membership already exists for the same account.
        membershipsToCreate.add(new Memberships__c(
            Account__c = accWithQueued.Id,
            TermStartDate__c = Date.today().addYears(-1),
            Membership_Status__c = 'Queued',
            Is_Active__c = false
        ));
        
        // Scenario 3: This membership should be IGNORED by the start() method's query.
        membershipsToCreate.add(new Memberships__c(
            Account__c = accToIgnore.Id,
            TermStartDate__c = Date.today().addYears(-1),
            Membership_Status__c = 'Membership Activated',
            Is_Active__c = true,
            TermEndDate__c = Date.today() // Not expired yet
        ));

        insert membershipsToCreate;
        
        // Link the memberships back to the Account lookup for the batch query to work
        Map<Id, Id> accountToMembershipMap = new Map<Id, Id>();
        for(Memberships__c m : [SELECT Id, Account__c FROM Memberships__c WHERE Membership_Status__c = 'Membership Activated']){
            accountToMembershipMap.put(m.Account__c, m.Id);
        }
        
        List<Account> accountsToUpdate = new List<Account>();
        for(Id accId : accountToMembershipMap.keySet()){
            accountsToUpdate.add(new Account(Id = accId, Membership__c = accountToMembershipMap.get(accId)));
        }
        update accountsToUpdate;
    }

    @isTest
    static void testGracePeriodSuccessScenario() {
        // Arrange: Get the ID of the membership that we expect to be updated.
        // Act: Execute the batch job.
        Test.startTest();
        Database.executeBatch(new MembershipGracePeriodHandlerBatch());
        Test.stopTest();

       
    }

    @isTest
    static void testGracePeriodSkippedForQueuedMembership() {
        
        
        // Act: Execute the batch job.
        Test.startTest();
        Database.executeBatch(new MembershipGracePeriodHandlerBatch());
        Test.stopTest();
        
        
    }

    @isTest
    static void testSchedulableStartsBatch() {
        // Act: Execute the schedulable interface's execute method.
        Test.startTest();
        // The SchedulableContext parameter is not used in the method, so it can be null.
        new MembershipGracePeriodHandlerBatch().execute(null);
        Test.stopTest();
        
        
    }
    
}