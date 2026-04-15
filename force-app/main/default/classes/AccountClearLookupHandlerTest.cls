@isTest
private class AccountClearLookupHandlerTest {

    // @testSetup runs once before all test methods in the class.
    // It's the most efficient way to create test data.
    @testSetup
    static void makeData() {
        // --- Create Accounts ---
        // Account to be processed by the handler
        Account accToProcess = new Account(Name = 'Test Account to Process',Person_Last_Name__c='Test User',Person_Email__c ='testfehfwebbe@gmail.com');
        // A control account that should remain untouched
        Account controlAcc = new Account(Name = 'Control Account',Person_Last_Name__c='Test User',Person_Email__c ='testfehfwebbe@gmail.com');
        insert new List<Account>{ accToProcess, controlAcc };

        // --- Create Invoice__c Records ---
        // An invoice related to the account we will process
        Invoice__c invoiceToClear = new Invoice__c(
            Bill_To_Account__c = accToProcess.Id,
            Status__c ='Draft'
        );
        // A control invoice that should not be cleared
        Invoice__c controlInvoice = new Invoice__c(
            Bill_To_Account__c = controlAcc.Id,
            Status__c ='Draft'
        );
        insert new List<Invoice__c>{ invoiceToClear, controlInvoice };

        // --- Setup for Orders and OrderItems ---
        // Get the standard pricebook
        //Pricebook2 stdPricebook = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        Id stdPricebookId = Test.getStandardPricebookId();
        // Create a product
        Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
        insert prod;
        
        // Create a pricebook entry for the product in the standard pricebook
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        // --- Create Order and OrderItem Records ---
        // Order and item related to the account we will process
        Order orderToClear = new Order(
            Name = 'Order-001',
            AccountId = accToProcess.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = stdPricebookId
        );
        insert orderToClear;

        OrderItem orderItemToClear = new OrderItem(
            OrderId = orderToClear.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100,
            Billed_For_Account__c = accToProcess.Id
        );
        insert orderItemToClear;

        // Control order and item that should not be cleared
        Order controlOrder = new Order(
            Name = 'Order-999',
            AccountId = controlAcc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = stdPricebookId
        );
        insert controlOrder;

        OrderItem controlOrderItem = new OrderItem(
            OrderId = controlOrder.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100,
            Billed_For_Account__c = controlAcc.Id
        );
        insert controlOrderItem;
    }

    @isTest
    static void testClearLookups_PositiveScenario() {
        // Arrange: Get the ID of the account to be processed.
        Account accToProcess = [SELECT Id FROM Account WHERE Name = 'Test Account to Process' LIMIT 1];
        Account controlAcc = [SELECT Id FROM Account WHERE Name = 'Control Account' LIMIT 1];
        
        Set<Id> accountIdsToClear = new Set<Id>{ accToProcess.Id };
        
        // Act: Call the method to clear the lookups.
        Test.startTest();
        AccountClearLookupHandler.clearAccountReferences(accountIdsToClear);
        Test.stopTest();

       
       
    }

    @isTest
    static void testClearLookups_NoRelatedRecords() {
        // Arrange: Create a new account with no related records.
        Account accWithNoChildren = new Account(Name = 'Lonely Account',Person_Last_Name__c='Test User',Person_Email__c ='testfehefebffwebbe@gmail.com');
        insert accWithNoChildren;
        
        Set<Id> accountIdsToClear = new Set<Id>{ accWithNoChildren.Id };
        
        // Act: Call the handler. The main goal is to ensure it runs without errors.
        Test.startTest();
        AccountClearLookupHandler.clearAccountReferences(accountIdsToClear);
        Test.stopTest();

     
    }

    @isTest
    static void testClearLookups_EmptyInputSet() {
        // Arrange: Create an empty set of Ids.
        Set<Id> emptySet = new Set<Id>();
        
        // Act: Call the handler with the empty set.
        Test.startTest();
        AccountClearLookupHandler.clearAccountReferences(emptySet);
        Test.stopTest();
        
      
    }
    
    @isTest
    static void testClearLookups_BulkScenario() {
        // Arrange: Create a large number of accounts and one related record for each.
        List<Account> bulkAccounts = new List<Account>();
        for (Integer i = 0; i < 150; i++) {
            bulkAccounts.add(new Account(Name = 'Bulk Account ' + i,Person_Last_Name__c='Test User',Person_Email__c ='testfehefebffwebbe@gmail.com'));
        }
        insert bulkAccounts;

        List<Invoice__c> bulkInvoices = new List<Invoice__c>();
        Set<Id> accountIds = new Map<Id, SObject>(bulkAccounts).keySet();
        for (Id accId : accountIds) {
            bulkInvoices.add(new Invoice__c(Bill_To_Account__c = accId,Status__c='Draft'));
        }
        insert bulkInvoices;

        // Act: Call the handler with all the new account IDs.
        Test.startTest();
        AccountClearLookupHandler.clearAccountReferences(accountIds);
        Test.stopTest();
        
        
    }
}