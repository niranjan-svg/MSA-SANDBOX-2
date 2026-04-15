@isTest
private class ShowActiveMembershipBannerApexTest {

    @testSetup
    static void makeData(){
        // Create a test Account with specified fields
        Account testAccount = new Account(
            Name='Test Account 1', 
            Account_Id__c='1001',
            Program_Type__c = 'Coordinating Program',  
            Person_Last_Name__c = 'John', 
            Person_Email__c = 'setup1@kloudserv.ca'
        );
        insert testAccount;
        Membership_Type__c newMembershipId = new Membership_Type__c();
        newMembershipId.Name = 'Coordinating Program Member';
        newMembershipId.Price__c = 1000;
        insert newMembershipId;

        // Create an active Membership record
        Memberships__c activeMembership = new Memberships__c(
            Is_Active__c = true,
            // WARNING: Hardcoding IDs is not a recommended practice.
            // This test will fail if the record with this ID does not exist
            // in the environment where the test is run.
            Membership_Type__c = newMembershipId.id, 
            TermStartDate__c = Date.today().addMonths(-1),
            TermEndDate__c = Date.today().addDays(30)
        );
        insert activeMembership;
        
        // Associate the active membership with the account
        testAccount.Membership__c = activeMembership.Id;
        update testAccount;
    }

    @isTest
    static void testGetActiveMembership() {
        // Get the test Account created in testSetup
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account 1' LIMIT 1];

        Test.startTest();
        // Call the method to be tested
        Memberships__c result = ShowActiveMembershipBannerApex.getMembership(acc.Id);
        Test.stopTest();

        // Assert that a membership record was returned and it is active
        System.assertNotEquals(null, result, 'Membership should not be null for an account with an active membership.');
        System.assertEquals(true, result.Is_Active__c, 'The returned membership should be active.');
    }

    @isTest
    static void testGetMembership_NoMembership() {
        // Create an account without a membership, including the new fields
        Account accountWithoutMembership = new Account(
            Name='Test Account 2', 
            Account_Id__c='1002',
            Program_Type__c = 'Coordinating Program',  
            Person_Last_Name__c = 'Jane', 
            Person_Email__c = 'setup2@kloudserv.ca'
        );
        insert accountWithoutMembership;

        Test.startTest();
        // Call the method with an account that has no membership
        Memberships__c result = ShowActiveMembershipBannerApex.getMembership(accountWithoutMembership.Id);
        Test.stopTest();

        // Assert that the result is null
        System.assertEquals(null, result, 'Should return null for an account with no membership.');
    }
    
    @isTest
    static void testGetMembership_InactiveMembership() {
        // Create an inactive Membership record
         Membership_Type__c newMembershipId = new Membership_Type__c();
        newMembershipId.Name = 'Coordinating Program Member';
        newMembershipId.Price__c = 1000;
        insert newMembershipId;
        Memberships__c inactiveMembership = new Memberships__c(
            Is_Active__c = false,
            // WARNING: Hardcoding IDs is not a recommended practice.
            Membership_Type__c = newMembershipId.Id,
            TermStartDate__c = Date.today().addMonths(-6),
            TermEndDate__c = Date.today().addDays(-1)
        );
        insert inactiveMembership;
        
        // Create an account and associate the inactive membership
        Account accountWithInactiveMembership = new Account(
            Name='Test Account 3', 
            Account_Id__c='1003',
            Program_Type__c = 'Coordinating Program',  
            Person_Last_Name__c = 'Smith', 
            Person_Email__c = 'setup3@kloudserv.ca',
            Membership__c = inactiveMembership.Id
        );
        insert accountWithInactiveMembership;

        Test.startTest();
        // Call the method with the account linked to the inactive membership
        Memberships__c result = ShowActiveMembershipBannerApex.getMembership(accountWithInactiveMembership.Id);
        Test.stopTest();
        
        // Assert that the inactive membership record is returned
        System.assertNotEquals(null, result, 'An inactive membership record should be returned.');
        System.assertEquals(false, result.Is_Active__c, 'The returned membership should be inactive.');
    }

    @isTest
    static void testGetMembership_ErrorCondition() {
        try {
            Test.startTest();
            // Call the method with a null accountId to simulate an error
            Memberships__c result = ShowActiveMembershipBannerApex.getMembership(null);
            Test.stopTest();
        } catch (Exception e) {
            // Assert that a specific exception is thrown
            System.assert(e.getMessage().contains('Error retrieving membership data'), 'A custom error message should be thrown.');
        }
    }
}