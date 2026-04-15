/**
 * Class ProgramRelationshipTriggerHandler
 *
 * Trigger Handler for the AccountContactRelation SObject. This class implements the TriggerInterface
 * interface to help ensure the trigger code is bulkified and all in one place.
 */
public with sharing class ProgramRelationshipTriggerHandler implements TriggerInterface
{	
	
    public Set<String> existingPairs;
    public Map<Id, Account> lps;
	// Constructor
	public ProgramRelationshipTriggerHandler()
	{
        existingPairs = new Set<String>();
        lps = new Map<Id, Account>();
	}

	/**
	 * bulkBefore
	 *
	 * This method is called prior to execution of a BEFORE trigger. Use this to cache
	 * any data required into maps prior execution of the trigger.
	 */
    
    public Map<Id,List<Program_Relationship__c>> prMap = new Map<Id,List<Program_Relationship__c>>();
	public void bulkBefore()
	{
        Set<Id> lpIds = new Set<Id>();
        Set<Id> cpIds = new Set<Id>();
        for (Program_Relationship__c pr : (List<Program_Relationship__c >)Trigger.new) {
            if (pr.Local_Program__c != null && pr.Coordinating_Program__c != null) {
                lpIds.add(pr.Local_Program__c);
                cpIds.add(pr.Coordinating_Program__c);
            }
        }
        if (!lpIds.isEmpty()) {
            lps = new Map<Id, Account>([SELECT Id, Coordinating_Program__c,Coordinating_Program__r.name FROM Account WHERE Id IN :lpIds]);
        }
        if (!lpIds.isEmpty() && !cpIds.isEmpty()) {
            
            for (Program_Relationship__c existing : [SELECT Local_Program__c,Local_Program__r.name, Coordinating_Program__c,Coordinating_Program__r.name,Relationship_Type__c,Term_End_Date__c,Coordinating_Program_Name__c,Local_Program_Name__c FROM Program_Relationship__c WHERE Local_Program__c IN :lpIds AND Coordinating_Program__c IN :cpIds AND Status__c = 'Active' AND Term_End_Date__c != null]) {
                existingPairs.add(existing.Local_Program__c + '-' + existing.Coordinating_Program__c);
                if(!prMap.containskey(existing.Coordinating_Program__c)){
                    List<Program_Relationship__c> prlist = new List<Program_Relationship__c>();
                    prlist.add(existing);
                    prMap.put(existing.Coordinating_Program__c,prlist);
                }else{
                    prMap.get(existing.Coordinating_Program__c).add(existing);
                }
                
            }
        }    
	}
	
	public void bulkAfter()
	{ 
        Set<Id> lpIds = new Set<Id>();
        for (Program_Relationship__c pr : (List<Program_Relationship__c >)Trigger.new) {
            if (pr.Local_Program__c != null && pr.Coordinating_Program__c != null ) {
                lpIds.add(pr.Local_Program__c);
            }
        }
        
        if (!lpIds.isEmpty()) {
            lps = new Map<Id, Account>([SELECT Id, Coordinating_Program__c,Coordinating_Program__r.name FROM Account WHERE Id IN :lpIds and Coordinating_Program__c = null]);
        }
            
	}
    
	public void beforeInsert(SObject so)
	{
        Program_Relationship__c pr = (Program_Relationship__c)so;
        
        if(pr.Coordinating_Program__c != null && prMap.containskey(pr.Coordinating_Program__c)){
            for(Program_Relationship__c existing : prMap.get(pr.Coordinating_Program__c)){
                if(pr.Local_Program__c <> null && pr.Local_Program__c == existing.Local_Program__c && pr.Coordinating_Program__c == existing.Coordinating_Program__c &&  pr.Relationship_Type__c == existing.Relationship_Type__c && pr.Term_End_Date__c <> null &&  pr.Term_End_Date__c.year() == existing.Term_End_Date__c.year()){
                    //pr.addError('The LP (' + pr.Local_Program_Name__c + ') is already related with the CP (' + pr.Coordinating_Program_Name__c + ') for this term year : ' +pr.Term_End_Date__c.year());
                }
            }
        }
		
		if(pr.Local_Program__c <> null && lps.containskey(pr.Local_Program__c) && lps.get(pr.Local_Program__c).Coordinating_Program__c <> null && pr.Coordinating_Program__c <> lps.get(pr.Local_Program__c).Coordinating_Program__c ){
			//pr.adderror('The LP ('+ pr.Local_Program_Name__c + ') is already related with another CP  ('+ lps.get(pr.Local_Program__c).Coordinating_Program__r.name + ') for this term year : '+pr.Term_End_Date__c.year());
		}
	}
	
	public void beforeUpdate(SObject oldSo, SObject so)
	{
        Program_Relationship__c pr = (Program_Relationship__c)so;
        Program_Relationship__c oldPr = (Program_Relationship__c)oldSo;
        
        if(pr.Status__c == 'Active' && pr.Status__c <> oldPr.Status__c &&  pr.Coordinating_Program__c != null && prMap.containskey(pr.Coordinating_Program__c)){
            for(Program_Relationship__c existing : prMap.get(pr.Coordinating_Program__c)){
                if(pr.Local_Program__c <> null && pr.Local_Program__c == existing.Local_Program__c && pr.Coordinating_Program__c == existing.Coordinating_Program__c &&  pr.Relationship_Type__c == existing.Relationship_Type__c && pr.Term_End_Date__c <> null &&  pr.Term_End_Date__c.year() == existing.Term_End_Date__c.year()){
                    //pr.addError('The LP (' + pr.Local_Program_Name__c + ') is already related with the CP (' + pr.Coordinating_Program_Name__c + ') for this term year : ' +pr.Term_End_Date__c.year());
                }
            }
        }
		
		if(pr.Local_Program__c <> null && lps.containskey(pr.Local_Program__c) && pr.Coordinating_Program__c <> lps.get(pr.Local_Program__c).Coordinating_Program__c){
			//pr.adderror('The LP ('+ pr.Local_Program_Name__c + ') is already related with another CP  ('+ lps.get(pr.Local_Program__c).Coordinating_Program__r.name + ') for this term year : '+pr.Term_End_Date__c.year());
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
	List<Account> accToBeUpdated = new List<Account>();
	public void afterInsert(SObject so)
	{
        Program_Relationship__c pr = (Program_Relationship__c)so;
        if(pr.Coordinating_Program__c <> null && pr.Local_Program__c <> null && lps.containskey(pr.Local_Program__c) && lps.get(pr.Local_Program__c).Coordinating_Program__c == null){
            Account acc = lps.get(pr.Local_Program__c);
            acc.Coordinating_Program__c = pr.Coordinating_Program__c;
            accToBeUpdated.add(acc);
        }
	}
    
	
	public void afterUpdate(SObject oldSo, SObject so)
	{
    	Program_Relationship__c pr = (Program_Relationship__c)so;
        Program_Relationship__c oldPr = (Program_Relationship__c)oldSo;
        if(pr.Status__c == 'Active' && pr.Status__c <> oldPr.Status__c && pr.Local_Program__c <> null && lps.containskey(pr.Local_Program__c) && lps.get(pr.Local_Program__c).Coordinating_Program__c == null){
            Account acc = lps.get(pr.Local_Program__c);
            acc.Coordinating_Program__c = pr.Coordinating_Program__c;
            accToBeUpdated.add(acc);
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
        if(!accToBeUpdated.isempty()){
            update accToBeUpdated;
        }
	}   
}