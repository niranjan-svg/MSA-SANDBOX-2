public class AccountMemberCountHandler {
    public static void updateMemberCounts(List<Account> newAccounts) {
        Set<Id> parentAccountIds = new Set<Id>();
        Map<Id, Account> parentAccountsMap = new Map<Id, Account>();
        
        // Collect Parent Account IDs based on whether the account is a Person Account or not
        for (Account acc : newAccounts) {
            if (acc.IsPersonAccount) {
                parentAccountIds.add(acc.Parent_Account__c);
            } else {
                parentAccountIds.add(acc.Coordinating_Program__c);
            }
        }
        
        // Query the parent accounts to get their current counts
        if (!parentAccountIds.isEmpty()) {
            parentAccountsMap = new Map<Id, Account>([
                SELECT Id, Individual_Sub_Member_Count__c, Organization_Sub_Member_Count__c
                FROM Account
                WHERE Id IN :parentAccountIds
            ]);
        }
        
        // Update the counts based on the type of account
        for (Account acc : newAccounts) {
            if (acc.IsPersonAccount && parentAccountsMap.containsKey(acc.Parent_Account__c)) {
                Account parentAcc = parentAccountsMap.get(acc.Parent_Account__c);
                parentAcc.Individual_Sub_Member_Count__c = (parentAcc.Individual_Sub_Member_Count__c == null ? 0 : parentAcc.Individual_Sub_Member_Count__c) + 1;
            } else if (!acc.IsPersonAccount && parentAccountsMap.containsKey(acc.Coordinating_Program__c)) {
                Account parentAcc = parentAccountsMap.get(acc.Coordinating_Program__c);
                parentAcc.Organization_Sub_Member_Count__c = (parentAcc.Organization_Sub_Member_Count__c == null ? 0 : parentAcc.Organization_Sub_Member_Count__c) + 1;
            }
        }
        
        // Update the parent accounts with the new counts
        if (!parentAccountsMap.isEmpty()) {
            update parentAccountsMap.values();
        }
    }
    
    
    public static void handleAccountCreation(List<Account> newAccounts) {
        // Create a set to hold unique parent account IDs
        Set<Id> parentAccountIds = new Set<Id>();
        system.debug('parentAccountIds---'+parentAccountIds);
        // Loop through new accounts to collect parent account IDs
        for (Account acc : newAccounts) {
            if (acc.IsPersonAccount) {
                // Add Parent_Account__c for person accounts
                if (acc.Parent_Account__c != null) {
                    system.debug('51----'+acc.Parent_Account__c);
                    parentAccountIds.add(acc.Parent_Account__c);
                }
            } else {
                // Add Coordinating_Program__c for organization accounts
                if (acc.Coordinating_Program__c != null) {
                    system.debug('57----'+acc.Parent_Account__c);
                    parentAccountIds.add(acc.Coordinating_Program__c);
                }
            }
        }
        
        // Create a map to hold parent accounts to update later
        Map<Id, Account> parentAccountsToUpdate = new Map<Id, Account>();
        
        // Query the parent accounts based on collected IDs
        if (!parentAccountIds.isEmpty()) {
            List<Account> parentAccounts = [SELECT Id, Submembers_List__c FROM Account WHERE Id IN :parentAccountIds];
            system.debug('parentAccounts----'+parentAccounts);
            
            // Create a map from the queried parent accounts for easy access
            Map<Id, Account> parentAccountsMap = new Map<Id, Account>();
            for (Account parentAcc : parentAccounts) {
                parentAccountsMap.put(parentAcc.Id, parentAcc);
            }
            
            // Loop through new accounts again to update the parent accounts
            for (Account newAccount : newAccounts) {
                String subMemberName;
                if (newAccount.IsPersonAccount) {
                    subMemberName = newAccount.FirstName + newAccount.LastName  + ' Individual account';
                } else {
                    subMemberName = newAccount.Name + ' Organization account';
                }
                
                // Determine the correct parent account ID to update
                Id parentIdToUpdate;
                if (newAccount.IsPersonAccount) {
                    parentIdToUpdate = newAccount.Parent_Account__c;
                } else {
                    parentIdToUpdate = newAccount.Coordinating_Program__c;
                }
                
                // Find the corresponding parent account in the map
                if (parentIdToUpdate != null && parentAccountsMap.containsKey(parentIdToUpdate)) {
                    Account parentAccount = parentAccountsMap.get(parentIdToUpdate);
                    
                    // Prepare the sequentially numbered entry
                    String existingNames = parentAccount.Submembers_List__c;
                    Integer count = 1;
                    
                    // Count existing entries to determine the next number
                    if (String.isNotBlank(existingNames)) {
                        List<String> existingEntries = existingNames.split(', ');
                        count += existingEntries.size();
                    }
                    
                    // Create the new entry with sequential numbering
                    String numberedEntry = count + '. ' + subMemberName;
                    
                    // Update the Sub_Member_Names__c field
                    if (String.isNotBlank(existingNames)) {
                        parentAccount.Submembers_List__c += ', ' + numberedEntry;
                    } else {
                        parentAccount.Submembers_List__c = numberedEntry;
                    }
                    
                    // Add to the map for bulk update later
                    parentAccountsToUpdate.put(parentAccount.Id, parentAccount);
                }
            }
        }
        
        // Perform bulk update of parent accounts
        if (!parentAccountsToUpdate.isEmpty()) {
            system.debug('115  parentIdToUpdate---'+parentAccountsToUpdate);
            system.debug('parentAccountsToUpdate----'+parentAccountsToUpdate.values());
            update parentAccountsToUpdate.values();
        }
    }
    
    
    
}