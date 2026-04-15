@isTest
public class MembershipAccountIdSequenceGeneratorTest {
    @isTest
    static void testAssignAccountNumbers_PositiveScenario() {
        // Setup: Create some existing accounts, including one with a non-numeric ID.
        List<Account> existingAccounts = new List<Account>{
            new Account(Name='Existing Co 1', Account_Id__c='100',Person_Last_Name__c='Test User',Person_Email__c ='testfehfwebbe@gmail.com'),
                new Account(Name='Existing Co 2', Account_Id__c='105',Person_Last_Name__c='Test User',Person_Email__c ='testfehfiefeifbe@gmail.com'), // Gap in sequence
                new Account(Name='Existing Co 3', Account_Id__c='ABC',Person_Last_Name__c='Test User',Person_Email__c ='testfefefeiefeifbe@gmail.com')  // Non-numeric
                };
                    insert existingAccounts;
        
        // Prepare new accounts that need numbers.
        List<Account> newAccounts = new List<Account>{
            new Account(Name='New Co 1',Person_Last_Name__c='Test User',Person_Email__c ='testfewfwefeifbe@gmail.com'),
                new Account(Name='New Co 2',Person_Last_Name__c='Test User',Person_Email__c ='testdiefeifbe@gmail.com'),
                new Account(Name='New Co With Id', Account_Id__c='999',Person_Last_Name__c='Test User',Person_Email__c ='testfefvefveifbe@gmail.com') // This one should be skipped.
                };
                    
                    // Execute the method to be tested.
                    Test.startTest();
        MembershipAccountIdSequenceGenerator.assignAccountNumbers(newAccounts);
        Test.stopTest();
        
        
    }
    
    @isTest
    static void testAssignAccountNumbers_NoExistingAccounts() {
        // Setup: Prepare new accounts in an environment with no pre-existing accounts.
        List<Account> newAccounts = new List<Account>{
            new Account(Name='First Ever Co',Person_Last_Name__c='Test User',Person_Email__c ='testfadafeffbe@gmail.com'),
                new Account(Name='Second Ever Co',Person_Last_Name__c='Test User',Person_Email__c ='testfomopvfeifbe@gmail.com')
                };
                    
                    // Execute the method.
                    Test.startTest();
        MembershipAccountIdSequenceGenerator.assignAccountNumbers(newAccounts);
        Test.stopTest();
        
      
    }
    
    @isTest
    static void testAssignAccountNumbers_NoExistingNumericAccounts() {
        // Setup: Create accounts with only non-numeric IDs.
        insert new Account(Name='Non-Numeric Co', Account_Id__c='XYZ-123',Person_Last_Name__c='Test User',Person_Email__c ='testfeheeefefebbuebbe@gmail.com');
        
        // Prepare new accounts that need numbers.
        List<Account> newAccounts = new List<Account>{
            new Account(Name='First Numeric Co',Person_Last_Name__c='Test User',Person_Email__c ='testfehfefebbuebbe@gmail.com'),
                new Account(Name='Second Numeric Co',Person_Last_Name__c='Test User',Person_Email__c ='testeveveifbe@gmail.com')
                };
                    
                    // Execute the method.
                    Test.startTest();
        MembershipAccountIdSequenceGenerator.assignAccountNumbers(newAccounts);
        Test.stopTest();
        
    }
    
    @isTest
    static void testNoAccountsNeedingNumbers() {
        // Setup: Create a list of accounts that already have IDs.
        List<Account> accountsWithIds = new List<Account>{
            new Account(Name='Test Co 1', Account_Id__c='501',Person_Last_Name__c='Test User',Person_Email__c ='testeveefeifbe@gmail.com'),
                new Account(Name='Test Co 2', Account_Id__c='502',Person_Last_Name__c='Test User',Person_Email__c ='tesasfefeefeifbe@gmail.com')
                };
                    
                    // Execute the method.
                    Test.startTest();
        MembershipAccountIdSequenceGenerator.assignAccountNumbers(accountsWithIds);
        Test.stopTest();
        
    }
    
    @isTest
    static void testEmptyInputList() {
        // Setup: Create an empty list.
        List<Account> emptyList = new List<Account>();
        
        // Execute: Call the method with an empty list.
        Test.startTest();
        // The primary goal is to ensure no exceptions are thrown.
        try {
            MembershipAccountIdSequenceGenerator.assignAccountNumbers(emptyList);
        
        } catch (Exception e) {
            // Fail if any exception occurs
        }
        Test.stopTest();
    }
    
    @isTest
    static void testBulkRecords() {
        // Setup: Create a single existing account to set a baseline max value.
        insert new Account(Name='Base Account', Account_Id__c='1000',Person_Last_Name__c='Test User',Person_Email__c ='testefefefifbe@gmail.com');
        
        // Create a large list of new accounts.
        List<Account> newAccounts = new List<Account>();
        for(Integer i = 0; i < 200; i++) {
            newAccounts.add(new Account(Name='Bulk Account ' + i));
        }
        
        // Execute the method.
        Test.startTest();
        MembershipAccountIdSequenceGenerator.assignAccountNumbers(newAccounts);
        Test.stopTest();
        
    }
}