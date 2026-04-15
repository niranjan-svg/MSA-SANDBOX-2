public with sharing class ShowActiveMembershipBannerApex {
    @AuraEnabled // It's a best practice to add cacheable=true for read-only operations
    public static Memberships__c getMembership(Id accountId) {
        // Use a try-catch block for robust error handling
        try {
            system.debug('accountid---'+accountId);
            // Query for the single Account record
            // IMPORTANT: The relationship name has been changed from Memberships__r to Membership__r
            // Please verify that 'Membership__c' is the correct API name of your lookup field on the Account object.
            List<Account> accounts = [
                SELECT
                    Id,
                	Membership__r.Id,
                    Membership__r.Is_Active__c,      // Corrected from Is_Active__c, verify this API name on your Memberships__c object
                    Membership__r.TermEndDate__c 
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];

            // Check if the list is not empty and the relationship field is populated
            if (!accounts.isEmpty() && accounts[0].Membership__r != null) {
                return accounts[0].Membership__r;
            }

            return null; // Return null if no account or no membership exists

        } catch (Exception e) { throw new AuraHandledException('Error retrieving membership data: ' + e.getMessage());
        }
    }
}