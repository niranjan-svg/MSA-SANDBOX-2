trigger InvoicePDFTrigger on Invoice__c (after insert,after update) {
    if (Trigger.isAfter) { // Covers both insert and update
        
        Map<Id, Invoice__c> oldInvoiceMap = Trigger.oldMap;
        List<Id> paidInvoiceIds = new List<Id>();
        
        for (Invoice__c newInvoice : Trigger.new) {
            
            // Check if the status has changed to a "paid" state
            Boolean wasPaidBefore = (Trigger.isUpdate && (oldInvoiceMap.get(newInvoice.Id).Status__c == 'Paid' || oldInvoiceMap.get(newInvoice.Id).Status__c == 'Paid By CP'));
            Boolean isPaidNow = (newInvoice.Status__c == 'Paid' || newInvoice.Status__c == 'Paid By CP');
            
            // Trigger ONLY when the status changes TO paid, not if it was already paid.
            if (isPaidNow && !wasPaidBefore) {
                paidInvoiceIds.add(newInvoice.Id);
            }
        }
        
        if (!paidInvoiceIds.isEmpty()) {
            Set<Id> paidInvoiceIdSet = new Set<Id>(paidInvoiceIds);
            // Call the future method to handle the complex processing asynchronously
            //MembershipInvoiceProcess.generateAndSendInvoice(paidInvoiceIds); // comment by shubham for testing-15Apr2026
            MembershipInvoiceProcess_1.processInvoicesAsync(paidInvoiceIdSet);
        }
    }
}