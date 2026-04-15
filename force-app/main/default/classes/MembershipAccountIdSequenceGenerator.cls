/**
 * MembershipAccountIdSequenceGenerator
 **/
public with sharing class MembershipAccountIdSequenceGenerator {

    /**
     * Assigns Account_Id_Number__c to Accounts where it is null
     * Call this from a BEFORE trigger
     */
    public static void assignAccountNumbers(List<Account> incomingAccounts) {
        if (incomingAccounts == null || incomingAccounts.isEmpty()) {
            return;
        }
		//System.debug('incomingAccounts..>'+incomingAccounts);
        // Filter only accounts that need a number
        List<Account> accountsNeedingNumbers = new List<Account>();
        for (Account acc : incomingAccounts) {
            if (acc != null && acc.Account_Id_Number__c == null) {
                accountsNeedingNumbers.add(acc);
            }
        }

        if (accountsNeedingNumbers.isEmpty()) {
            return;
        }

        // Fetch current max value once
        Decimal currentMax = fetchCurrentMaxAccountNumber();

        // Assign sequential numbers in memory
        for (Account acc : accountsNeedingNumbers) {
            currentMax++;
            acc.Account_Id_Number__c = currentMax;
            acc.Account_Id__c = String.valueOf(acc.Account_Id_Number__c);
        }
    }

    /**
     * Returns the maximum Account_Id_Number__c value
     * Uses aggregate query for best performance
     */
    public static Decimal fetchCurrentMaxAccountNumber() {
        Decimal maxValue = 0;

        AggregateResult[] results = [SELECT MAX(Account_Id_Number__c) maxNumber FROM Account WHERE Account_Id_Number__c != null];

        if (!results.isEmpty() && results[0].get('maxNumber') != null) {
            maxValue = (Decimal) results[0].get('maxNumber');
        }
		System.debug('maxValue..>'+maxValue);
        return maxValue;
    }
    
    public static void updatePrimaryContact(List<Account> newList, Map<Id, Account> oldMap){

        System.debug('newList..>'+newList);
		System.debug('oldMap..>'+oldMap);
        Set<Id> contactIds = new Set<Id>();
        Map<Id, Account> sourceAccountMap = new Map<Id, Account>();

        // Filter records where fields changed
        for(Account acc : newList){
            Account oldAcc = oldMap.get(acc.Id);

            if(acc.Person_First_Name__c != oldAcc.Person_First_Name__c ||
                acc.Person_Last_Name__c  != oldAcc.Person_Last_Name__c ||
                acc.Person_Email__c      != oldAcc.Person_Email__c
            ){
                if(acc.Primary_Contact__c != null){
                    contactIds.add(acc.Primary_Contact__c);
                    sourceAccountMap.put(acc.Primary_Contact__c, acc);
                }
            }
        }

        if(contactIds.isEmpty()){
            return;
        }

        // Query Person Accounts
        List<Account> primaryContacts = [SELECT Id, PersonContactId, FirstName, LastName, PersonEmail FROM Account
            							WHERE PersonContactId IN :contactIds AND IsPersonAccount = true];

        // Query Contacts
        List<Contact> contactsToUpdateList = [SELECT Id, FirstName, LastName, Email FROM Contact WHERE Id IN :contactIds];

        List<Account> accountsToUpdate = new List<Account>();
        List<Contact> contactsToUpdate = new List<Contact>();

        // Apply updates to Person Accounts
        for(Account pc : primaryContacts){
            Account source = sourceAccountMap.get(pc.PersonContactId);

            if(source != null){
                pc.FirstName   = source.Person_First_Name__c;
                pc.LastName    = source.Person_Last_Name__c;
                pc.PersonEmail = source.Person_Email__c;

                accountsToUpdate.add(pc);
            }
        }

        // Apply updates to Contacts
        for(Contact con : contactsToUpdateList){
            Account source = sourceAccountMap.get(con.Id);

            if(source != null){
                con.FirstName = source.Person_First_Name__c;
                con.LastName  = source.Person_Last_Name__c;
                con.Email     = source.Person_Email__c;

                contactsToUpdate.add(con);
            }
        }

        // update person accounts
        System.debug('accountsToUpdate..>'+accountsToUpdate);
        if(!accountsToUpdate.isEmpty()){
            update accountsToUpdate;
        }

        // update contacts
        System.debug('contactsToUpdate..>'+contactsToUpdate);
        if(!contactsToUpdate.isEmpty()){
            update contactsToUpdate;
        }
    }
}