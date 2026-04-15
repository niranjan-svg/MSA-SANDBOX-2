@isTest
private class ChangeContactEmailApexTest {

    // Test constants for repeatable inputs
    private static final String TEST_USER_ID = 'encryptedUserId123';
    private static final String TEST_CONTACT_ID = 'encryptedPersonContactId456';
    private static final String TEST_NEW_EMAIL = 'new.email@example.com';

    // --- INNER MOCK CLASSES FOR HTTP CALLOUTS ---

    /**
     * A flexible mock for simulating a single, specific HTTP response.
     */
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        // ... (This class is correct and needs no changes)
        protected Integer statusCode;
        protected String status;
        protected String body;
        protected Map<String, String> responseHeaders;

        public MockHttpResponseGenerator(Integer code, String stat, String b, Map<String, String> headers) {
            this.statusCode = code;
            this.status = stat;
            this.body = b;
            this.responseHeaders = headers;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setStatus(this.status);
            res.setBody(this.body);
            if (this.responseHeaders != null) {
                for (String key : this.responseHeaders.keySet()) {
                    res.setHeader(key, this.responseHeaders.get(key));
                }
            }
            return res;
        }
    }

    /**
     * A mock for simulating a sequence of HTTP responses for redirect tests.
     */
    private class MockSequentialHttpResponses implements HttpCalloutMock {
        // ... (This class is correct and needs no changes)
        private List<HttpResponse> responses;
        private Integer calloutCount = 0;

        public MockSequentialHttpResponses(List<HttpResponse> responses) {
            this.responses = responses;
        }

        public HttpResponse respond(HttpRequest req) {
            if (calloutCount >= responses.size()) {
                System.assert(false, 'More HTTP callouts were made than expected by the mock.');
                return null; 
            }
            
            HttpResponse res = responses.get(calloutCount);
            calloutCount++;
            return res;
        }
    }
    
    /**
     * <-- FIXED: Renamed the class from 'MockHttpCalloutException' to 'MockCalloutExceptionGenerator'.
     * This mock is designed to throw a CalloutException to test the catch block.
     * The name no longer conflicts with the Apex rule for custom exception classes.
     */
    private class MockCalloutExceptionGenerator implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            // The logic here is correct: throw a real System.CalloutException.
            throw new System.CalloutException('Mocked callout exception for testing.');
        }
    }

    // --- TEST METHODS ---

    @isTest
    static void testSuccessScenario() {
        List<ChangeContactEmailApex.InvocableRequest> requests = new List<ChangeContactEmailApex.InvocableRequest>();
        ChangeContactEmailApex.InvocableRequest req = new ChangeContactEmailApex.InvocableRequest();
        req.userId = TEST_USER_ID;
        req.personContactId = TEST_CONTACT_ID;
        req.newEmail = TEST_NEW_EMAIL;
        requests.add(req);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, 'OK', '{"status":"success"}', null));
        
        Test.startTest();
        List<ChangeContactEmailApex.InvocableResponse> responses = ChangeContactEmailApex.changeEmail(requests);
        Test.stopTest();
        
        System.assertEquals(1, responses.size());
        System.assertEquals('Success', responses[0].result);
        System.assertEquals(0, [SELECT COUNT() FROM Error__c]);
    }

    @isTest
    static void testRedirectSuccessScenario() {
        List<ChangeContactEmailApex.InvocableRequest> requests = new List<ChangeContactEmailApex.InvocableRequest>();
        ChangeContactEmailApex.InvocableRequest req = new ChangeContactEmailApex.InvocableRequest();
        req.userId = TEST_USER_ID;
        req.personContactId = TEST_CONTACT_ID;
        req.newEmail = TEST_NEW_EMAIL;
        requests.add(req);

        HttpResponse redirectResponse = new HttpResponse();
        redirectResponse.setStatusCode(301);
        redirectResponse.setHeader('Location', 'https://new.endpoint.com/platform/change-email');
        
        HttpResponse successResponse = new HttpResponse();
        successResponse.setStatusCode(200);
        successResponse.setStatus('OK');
        
        Test.setMock(HttpCalloutMock.class, new MockSequentialHttpResponses(new List<HttpResponse>{redirectResponse, successResponse}));
        
        Test.startTest();
        List<ChangeContactEmailApex.InvocableResponse> responses = ChangeContactEmailApex.changeEmail(requests);
        Test.stopTest();
        
        System.assertEquals(1, responses.size());
        System.assertEquals('Success', responses[0].result);
    }

    @isTest
    static void testApiFailureScenario() {
        List<ChangeContactEmailApex.InvocableRequest> requests = new List<ChangeContactEmailApex.InvocableRequest>();
        ChangeContactEmailApex.InvocableRequest req = new ChangeContactEmailApex.InvocableRequest();
        req.userId = TEST_USER_ID;
        req.personContactId = TEST_CONTACT_ID;
        req.newEmail = TEST_NEW_EMAIL;
        requests.add(req);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Server Error', '{"error":"Something went wrong"}', null));
        
        Test.startTest();
        List<ChangeContactEmailApex.InvocableResponse> responses = ChangeContactEmailApex.changeEmail(requests);
        Test.stopTest();
        
        System.assertEquals(1, responses.size());
        System.assertEquals('Failed', responses[0].result);
        System.assertEquals(1, [SELECT COUNT() FROM Error__c], 'An Error__c record should have been created.');
    }
    
    @isTest
    static void testCalloutExceptionScenario() {
        List<ChangeContactEmailApex.InvocableRequest> requests = new List<ChangeContactEmailApex.InvocableRequest>();
        ChangeContactEmailApex.InvocableRequest req = new ChangeContactEmailApex.InvocableRequest();
        req.userId = TEST_USER_ID;
        req.personContactId = TEST_CONTACT_ID;
        req.newEmail = TEST_NEW_EMAIL;
        requests.add(req);
        
        // <-- FIXED: Use the new, correctly named mock class.
        Test.setMock(HttpCalloutMock.class, new MockCalloutExceptionGenerator());
        
        Test.startTest();
        List<ChangeContactEmailApex.InvocableResponse> responses = ChangeContactEmailApex.changeEmail(requests);
        Test.stopTest();
        
        System.assertEquals(1, responses.size());
        System.assertEquals('Failed', responses[0].result);
        List<Error__c> errors = [SELECT Id, Error_Message__c FROM Error__c];
        System.assertEquals(1, errors.size());
        System.assert(errors[0].Error_Message__c.contains('Apex Callout Exception'));
    }
    
    @isTest
    static void testInvalidInputScenario() {
        List<ChangeContactEmailApex.InvocableRequest> requests = new List<ChangeContactEmailApex.InvocableRequest>();
        ChangeContactEmailApex.InvocableRequest req = new ChangeContactEmailApex.InvocableRequest();
        req.userId = TEST_USER_ID;
        req.personContactId = ''; // Blank input
        req.newEmail = TEST_NEW_EMAIL;
        requests.add(req);
        
        Test.startTest();
        List<ChangeContactEmailApex.InvocableResponse> responses = ChangeContactEmailApex.changeEmail(requests);
        Test.stopTest();
        
        System.assertEquals(1, responses.size());
        System.assertEquals('Failed', responses[0].result);
        System.assertEquals(0, Limits.getCallouts());
        System.assertEquals(1, [SELECT COUNT() FROM Error__c], 'An Error__c record should have been created.');
    }
}