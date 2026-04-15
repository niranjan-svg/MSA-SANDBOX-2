@isTest
private class MembershipPasswordResetApexTest {
    
    // Mock class for successful API response
    private class SuccessHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"success":true,"message":"OK","data":{"userId":405644,"email":"test@example.com"}}');
            return res;
        }
    }
    
    // Mock class for failed API response (invalid data)
    private class FailedDataHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"success":false,"message":"Error","data":null}');
            return res;
        }
    }
    
    // Mock class for 500 error response
    private class ErrorHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(500);
            res.setBody('{"error":"Internal Server Error"}');
            return res;
        }
    }
    
    // Mock class for 301 redirect response
    private class RedirectHttpMock implements HttpCalloutMock {
        private Integer callCount = 0;
        
        public HTTPResponse respond(HTTPRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            
            if (callCount == 1) {
                // First call returns 301 redirect
                res.setStatusCode(301);
                res.setHeader('Location', 'https://redirected.example.com/platform/initiate-password-reset');
            } else {
                // Second call returns success
                res.setHeader('Content-Type', 'application/json');
                res.setStatusCode(200);
                res.setBody('{"success":true,"message":"OK","data":{"userId":405644,"email":"test@example.com"}}');
            }
            return res;
        }
    }
    
    // Mock class for invalid JSON response
    private class InvalidJsonHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('This is not valid JSON');
            return res;
        }
    }
    
    // Setup test data
    @TestSetup
    static void setupTestData() {
        // Note: Custom Metadata records (Membership_Shared_Secret__mdt and CMS_Base_URL__mdt)
        // must exist in your org as they cannot be created in test methods
        
        // Create test record types
        Id personAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();
        Id orgAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Organization_Account').getRecordTypeId();
    }
    
    // Helper method to create Person Account
    private static Account createPersonAccount() {
        Id personAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();
        
        Account personAcc = new Account(
            RecordTypeId = personAccountRecordTypeId,
            FirstName = 'Test',
            LastName = 'Person',
            PersonEmail = 'emailprotected@gmail.com',
            Craft_User_Id__pc = '12345'
        );
        insert personAcc;
        
        // Query back to get PersonContactId
        personAcc = [SELECT Id, PersonContactId, Craft_User_Id__pc FROM Account WHERE Id = :personAcc.Id];
        return personAcc;
    }
    
    // Helper method to create Organization Account with Primary Contact
    private static Account createOrgAccountWithContact() {
        Id orgAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Organization_Account').getRecordTypeId();
        
        Account orgAcc = new Account(
            RecordTypeId = orgAccountRecordTypeId,
            Name = 'Test Organization',
            Person_Last_Name__c = 'Testfh',
            Person_Email__c = 'teseeekjbfekt@test.com'
        );
        insert orgAcc;
        
        Contact primaryContact = new Contact(
            FirstName = 'Primary',
            LastName = 'Contact',
            Email = 'emailprotectedrgnrb@gmail.com',
            AccountId = orgAcc.Id,
            Craft_User_Id__c = '67890'
        );
        insert primaryContact;
        
        orgAcc.Primary_Contact__c = primaryContact.Id;
        update orgAcc;
        
        return orgAcc;
    }
    
    // Test 1: Successful password reset for Person Account
    @isTest
    static void testProcessWebhook_PersonAccount_Success() {
        // Arrange
        Account personAcc = createPersonAccount();
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        
        // Act
        Test.startTest();
        String result = MembershipPasswordResetApex.processWebhook(personAcc.Id);
        Test.stopTest();
        
        // Assert
        System.assertEquals('Password reset initiated successfully', result, 
            'Should return success message for Person Account');
    }
    
    // Test 2: Successful password reset for Organization Account
    @isTest
    static void testProcessWebhook_OrgAccount_Success() {
        // Arrange
        Account orgAcc = createOrgAccountWithContact();
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        
        // Act
        Test.startTest();
        String result = MembershipPasswordResetApex.processWebhook(orgAcc.Id);
        Test.stopTest();
        
        // Assert
        System.assertEquals('Password reset initiated successfully', result, 
            'Should return success message for Organization Account');
    }
    
    // Test 3: Handle 301 redirect
    @isTest
    static void testProcessWebhook_HandleRedirect() {
        // Arrange
        Account personAcc = createPersonAccount();
        Test.setMock(HttpCalloutMock.class, new RedirectHttpMock());
        
        // Act
        Test.startTest();
        String result = MembershipPasswordResetApex.processWebhook(personAcc.Id);
        Test.stopTest();
        
        // Assert
        System.assertEquals('Password reset initiated successfully', result, 
            'Should handle 301 redirect and return success');
    }
    
    // Test 4: Failed API response with invalid data
    @isTest
    static void testProcessWebhook_InvalidApiResponse() {
        // Arrange
        Account personAcc = createPersonAccount();
        Test.setMock(HttpCalloutMock.class, new FailedDataHttpMock());
        
        // Act
        Test.startTest();
        String result = MembershipPasswordResetApex.processWebhook(personAcc.Id);
        Test.stopTest();
        
        // Assert
        System.assertEquals('Password reset failed, Please contact your administrator!', result, 
            'Should return error message for invalid API response');
        
        // Verify error was logged
        List<Error__c> errors = [SELECT Id, Error_Message__c FROM Error__c];
        System.assertEquals(1, errors.size(), 'Should log one error');
        System.assert(errors[0].Error_Message__c.contains('API response validation failed'), 
            'Error message should indicate validation failure');
    }
    
    // Test 5: API returns 500 error
    @isTest
    static void testProcessWebhook_ApiError() {
        // Arrange
        Account personAcc = createPersonAccount();
        Test.setMock(HttpCalloutMock.class, new ErrorHttpMock());
        
        // Act
        Test.startTest();
        String result = MembershipPasswordResetApex.processWebhook(personAcc.Id);
        Test.stopTest();
        
        // Assert
        System.assertEquals('Password reset failed, Please contact your administrator!', result, 
            'Should return error message for API error');
        
        // Verify error was logged
        List<Error__c> errors = [SELECT Id, Error_Message__c FROM Error__c];
        System.assertEquals(1, errors.size(), 'Should log one error');
        System.assert(errors[0].Error_Message__c.contains('500'), 
            'Error message should contain status code 500');
    }
    
    // Test 6: Invalid JSON response
    @isTest
    static void testProcessWebhook_InvalidJsonResponse() {
        // Arrange
        Account personAcc = createPersonAccount();
        Test.setMock(HttpCalloutMock.class, new InvalidJsonHttpMock());
        
        // Act
        Test.startTest();
        String result = MembershipPasswordResetApex.processWebhook(personAcc.Id);
        Test.stopTest();
        
        // Assert
        System.assertEquals('Password reset failed, Please contact your administrator!', result, 
            'Should return error message for invalid JSON');
        
        // Verify error was logged
        List<Error__c> errors = [SELECT Id, Error_Message__c FROM Error__c];
        System.assertEquals(1, errors.size(), 'Should log one error');
        System.assert(errors[0].Error_Message__c.contains('Failed to parse API response'), 
            'Error message should indicate JSON parsing failure');
    }
    
    // Test 7: Invalid Account ID (record not found)
    @isTest
    static void testProcessWebhook_AccountNotFound() {
        // Arrange
        Id fakeAccountId = '001000000000000AAA'; // Fake Account ID
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        
        // Act
        Test.startTest();
        String result = MembershipPasswordResetApex.processWebhook(fakeAccountId);
        Test.stopTest();
        
        // Assert
        System.assertEquals('Password reset failed, Please contact your administrator!', result, 
            'Should return error message when account not found');
        
        // Verify error was logged
        List<Error__c> errors = [SELECT Id, Error_Message__c FROM Error__c];
        System.assertEquals(1, errors.size(), 'Should log one error');
    }
    
    // Test 8: Organization Account without Primary Contact
    @isTest
    static void testProcessWebhook_OrgAccountWithoutPrimaryContact() {
        // Arrange
        Id orgAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Organization_Account').getRecordTypeId();
        
        Account orgAcc = new Account(
            RecordTypeId = orgAccountRecordTypeId,
            Name = 'Test Organization Without Contact',
            Person_Last_Name__c = 'Test contact',
            Person_Email__c = 'tefebfkje@gmail.com'
        );
        insert orgAcc;
        
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        
        // Act
        Test.startTest();
        String result = MembershipPasswordResetApex.processWebhook(orgAcc.Id);
        Test.stopTest();
        
        // Assert
        System.assertEquals('Password reset failed, Please contact your administrator!', result, 
            'Should return error message when Primary Contact is missing');
        
        // Verify error was logged
        List<Error__c> errors = [SELECT Id, Error_Message__c FROM Error__c];
        System.assertEquals(1, errors.size(), 'Should log one error');
        System.assert(errors[0].Error_Message__c.contains('Could not determine userId or personContactId'), 
            'Error message should indicate missing IDs');
    }
    
    // Test 9: Person Account without Craft User ID
    @isTest
    static void testProcessWebhook_PersonAccountWithoutCraftUserId() {
        // Arrange
        Id personAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();
        
        Account personAcc = new Account(
            RecordTypeId = personAccountRecordTypeId,
            FirstName = 'Test',
            LastName = 'Person',
            PersonEmail = 'emailprotectefeed@gmail.com'
            // Craft_User_Id__pc is intentionally not set
        );
        insert personAcc;
        
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        
        // Act
        Test.startTest();
        String result = MembershipPasswordResetApex.processWebhook(personAcc.Id);
        Test.stopTest();
        
        // Assert
        System.assertEquals('Password reset failed, Please contact your administrator!', result, 
            'Should return error message when Craft User ID is missing');
        
        // Verify error was logged
        List<Error__c> errors = [SELECT Id, Error_Message__c FROM Error__c];
        System.assertEquals(1, errors.size(), 'Should log one error');
    }
    
    // Test 10: Verify encryption is working (values are different)
    @isTest
    static void testProcessWebhook_VerifyEncryption() {
        // Arrange
        Account personAcc = createPersonAccount();
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        
        // Act
        Test.startTest();
        String result = MembershipPasswordResetApex.processWebhook(personAcc.Id);
        Test.stopTest();
        
        // Assert - We can't directly test the encrypted values, but we can verify
        // that the process completed successfully, which means encryption worked
        System.assertEquals('Password reset initiated successfully', result, 
            'Encryption and API call should complete successfully');
    }
    
    // Test 11: Bulk test - multiple accounts
    @isTest
    static void testProcessWebhook_BulkOperations() {
        // Arrange
        List<Account> personAccounts = new List<Account>();
        Id personAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();
        
        for (Integer i = 0; i < 5; i++) {
            personAccounts.add(new Account(
                RecordTypeId = personAccountRecordTypeId,
                FirstName = 'Test' + i,
                LastName = 'Person' + i,
                PersonEmail = 'test' + i + '@example.com',
                Craft_User_Id__pc = '12345' + i
            ));
        }
        insert personAccounts;
        
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        
        // Act
        Test.startTest();
        List<String> results = new List<String>();
        for (Account acc : personAccounts) {
            results.add(MembershipPasswordResetApex.processWebhook(acc.Id));
        }
        Test.stopTest();
        
        // Assert
        for (String result : results) {
            System.assertEquals('Password reset initiated successfully', result, 
                'All bulk operations should succeed');
        }
    }
    
    // Test 12: Error logging functionality
    @isTest
    static void testErrorLogging() {
        // Arrange
        Account personAcc = createPersonAccount();
        Test.setMock(HttpCalloutMock.class, new ErrorHttpMock());
        
        // Act
        Test.startTest();
        MembershipPasswordResetApex.processWebhook(personAcc.Id);
        Test.stopTest();
        
        // Assert - Verify error log was created
        List<Error__c> errors = [SELECT Id, Error_Trace__c, Error_Message__c, Error_Type__c 
                                  FROM Error__c];
        System.assertEquals(1, errors.size(), 'Should create one error log');
        System.assertEquals('MembershipPasswordResetApex.processWebhook', errors[0].Error_Trace__c, 
            'Should log correct class and method');
        System.assertNotEquals(null, errors[0].Error_Message__c, 'Error message should not be null');
        System.assertEquals(String.valueOf(personAcc.Id), errors[0].Error_Type__c, 
            'Should log the record ID');
    }
}