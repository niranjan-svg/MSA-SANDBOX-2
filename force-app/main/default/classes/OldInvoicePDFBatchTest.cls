@isTest
public class OldInvoicePDFBatchTest {

    @testSetup
    static void setupData() {

        // Create Account
        Account acc = new Account(
            Name = 'Test Account'
        );
        insert acc;
 // Create Invoice (Paid)
        Invoice__c inv = new Invoice__c(
            Status__c = 'Paid',
            Bill_To_Account__c = acc.Id
        );
        insert inv;
    }

  
        // Fetch Invoice
        Invoice__c inv = [
            SELECT Id, Name
            FROM Invoice__c
            LIMIT 1
        ];
}