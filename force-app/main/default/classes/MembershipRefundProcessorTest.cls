@isTest
private class MembershipRefundProcessorTest {

    // Use @testSetup to create common test data once for all test methods.
    @testSetup
    static void makeData() {
          Account cpAccount = new Account(
            Name = 'Coordinating Program Inc.',
            Person_Last_Name__c = 'CP Test', 
            Person_Email__c = 'cp_acct@test.com', 
            Program_Type__c = 'Coordinating Program'
        );
        insert cpAccount;
        Date orderEndDate = Date.newInstance(Date.today().year(), 12, 31);
         Order orderForLP = new Order(
            AccountId = cpAccount.Id, 
            EffectiveDate = Date.today(), 
            EndDate = orderEndDate, 
            Status = 'Draft', 
            Billing_Type__c = 'Paid by Coordinating Program'
        );
        insert orderForLP;
        Invoice__c newInvoice = new Invoice__c();
        newInvoice.Bill_To_Account__c = cpAccount.Id;
        newInvoice.Related_Order__c = orderForLP.Id;
        newInvoice.Status__c = 'Draft';
        insert newInvoice;
        
        // Create a parent Membership Transaction record.
        Membership_Transaction__c transaction1 = new Membership_Transaction__c(
            Craft_Commerce_Reference_Id__c = 'some-commerce-id-123',
            Transaction_Name__c = 'Trans No ID',
            Invoice__c = newInvoice.Id // Note: This hardcoded ID may cause issues in other orgs.
                                             // For this test, it's okay since it's not used by the Apex class.
        );
        insert transaction1;

        // Create the Membership Refund record that will be processed.
        Membership_Refund__c refund = new Membership_Refund__c(
            Membership_Transaction__c = transaction1.Id
        );
        insert refund;
    }

    // --- Test for the successful, "happy path" scenario ---
    @isTest
    static void testProcessRefund_Success() {
        // ARRANGE: Get the refund record and set up a mock success response.
        Membership_Refund__c refund = [SELECT Id FROM Membership_Refund__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, 'OK', 'Success Body'));

        // ACT: Execute the method.
        Test.startTest();
        String result = MembershipRefundProcessor.processRefund(refund.Id);
        Test.stopTest();

    }

    // --- Test for handling a 301 Redirect successfully ---
    @isTest
    static void testProcessRefund_RedirectSuccess() {
        // ARRANGE: Set up a multi-response mock to simulate a 301 redirect followed by a 200 OK.
        Map<Integer, HttpResponse> responseMap = new Map<Integer, HttpResponse>();
        
        // First response: 301 Redirect
        HttpResponse redirectResponse = new HttpResponse();
        redirectResponse.setStatusCode(301);
        redirectResponse.setHeader('Location', 'https://new-endpoint.com/commerce/refund');
        responseMap.put(1, redirectResponse);

        // Second response: 200 OK
        HttpResponse successResponse = new HttpResponse();
        successResponse.setStatusCode(200);
        successResponse.setStatus('OK');
        successResponse.setBody('Success on redirect');
        responseMap.put(2, successResponse);
        
        Test.setMock(HttpCalloutMock.class, new MockMultiResponse(responseMap));
        
        Membership_Refund__c refund = [SELECT Id FROM Membership_Refund__c LIMIT 1];

        // ACT
        Test.startTest();
        String result = MembershipRefundProcessor.processRefund(refund.Id);
        Test.stopTest();

    }

    // --- Test for an API error (e.g., 500 server error) ---
    @isTest
    static void testProcessRefund_ApiError() {
        // ARRANGE: Get the refund record and set up a mock error response.
        Membership_Refund__c refund = [SELECT Id FROM Membership_Refund__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Server Error', 'Error Body'));

        // ACT: Execute the method.
        Test.startTest();
        String result = MembershipRefundProcessor.processRefund(refund.Id);
        Test.stopTest();

    }

    // --- Test for a general callout exception (e.g., endpoint unavailable) ---
    @isTest
    static void testProcessRefund_CalloutException() {
        // ARRANGE: Get the refund record and set up a mock that throws an exception.
        Membership_Refund__c refund = [SELECT Id FROM Membership_Refund__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockExceptionResponse());

        // ACT: Execute the method.
        Test.startTest();
        String result = MembershipRefundProcessor.processRefund(refund.Id);
        Test.stopTest();

    }

    // --- Test for missing data (Commerce Reference ID is blank) ---
    @isTest
    static void testProcessRefund_NoCommerceId() {
        
         Account cpAccount = new Account(
            Name = 'Coordinating Program Inc.',
            Person_Last_Name__c = 'CP Test', 
            Person_Email__c = 'cp_acct@test.com', 
            Program_Type__c = 'Coordinating Program'
        );
        insert cpAccount;
        Date orderEndDate = Date.newInstance(Date.today().year(), 12, 31);
         Order orderForLP = new Order(
            AccountId = cpAccount.Id, 
            EffectiveDate = Date.today(), 
            EndDate = orderEndDate, 
            Status = 'Draft', 
            Billing_Type__c = 'Paid by Coordinating Program'
        );
        insert orderForLP;
        Invoice__c newInvoice = new Invoice__c();
        newInvoice.Bill_To_Account__c = cpAccount.Id;
        newInvoice.Related_Order__c = orderForLP.Id;
        newInvoice.Status__c = 'Draft';
        insert newInvoice;
        
        
        
        // ARRANGE: Create a transaction with a null commerce reference ID.
        Membership_Transaction__c transNoId = new Membership_Transaction__c(Transaction_Name__c = 'Trans No ID', Invoice__c =newInvoice.Id);
        insert transNoId;
        Membership_Refund__c refundNoId = new Membership_Refund__c(Membership_Transaction__c = transNoId.Id);
        insert refundNoId;

        // ACT: Execute the method. No callout mock is needed as it should fail before that.
        Test.startTest();
        String result = MembershipRefundProcessor.processRefund(refundNoId.Id);
        Test.stopTest();

    }

    // --- Test for a refund record that doesn't exist ---
    @isTest
    static void testProcessRefund_NoRefundRecord() {
        // ARRANGE: Create a fake ID that doesn't exist in the database.
        Id fakeId = 'a01dp0000000001AAA'; // Used a valid prefix for Membership_Refund__c for robustness

        // ACT: Execute the method.
        Test.startTest();
        String result = MembershipRefundProcessor.processRefund(fakeId);
        Test.stopTest();

    }


    // --- Mock Classes for Simulating HTTP Responses ---

    // Mock for a single, configurable HTTP response.
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        protected Integer code;
        protected String status;
        protected String body;
        
        public MockHttpResponseGenerator(Integer code, String status, String body) {
            this.code = code;
            this.status = status;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.code);
            res.setStatus(this.status);
            res.setBody(this.body);
            return res;
        }
    }

    // Mock that throws a CalloutException.
    private class MockExceptionResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new System.CalloutException('Endpoint unavailable');
        }
    }

    // Mock for handling multiple sequential callouts (used for redirects).
    private class MockMultiResponse implements HttpCalloutMock {
        private Map<Integer, HttpResponse> responseMap;
        // CORRECTED: Changed from a static variable to an instance variable.
        private Integer calloutCount = 0; 

        public MockMultiResponse(Map<Integer, HttpResponse> responseMap) {
            this.responseMap = responseMap;
            // CORRECTED: The static variable was removed, so no reset is needed here.
            // The instance variable is already initialized to 0 above.
        }

        public HttpResponse respond(HttpRequest req) {
            this.calloutCount++;
            return responseMap.get(this.calloutCount);
        }
    }
}