@isTest
public class CreateMissingInvoicePDFTest {
	@testSetup
    static void makeData() {
        
        // --- 2. Create Contacts ---
        Contact cpContact = new Contact(
            FirstName = 'Chris', 
            LastName = 'Program', 
            Email = 'cp_contact@test.com'
        );
        Contact businessContact = new Contact(
            FirstName = 'Betty', 
            LastName = 'Business', 
            Email = 'business_contact@test.com'
        );
        insert new List<Contact>{ cpContact, businessContact };

        // --- 3. Create Accounts ---
        Account cpAccount = new Account(
            Name = 'Coordinating Program Inc.',
            Person_Last_Name__c = 'CP Test', 
            Person_Email__c = 'cp_acct@test.com', 
            Program_Type__c = 'Coordinating Program',
            Primary_Contact__c = cpContact.Id  // <-- CRITICAL: Set Primary Contact
        );
        insert cpAccount;

        Account lpAccount = new Account(
            Name = 'Local Program (Paid by CP)', 
            Program_Type__c = 'Local Program', 
            Person_Last_Name__c = 'LP Test', 
            Person_Email__c = 'lp_acct@test.com'
        );
        Account businessAccount = new Account(
            Name = 'Self-Pay Business LLC', 
            Person_Last_Name__c = 'Biz Test', 
            Person_Email__c = 'biz_acct@test.com'
        );
        insert new List<Account>{ lpAccount, businessAccount };
        
        Account personAccount = new Account(
            FirstName = 'Pat', 
            LastName = 'Person', 
            PersonEmail = 'person_acct@test.com'
        );
        insert personAccount;
        
        // --- 4. Create Program Relationship ---
        Program_Relationship__c relationship = new Program_Relationship__c(
            Local_Program__c = lpAccount.Id,
            Coordinating_Program__c = cpAccount.Id,
            Status__c = 'Active',
            Term_Year__c = Date.today().year(),
            Relationship_Type__c = 'Pays LP Membership'
        );
        insert relationship;
        
        // --- 5. Create Orders ---
        Date orderEndDate = Date.newInstance(Date.today().year(), 12, 31);
        Order orderForLP = new Order(
            AccountId = lpAccount.Id, 
            EffectiveDate = Date.today(), 
            EndDate = orderEndDate, 
            Status = 'Draft', 
            Billing_Type__c = 'Paid by Coordinating Program'
        );
        Order orderForBusiness = new Order(
            AccountId = businessAccount.Id, 
            EffectiveDate = Date.today(), 
            EndDate = orderEndDate, 
            Status = 'Draft', 
            Billing_Type__c = 'Self-Pay'
        );
        Order orderForPerson = new Order(
            AccountId = personAccount.Id, 
            EffectiveDate = Date.today(), 
            EndDate = orderEndDate, 
            Status = 'Draft', 
            Billing_Type__c = 'Self-Pay'
        );
        insert new List<Order>{ orderForLP, orderForBusiness, orderForPerson };

        // --- 6. Create Invoices ---
        Invoice__c invForCP = new Invoice__c(
            Bill_To_Account__c = lpAccount.Id, 
            Related_Order__c = orderForLP.Id, 
            Status__c = 'Draft'
        );
        Invoice__c invForBusiness = new Invoice__c(
            Bill_To_Account__c = businessAccount.Id, 
            Bill_To_Contact__c = businessContact.Id, 
            Related_Order__c = orderForBusiness.Id,
            Status__c = 'Draft'
        );
        Invoice__c invForPerson = new Invoice__c(
            Bill_To_Account__c = personAccount.Id, 
            Related_Order__c = orderForPerson.Id,
            Status__c = 'Draft'
        );
        Invoice__c invNoTransaction = new Invoice__c(
            Bill_To_Account__c = personAccount.Id, 
            Related_Order__c = orderForPerson.Id,
            Status__c = 'Draft'
        );
        Invoice__c invNoRecipient = new Invoice__c(
            Bill_To_Account__c = businessAccount.Id, 
            Related_Order__c = orderForBusiness.Id,
            Status__c = 'Draft'
        );
        insert new List<Invoice__c>{ 
            invForCP, 
            invForBusiness, 
            invForPerson, 
            invNoTransaction, 
            invNoRecipient 
        };
        
        // --- 7. Create Transactions (for all except the "no transaction" test case) ---
        insert new List<Membership_Transaction__c>{
            new Membership_Transaction__c(Invoice__c = invForCP.Id),
            new Membership_Transaction__c(Invoice__c = invForBusiness.Id),
            new Membership_Transaction__c(Invoice__c = invForPerson.Id)
            // NOTE: invNoRecipient HAS a transaction (to test email validation failure)
            // NOTE: invNoTransaction does NOT have a transaction (to test that skip scenario)
        };
    }
    @isTest
    static void test1() {
        // Query the Invoice created in @testSetup
        Invoice__c invForCP = [SELECT Id  FROM Invoice__c WHERE Bill_To_Account__r.Name = 'Local Program (Paid by CP)'  AND Related_Order__r.Billing_Type__c = 'Paid by Coordinating Program' LIMIT 1 ];
       
        invForCP.Status__c = 'Paid';
        update invForCP;
        Test.startTest();
        Database.executebatch(new CreateMissingInvoicePDF(),10);
        Test.stopTest();
    }
}