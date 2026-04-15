public class AccountClearLookupHandler {
    public static Boolean isProcessing = false;
    
    public static void clearAccountReferences(Set<Id> accountIds) {
        
        List<SObject> recordsToUpdate = new List<SObject>();
        
        // 1. Clear Account__c reference from Invoice__c records
        try {
            List<Invoice__c> invoicesToUpdate = [
                SELECT Id, Bill_To_Account__c 
                FROM Invoice__c 
                WHERE Bill_To_Account__c IN :accountIds
                AND Bill_To_Account__c != null
            ];
            
            for (Invoice__c invoice : invoicesToUpdate) {
                invoice.Bill_To_Account__c = null;
            }
            
            if (!invoicesToUpdate.isEmpty()) {
                recordsToUpdate.addAll(invoicesToUpdate);
                System.debug('Found ' + invoicesToUpdate.size() + ' Invoices to update');
            }
        } catch (Exception e) {
            System.debug('Error querying Invoices: ' + e.getMessage());
        }
        
        // 2. Clear AccountId reference from Order records
        try {
            List<Order> ordersToUpdate = [
                SELECT Id, AccountId 
                FROM Order 
                WHERE AccountId IN :accountIds
                AND AccountId != null
            ];
            
            for (Order orderRecord : ordersToUpdate) {
                orderRecord.AccountId = null;
            }
            
            if (!ordersToUpdate.isEmpty()) {
                recordsToUpdate.addAll(ordersToUpdate);
                System.debug('Found ' + ordersToUpdate.size() + ' Orders to update');
            }
        } catch (Exception e) {
            System.debug('Error querying Orders: ' + e.getMessage());
        }
        
        // 3. Clear Billed_For_Account__c reference from OrderItem records
        try {
            List<OrderItem> orderItemsToUpdate = [
                SELECT Id, Billed_For_Account__c 
                FROM OrderItem 
                WHERE Billed_For_Account__c IN :accountIds
                AND Billed_For_Account__c != null
            ];
            
            for (OrderItem orderItem : orderItemsToUpdate) {
                orderItem.Billed_For_Account__c = null;
            }
            
            if (!orderItemsToUpdate.isEmpty()) {
                recordsToUpdate.addAll(orderItemsToUpdate);
                System.debug('Found ' + orderItemsToUpdate.size() + ' OrderItems to update');
            }
        } catch (Exception e) {
            System.debug('Error querying OrderItems: ' + e.getMessage());
        }
        
        // 4. Update all records at once for better performance
        if (!recordsToUpdate.isEmpty()) {
            try {
                Database.SaveResult[] results = Database.update(recordsToUpdate, false);
                
                Integer successCount = 0;
                Integer errorCount = 0;
                
                for (Database.SaveResult result : results) {
                    if (result.isSuccess()) {
                        successCount++;
                    } else {
                        errorCount++;
                        for (Database.Error error : result.getErrors()) {
                            System.debug('Update error: ' + error.getMessage());
                        }
                    }
                }
                
                System.debug('Successfully updated ' + successCount + ' records');
                if (errorCount > 0) {
                    System.debug('Failed to update ' + errorCount + ' records');
                }
                
            } catch (Exception e) {
                System.debug('Error updating records: ' + e.getMessage());
            }
        } else {
            System.debug('No related records found to update');
        }
    }
}