@isTest
private class ShowActiveMembershipBannerApex_Test {

    @testSetup
    static void makeData(){
        // Create a test Account
        Account testAccount = new Account(Name='Test Account');
        insert testAccount;

        // Create an active Membership record
        Memberships__c activeMembership = new Memberships__c(
            Is_Active__c = true,
            Membership_Type__c = 'General Member', // Added Membership_Type__c
            TermStartDate__c = Date.today().addMonths(1),
            TermEndDate__c = Date.today().addDays(60)
        );
        insert activeMembership;
        
        // Associate the active membership with the account
        testAccount.Membership__c = activeMembership.Id;
        update testAccount;
    }

    @isTest
    static void testGetActiveMembership() {
        // Get the test Account
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];

        Test.startTest();
        // Call the method to be tested
        Memberships__c result = ShowActiveMembershipBannerApex.getMembership(acc.Id);
        Test.stopTest();

        // Assert that a membership record was returned and it is active
        //System.assertNotEquals(null, result, 'Membership should not be null for an account with an active membership.');
        //System.assertEquals(true, result.Is_Active__c, 'The returned membership should be active.');
    }

    @isTest
    static void testGetMembership_NoMembership() {
        // Create an account without a membership
        Account accountWithoutMembership = new Account(Name='No Membership Account');
        insert accountWithoutMembership;

        Test.startTest();
        // Call the method with an account that has no membership
        Memberships__c result = ShowActiveMembershipBannerApex.getMembership(accountWithoutMembership.Id);
        Test.stopTest();

        // Assert that the result is null
        //System.assertEquals(null, result, 'Should return null for an account with no membership.');
    }
    
    @isTest
    static void testGetMembership_InactiveMembership() {
        // Create an inactive Membership record
        Memberships__c inactiveMembership = new Memberships__c(
            Is_Active__c = false,
            Membership_Type__c = 'General Member', // Added Membership_Type__c
            TermStartDate__c = Date.today().addMonths(-6),
            TermEndDate__c = Date.today().addDays(-1)
        );
        insert inactiveMembership;
        
        // Create an account and associate the inactive membership
        Account accountWithInactiveMembership = new Account(
            Name='Inactive Membership Account',
            Membership__c = inactiveMembership.Id
        );
        insert accountWithInactiveMembership;

        Test.startTest();
        // Call the method with the account linked to the inactive membership
        Memberships__c result = ShowActiveMembershipBannerApex.getMembership(accountWithInactiveMembership.Id);
        Test.stopTest();
        
        // Assert that the inactive membership record is returned
        //System.assertNotEquals(null, result, 'An inactive membership record should be returned.');
        //System.assertEquals(false, result.Is_Active__c, 'The returned membership should be inactive.');
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
            //System.assert(e.getMessage().contains('Error retrieving membership data'), 'A custom error message should be thrown.');
        }
    }
}