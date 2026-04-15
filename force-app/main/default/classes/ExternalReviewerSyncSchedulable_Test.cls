/**
 * @description Complete test class for ExternalReviewerSyncSchedulable.
 * This class tests all success, failure, and edge-case scenarios to ensure
 * high code coverage and robust error handling.
 */
@isTest
private class ExternalReviewerSyncSchedulable_Test {

    // Mock #1: For simulating specific HTTP responses (Success, Error Codes, etc.)
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        Integer statusCode;
        String responseBody;

        public MockHttpResponseGenerator(Integer code, String body) {
            this.statusCode = code;
            this.responseBody = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(this.responseBody);
            res.setStatusCode(this.statusCode);
            return res;
        }
    }

    // Mock #2: For simulating a System.CalloutException (e.g., a timeout)
    private class MockCalloutExceptionGenerator implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            // Instead of returning a response, this mock throws the exception.
            throw new System.CalloutException('This is a simulated callout exception from the test mock.');
        }
    }


    // --- Test Method 1: The "Happy Path" / Successful Execution ---
    @isTest
    static void testScheduledJobExecution_Success() {
        // Setup
        insert new External_Reviewer__c(Name = 'Existing Devin Sizer', Submittable_User_Id__c = 'cf452bad-da9a-41f4-be49-01c01ac6c991');
        String successJson = '{ "teamMembers": [ { "userId": "0e9dd7db-5ef4-4dd3-84a1-0051006e66b5", "name": { "full": "Kevin Teater" }, "roles": [{"id":"role1"}] }, { "userId": "cf452bad-da9a-41f4-be49-01c01ac6c991", "name": { "full": "Devin Sizer" } } ] }';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, successJson));

        // Execute
        Test.startTest();
        System.schedule('Test Success Job', '0 0 1 * * ?', new ExternalReviewerSyncSchedulable());
        Test.stopTest();

        // Assert
        System.assertEquals(2, [SELECT count() FROM External_Reviewer__c], 'Should be 2 reviewers total: 1 pre-existing + 1 new.');
        System.assertEquals(0, [SELECT count() FROM Error__c], 'No Error__c records should be created on a successful run.');
    }

    // --- Test Method 2: Endpoint returns an error (e.g., 500 Server Error) ---
    @isTest
    static void testEndpointError() {
        // Setup
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error'));

        // Execute
        Test.startTest();
        System.schedule('Test Endpoint Error Job', '0 0 2 * * ?', new ExternalReviewerSyncSchedulable());
        Test.stopTest();

        // Assert
        System.assertEquals(0, [SELECT count() FROM External_Reviewer__c], 'No reviewers should be created when the endpoint fails.');
        List<Error__c> errors = [SELECT Error_Type__c FROM Error__c];
        System.assertEquals(1, errors.size(), 'An Error__c record should be created for an endpoint error.');
        System.assertEquals('Endpoint Error', errors[0].Error_Type__c, 'Error Type should be Endpoint Error.');
    }

    // --- Test Method 3: System fails to make the callout (e.g., Timeout) ---
    @isTest
    static void testSystemCalloutException() {
        // Setup
        Test.setMock(HttpCalloutMock.class, new MockCalloutExceptionGenerator());

        // Execute
        Test.startTest();
        System.schedule('Test System Error Job', '0 0 3 * * ?', new ExternalReviewerSyncSchedulable());
        Test.stopTest();

        // Assert
        System.assertEquals(0, [SELECT count() FROM External_Reviewer__c], 'No reviewers should be created on a system callout exception.');
        List<Error__c> errors = [SELECT Error_Type__c FROM Error__c];
        System.assertEquals(1, errors.size(), 'An Error__c record should be created for a system exception.');
        System.assertEquals('System Error', errors[0].Error_Type__c, 'Error Type should be System Error.');
    }

    // --- Test Method 4: The insert fails due to a DML Exception ---
    @isTest
    static void testDmlException() {
        // Setup
        // This JSON is missing the required `name` object, which will cause the insert to fail.
        String badJson = '{ "teamMembers": [ { "userId": "user-will-fail-dml", "roles": [{"id":"role1"}] } ] }';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, badJson));

        // Execute
        Test.startTest();
        System.schedule('Test DML Error Job', '0 0 4 * * ?', new ExternalReviewerSyncSchedulable());
        Test.stopTest();

        // Assert
        System.assertEquals(0, [SELECT count() FROM External_Reviewer__c], 'No reviewers should be created when the DML fails.');
        List<Error__c> errors = [SELECT Error_Type__c FROM Error__c];
        System.assertEquals(1, errors.size(), 'An Error__c record should be created for a DML exception.');
        System.assertEquals('DML Error', errors[0].Error_Type__c, 'Error Type should be DML Error.');
    }

    // --- Test Method 5: The API call is successful but returns an empty list ---
    @isTest
    static void testEmptyResponse() {
        // Setup
        String emptyJson = '{ "teamMembers": [] }';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, emptyJson));

        // Execute
        Test.startTest();
        System.schedule('Test Empty Response Job', '0 0 5 * * ?', new ExternalReviewerSyncSchedulable());
        Test.stopTest();

        // Assert
        System.assertEquals(0, [SELECT count() FROM External_Reviewer__c], 'No reviewers should be created for an empty response.');
        System.assertEquals(0, [SELECT count() FROM Error__c], 'No errors should be created for a valid empty response.');
    }
}