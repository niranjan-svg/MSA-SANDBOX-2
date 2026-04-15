/**
 * Class MembershipTriggerHandler
 *
 * Trigger Handler for the MembershipTriggerHandler SObject. This class implements the TriggerInterface
 * interface to help ensure the trigger code is bulkified and all in one place.
 */
public with sharing class MembershipTriggerHandler implements TriggerInterface
{	
        
	// Constructor
	public MembershipTriggerHandler()
	{
        
	}

	/**
	 * bulkBefore
	 *
	 * This method is called prior to execution of a BEFORE trigger. Use this to cache
	 * any data required into maps prior execution of the trigger.
	 */
	public Map<Id,Memberships__c> ingraceMembershipMap = new Map<Id,Memberships__c>(); 
	public void bulkBefore()
	{
		Set<Id> accids = new Set<Id>();
        for(Memberships__c mem: (List<Memberships__c>)Trigger.new){
            if(mem.Related_Account__c <> null){
				accids.add(mem.Related_Account__c);
			}
			
        }
		if(!accids.isempty()){
			for(Memberships__c mem: [select id,Related_Account__c,Membership_Status__c,Is_Active__c from Memberships__c where Related_Account__c IN: accids and Membership_Status__c = 'In Grace Period']){
				if(mem.Membership_Status__c == 'In Grace Period'){
					ingraceMembershipMap.put(mem.Related_Account__c,mem);
				}
			}
		}
	}
	
	public void bulkAfter()
	{ 
        Set<Id> accids = new Set<Id>();
        if(Trigger.new <> null){
            for(Memberships__c mem: (List<Memberships__c>)Trigger.new){
                if(mem.Related_Account__c <> null){
                    accids.add(mem.Related_Account__c);
                }
            }
        }
		if(!accids.isempty()){
			for(Memberships__c mem: [select id,Related_Account__c,Membership_Status__c,Is_Active__c from Memberships__c where Related_Account__c IN: accids and Membership_Status__c = 'In Grace Period']){
				if(mem.Membership_Status__c == 'In Grace Period'){
					ingraceMembershipMap.put(mem.Related_Account__c,mem);
				}
			}
		}
	}
    
	public void beforeInsert(SObject so)
	{
        Memberships__c membership = (Memberships__c)so;
        if(membership.Related_Account__c == null && membership.Account__c <> null){
             membership.Related_Account__c = membership.Account__c;
        }
        if(membership.Related_Account_Id__c <> null && membership.Membership_Account_Id__c == null){
             membership.Membership_Account_Id__c = membership.Related_Account_Id__c;
        }
	}
	
	public void beforeUpdate(SObject oldSo, SObject so)
	{
        Memberships__c membership = (Memberships__c)so;
        Memberships__c oldMembership = (Memberships__c)oldSo;
        if(membership.Related_Account__c == null && membership.Account__c <> null){
             membership.Related_Account__c = membership.Account__c;
        }
        if(membership.Related_Account_Id__c <> null && membership.Membership_Account_Id__c == null){
             membership.Membership_Account_Id__c = membership.Related_Account_Id__c;
        }
        if(membership.Membership_Status__c <> oldMembership.Membership_Status__c && membership.Membership_Status__c == 'Membership Activated'){
            membership.Is_Active__c = true;
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
	
	public void afterInsert(SObject so)
	{
        
	}
    
	List<Account> updateAccountBanner = new List<Account>();
	List<Memberships__c> membershipToBeExpired = new List<Memberships__c>();
	public void afterUpdate(SObject oldSo, SObject so)
	{
        Memberships__c membership = (Memberships__c)so;
        Memberships__c oldMembership = (Memberships__c)oldSo;
        if(membership.Membership_Status__c <> oldMembership.Membership_Status__c && membership.Membership_Status__c == 'Membership Activated' && membership.Related_Account__c <> null){
            Account acc = new Account();
            acc.Id = membership.Related_Account__c;
            acc.Membership__c = membership.Id;
            updateAccountBanner.add(acc);
			System.debug('ingraceMembershipMap.containskey(membership.Related_Account__c)...>> '+ingraceMembershipMap.containskey(membership.Related_Account__c));
			if(ingraceMembershipMap.containskey(membership.Related_Account__c)){
				Memberships__c ingraceMembership = ingraceMembershipMap.get(membership.Related_Account__c); 
                System.debug('ingraceMembershipMap.get(membership.Related_Account__c)..>>> '+ingraceMembershipMap.get(membership.Related_Account__c));
				ingraceMembership.Membership_Status__c = 'Expired';
				ingraceMembership.Is_Active__c = false;
				membershipToBeExpired.add(ingraceMembership);
			}
        }
	}
	
	public void afterDelete(SObject so)
	{
        
	}
	
	/**
	 * andFinally
	 *
	 * This method is called once all records have been processed by the trigger. Use this 
	 * method to accomplish any final operations such as creation or updates of other records.
	 */
	public void andFinally(){
        if(!updateAccountBanner.isEmpty()){
            update updateAccountBanner;
        }
		System.debug('membershipToBeExpired...>> '+membershipToBeExpired.size());
		if(!membershipToBeExpired.isEmpty()){
            update membershipToBeExpired;
        }
	}   
}