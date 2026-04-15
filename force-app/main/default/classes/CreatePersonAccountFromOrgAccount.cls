public class CreatePersonAccountFromOrgAccount {
    public static void createPersonAccount(List<Account> newAccounts) {
        // Get the Record Type Id for Person Accounts
        Id personAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        
        List<Account> personAccountsToCreate = new List<Account>();
        
        for (Account acc : newAccounts) {
            // Debug the source values
            System.debug('Source Account - Person_Last_Name__c: ' + acc.Person_Last_Name__c);
            System.debug('Source Account - Person_Email__c: ' + acc.Person_Email__c);
            System.debug('Source Account - Mailing_Address__c: ' + acc.Mailing_Address__c);
            
            // Create a new Person Account sObject
            Account personAccount = new Account();
            
            // Map fields from the triggering Account to the new Person Account
            personAccount.RecordTypeId = personAccountRecordTypeId;
            personAccount.FirstName = acc.Person_First_Name__c;
            personAccount.LastName = acc.Person_Last_Name__c;
            personAccount.PersonEmail = acc.Person_Email__c;
            personAccount.Phone = acc.Person_Phone__c;
            personAccount.PersonMobilePhone = acc.Person_Mobile__c;
            
            // Debug the mapped values
            System.debug('Person Account - FirstName: ' + personAccount.FirstName);
            System.debug('Person Account - LastName: ' + personAccount.LastName);
            System.debug('Person Account - PersonEmail: ' + personAccount.PersonEmail);
            
            // Handle the composite mailing address field with proper null checking
            if (acc.Mailing_Address__c != null) {
                try {
                    personAccount.PersonMailingStreet = acc.Mailing_Address__c.getStreet();
                    personAccount.PersonMailingCity = acc.Mailing_Address__c.getCity();
                    personAccount.PersonMailingState = acc.Mailing_Address__c.getState();
                    personAccount.PersonMailingPostalCode = acc.Mailing_Address__c.getPostalCode();
                    personAccount.PersonMailingCountry = acc.Mailing_Address__c.getCountry();
                    
                    System.debug('Address parsed successfully');
                } catch (Exception e) {
                    System.debug('Error parsing address: ' + e.getMessage());
                }
            } else {
                System.debug('Mailing address is null');
            }
            
            personAccountsToCreate.add(personAccount);
        }
        
        // Insert the new Person Accounts in bulk
        if (!personAccountsToCreate.isEmpty()) {
            try {
                insert personAccountsToCreate;
                
                // Rest of your code for updating the original accounts...
                List<Account> accountsToUpdate = new List<Account>();
                for (Integer i = 0; i < personAccountsToCreate.size(); i++) {
                    Account triggeringAccount = newAccounts[i];
                    Account newPersonAccount = personAccountsToCreate[i];
                    
                    triggeringAccount.Primary_Contact__c = newPersonAccount.PersonContactId;
                    triggeringAccount.Is_Person_Account_Created__c = true;
                    accountsToUpdate.add(triggeringAccount);
                }
                
                if (!accountsToUpdate.isEmpty()) {
                    update accountsToUpdate;
                }
            } catch (DmlException e) {
                System.debug('DML Exception: ' + e.getMessage());
                System.debug('First error: ' + e.getDmlMessage(0));
                throw e;
            }
        }
    }
}