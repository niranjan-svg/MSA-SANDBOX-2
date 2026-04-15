/**
 * Class AccountContactRelationTriggerHandler
 *
 * Trigger Handler for the AccountContactRelation SObject. This class implements the TriggerInterface
 * interface to help ensure the trigger code is bulkified and all in one place.
 */
public with sharing class AccountContactRelationTriggerHandler implements TriggerInterface
{	
	
	public static boolean isFirstRun = false;
    Set<String> acrRoles = new Set<String>();
        
	// Constructor
	public AccountContactRelationTriggerHandler()
	{
        acrRoles.add('Admin');
        acrRoles.add('Sub Member');
        acrRoles.add('Sub-Member');
        acrRoles.add('Primary Contact');
	}

	/**
	 * bulkBefore
	 *
	 * This method is called prior to execution of a BEFORE trigger. Use this to cache
	 * any data required into maps prior execution of the trigger.
	 */
    
    Map<Id,Decimal> maxSubMemberCountForAccount = new Map<Id,Decimal>();
    Map<Id,Decimal> acrCountForRelatedAccount = new Map<Id,Decimal>();
    
    Map<Id, Contact> contactMap = new Map<Id, Contact>();
	Set<Id> contactIdsToFetch = new Set<Id>();
   
	Set<Id> accountIdsToUpdate = new Set<Id>();
    List<ACR_History__c> acrHistoryList = new List<ACR_History__c>();
    
	public void bulkBefore()
	{
        Set<Id> accids = new Set<Id>();
        
        for(AccountContactRelation acr: (List<AccountContactRelation>)Trigger.new){
            accids.add(acr.AccountId);
        }
        for(Account acc : [Select id,Membership__r.Membership_Type__r.Max_Sub_Members__c from Account where Id IN: accids]){
            if(acc.Membership__r.Membership_Type__r.Max_Sub_Members__c <> null){
                maxSubMemberCountForAccount.put(acc.Id,acc.Membership__r.Membership_Type__r.Max_Sub_Members__c);
            }
            
        }
        
        for (AggregateResult ar : [SELECT AccountId accId, COUNT(Id) acrCount FROM AccountContactRelation WHERE AccountId IN :accids
            						AND Roles IN :acrRoles
            						GROUP BY AccountId]) 
        {
            acrCountForRelatedAccount.put((Id) ar.get('accId'), (Decimal) ar.get('acrCount'));
        }
	}
	public Map<Id,Account> accountWithPrimaryContactMap = new Map<Id,Account>();
    public Map<Id,List<AccountContactRelation>> primaryContactACRMap = new Map<Id,List<AccountContactRelation>>();
	Set<Id> acrIds = new Set<Id>();
	public void bulkAfter()
	{ 
        Set<Id> accids = new Set<Id>();
        if(!Trigger.isDelete){
            for(AccountContactRelation acr: (List<AccountContactRelation>)Trigger.new){
                accids.add(acr.AccountId);
                 if(acr.ContactId != null){
        			contactIdsToFetch.add(acr.ContactId);
    			}
            }
        } else{
            for(AccountContactRelation acr: (List<AccountContactRelation>)Trigger.old){
                accids.add(acr.AccountId);
                 if(acr.ContactId != null){
        			contactIdsToFetch.add(acr.ContactId);
    			}
                System.debug('deleteACR..>');
            }
        }
        
		
        for (AggregateResult ar : [SELECT AccountId accId, COUNT(Id) acrCount FROM AccountContactRelation WHERE AccountId IN :accids
            						AND Roles IN :acrRoles
            						GROUP BY AccountId]) 
        {
            acrCountForRelatedAccount.put(
                (Id) ar.get('accId'),
                (Decimal) ar.get('acrCount')
            );
        }
        Set<String> primaryRole = new Set<String>();
        primaryRole.add('Primary Contact');
        if(!accids.isEmpty()){
            accountWithPrimaryContactMap = new Map<Id,Account>([select id,Primary_Contact__c from Account where Primary_Contact__c <> null and Id IN :accids]);
            for(AccountContactRelation acr : [Select id,Roles,AccountId FROM AccountContactRelation WHERE AccountId IN :accids AND Roles IN :primaryRole]){
                //primaryContactACRMap.put(acr.AccountId , acr);
				acrIds.add(acr.Id);
                if (!primaryContactACRMap.containsKey(acr.AccountId)) {
                    List<AccountContactRelation> acrlist = new List<AccountContactRelation>();
                    acrlist.add(acr);
                    primaryContactACRMap.put(acr.AccountId, acrlist);
                }else{
                    primaryContactACRMap.get(acr.AccountId).add(acr);
                }
            }
            System.debug('primaryContactACRMap..>> '+primaryContactACRMap);
        }
        if(!contactIdsToFetch.isEmpty()){
    		contactMap = new Map<Id, Contact>([SELECT Id, FirstName, LastName, Email FROM Contact WHERE Id IN :contactIdsToFetch]);
		}
	}
    
	public void beforeInsert(SObject so)
	{
        //maxSubMemberCountForAccount
        //acrCountForRelatedAccount
		AccountContactRelation acr = (AccountContactRelation)so;
        if(acrRoles.contains(acr.Roles) && acrCountForRelatedAccount.containskey(acr.AccountId) && maxSubMemberCountForAccount.containskey(acr.AccountId) && acrCountForRelatedAccount.get(acr.AccountId) >= maxSubMemberCountForAccount.get(acr.AccountId)){
            acr.addError('You have reached Max Number of Sub Members. You can add up to '+maxSubMemberCountForAccount.get(acr.AccountId));
        }
		accountIdsToUpdate.add(acr.AccountId);
	}
	
	public void beforeUpdate(SObject oldSo, SObject so)
	{
        AccountContactRelation acr = (AccountContactRelation)so;
        AccountContactRelation oldAcr = (AccountContactRelation)oldSo;
        Boolean oldCounted = acrRoles.contains(oldAcr.Roles);
		Boolean newCounted = acrRoles.contains(acr.Roles);
        
        if(acr.Roles <> null && newCounted && !oldCounted && acrRoles.contains(acr.Roles) && acr.Roles <> oldAcr.Roles && acrCountForRelatedAccount.containskey(acr.AccountId) && maxSubMemberCountForAccount.containskey(acr.AccountId) && acrCountForRelatedAccount.get(acr.AccountId) >= maxSubMemberCountForAccount.get(acr.AccountId)){
            acr.addError('You have reached Max Number of Sub Members. You can add up to '+maxSubMemberCountForAccount.get(acr.AccountId));
        }
	}
	
	/**
	 * beforeDelete
	 *
	 * This method is called iteratively for each record to be deleted during a BEFORE
	 * trigger.
	 */
	public void beforeDelete(SObject so)
	{	
		
	}
	Set<Account> accsToUpdate = new Set<Account>();
    List<Account> accToUpdatePrimaryContact = new List<Account>();
    List<AccountContactRelation> acrToBeUpdated = new List<AccountContactRelation>();
    
	public void afterInsert(SObject so)
	{
        AccountContactRelation acr = (AccountContactRelation)so;
        //TriggerFactoryUtility.isFirstRun = false;
        if(acrRoles.contains(acr.Roles) && acrCountForRelatedAccount.containskey(acr.AccountId)){
            Account acc = new Account();
            acc.id = acr.AccountId;
            acc.Rollup_Sub_Member__c = acrCountForRelatedAccount.get(acr.AccountId);
            
			if(acr.Roles.contains('Primary Contact')){
				acc.Primary_Contact__c = acr.ContactId;
                    if(contactMap.containsKey(acr.ContactId)){
                        Contact con = contactMap.get(acr.ContactId);
                        
                        acc.Person_First_Name__c = con.FirstName;
                        acc.Person_Last_Name__c = con.LastName;
                        acc.Person_Email__c = con.Email;
                        System.debug('con..>'+con);
                    }
				
				if(primaryContactACRMap.containskey(acr.AccountId)){
					List<AccountContactRelation> existingPrimaryACR = primaryContactACRMap.get(acr.AccountId);
                    for(AccountContactRelation existing : existingPrimaryACR){
                        if(existing.Id <> acr.Id){
                            existing.Roles = 'Admin';
							acrToBeUpdated.add(existing);
                        }   
                    }
				}
			}
            accsToUpdate.add(acc);
        }
        // ACR History - CREATE
        ACR_History__c hist = new ACR_History__c();
        hist.Account__c = acr.AccountId;
        hist.Contact__c = acr.ContactId;
        hist.AccountContactRelation__c = acr.Id;
        
        hist.Field__c = 'ACR Created';
        hist.Old_Value__c = null;
        hist.New_Value__c = acr.Roles;
        
        acrHistoryList.add(hist);
        System.debug('acrHistoryList..>'+acrHistoryList);
	}
    
	
	public void afterUpdate(SObject oldSo, SObject so)
	{
        AccountContactRelation acr = (AccountContactRelation)so;
        AccountContactRelation oldAcr = (AccountContactRelation)oldSo;
        
        if((acrRoles.contains(acr.Roles) || acrRoles.contains(oldAcr.Roles)) && acr.Roles <> oldAcr.Roles && acrCountForRelatedAccount.containskey(acr.AccountId)){
            Account acc = new Account();
            acc.id = acr.AccountId;
            acc.Rollup_Sub_Member__c = acrCountForRelatedAccount.get(acr.AccountId);
            
			if(acr.Roles <> null && acr.Roles.contains('Primary Contact')){
				acc.Primary_Contact__c = acr.ContactId;
                
                if(contactMap.containsKey(acr.ContactId)){
                    Contact con = contactMap.get(acr.ContactId);
                    
                    acc.Person_First_Name__c = con.FirstName;
                    acc.Person_Last_Name__c = con.LastName;
                    acc.Person_Email__c = con.Email;
                    System.debug('contact..>'+con);
                }
                
				System.debug('acrIds.contains(acr.Id)..>> '+acrIds.contains(acr.Id));
                System.debug('primaryContactACRMap.containskey(acr.AccountId)..>> '+primaryContactACRMap.containskey(acr.AccountId));
				if(primaryContactACRMap.containskey(acr.AccountId)){
					List<AccountContactRelation> existingPrimaryACR = primaryContactACRMap.get(acr.AccountId);
                    for(AccountContactRelation existing : existingPrimaryACR){
                        if(existing.Id <> acr.Id){
                            existing.Roles = 'Admin';
							acrToBeUpdated.add(existing);
                        }   
                    }
				}
			}
            accsToUpdate.add(acc);
        }       
        if(acr.Roles <> oldAcr.Roles){
         	// ACR History - UPDATE (Roles)
            ACR_History__c hist = new ACR_History__c();
            hist.Account__c = acr.AccountId;
            hist.Contact__c = acr.ContactId;
            hist.AccountContactRelation__c = acr.Id;
            
            hist.Field__c = 'Roles';
            hist.Old_Value__c = oldAcr.Roles;
            hist.New_Value__c = acr.Roles;
            
            acrHistoryList.add(hist);
            System.debug('acrHistoryList..245..>'+acrHistoryList);   
        }
	}
	
	public void afterDelete(SObject so)
	{
        AccountContactRelation acr = (AccountContactRelation)so;
        System.debug('acr..>'+acr.Roles+'acrCountForRelatedAccount..>'+acrCountForRelatedAccount);
        if(acrRoles.contains(acr.Roles) && acrCountForRelatedAccount.containskey(acr.AccountId)){
            
            Account acc = new Account();
            acc.id = acr.AccountId;
            acc.Rollup_Sub_Member__c = acrCountForRelatedAccount.get(acr.AccountId);
            accsToUpdate.add(acc);
            System.debug('acrCountForRelatedAccount...>'+acrCountForRelatedAccount.get(acr.AccountId));
        }
        // ACR History - DELETE
        ACR_History__c hist = new ACR_History__c();
        
        hist.Account__c = acr.AccountId;
        hist.Contact__c = acr.ContactId;
        hist.AccountContactRelation__c = acr.Id;
        
        hist.Field__c = 'ACR Deleted';
        hist.Old_Value__c = acr.Roles;  
        hist.New_Value__c = null;
        
        acrHistoryList.add(hist);
	}
	
	/**
	 * andFinally
	 *
	 * This method is called once all records have been processed by the trigger. Use this 
	 * method to accomplish any final operations such as creation or updates of other records.
	 */
	public void andFinally(){
		System.debug('accsToUpdate..>'+accsToUpdate.size());
		if (!accsToUpdate.isEmpty()){
            List<Account> accList = new List<Account>(accsToUpdate);
			update accList;
		}
        System.debug('acrToBeUpdated..>'+acrToBeUpdated.size());
        if(!acrToBeUpdated.isEmpty()){
            update acrToBeUpdated;
        }
        // Insert ACR History
		if(!acrHistoryList.isEmpty()){
            System.debug('acrHistoryList.size..>'+acrHistoryList.size());
    		insert acrHistoryList;
		}
	}   
}