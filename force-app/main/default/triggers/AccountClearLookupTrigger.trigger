trigger AccountClearLookupTrigger on Account (before delete) {
    
    // Prevent recursion
    if (AccountClearLookupHandler.isProcessing) {
        return;
    }
    
    try {
        AccountClearLookupHandler.isProcessing = true;
        
        // Get all Account IDs being deleted
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : Trigger.old) {
            accountIds.add(acc.Id);
        }
        
        // Clear Account lookup references from related records
        AccountClearLookupHandler.clearAccountReferences(accountIds);
        
        // Clear Primary_Contact__c lookup field from the account itself
        List<Account> accountsToUpdate = new List<Account>();
        for (Account acc : Trigger.old) {
            if (acc.Primary_Contact__c != null) {
                Account accToUpdate = new Account(
                    Id = acc.Id,
                    Primary_Contact__c = null
                );
                accountsToUpdate.add(accToUpdate);
            }
        }
        
        if (!accountsToUpdate.isEmpty()) {
            try {
                update accountsToUpdate;
            } catch (System.DmlException e) {
                System.debug('Warning: Could not clear Primary_Contact__c: ' + e.getMessage());
            }
        }
        
    } catch (Exception e) {
        for (Account acc : Trigger.old) {
            acc.addError('Error occurred while clearing account references: ' + e.getMessage());
        }
    } finally {
        AccountClearLookupHandler.isProcessing = false;
    }
}