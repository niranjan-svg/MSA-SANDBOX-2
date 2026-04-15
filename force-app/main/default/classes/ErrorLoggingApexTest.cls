@isTest
private class ErrorLoggingApexTest {

    @isTest
    static void testCreateErrorLog_WithException() {
        // Arrange: Define the input parameters and create a sample Exception.
        String errorType = 'Apex';
        String subject = 'Error in Batch Job';
        String requestBody = '{"id": "123"}';
        String responseBody = '';
        String statusCode = 'N/A';
        Exception capturedException;

        // Generate a real exception to get its details.
        try {
            // This will cause a NullPointerException
            String s;
            s.toUpperCase(); 
        } catch (Exception e) {
            capturedException = e;
        }

        // Act: Call the method being tested.
        Test.startTest();
        Error__c resultErrorLog = ErrorLoggingApex.createErrorLog(
            errorType, subject, requestBody, responseBody, statusCode, capturedException
        );
        Test.stopTest();

        // Assert: Verify that the fields of the returned sObject are populated correctly.
        System.assertNotEquals(null, resultErrorLog, 'The returned Error__c object should not be null.');
        
        // --- Verify fields populated from the Exception ---
        System.assertEquals(capturedException.getTypeName(), resultErrorLog.Name, 'Name should be the exception type.');
        System.assertEquals(capturedException.getMessage(), resultErrorLog.Error_Message__c, 'Error_Message__c should match the exception message.');
        System.assert(resultErrorLog.Error_Trace__c.contains('ErrorLoggingApexTest'), 'Error_Trace__c should contain the stack trace string.');
        
        // --- Verify fields populated from method arguments ---
        System.assertEquals(errorType, resultErrorLog.Error_Type__c, 'Error_Type__c should match the input.');
        System.assertEquals(subject, resultErrorLog.Subject__c, 'Subject__c should match the input.');
        System.assertEquals(requestBody, resultErrorLog.API_Request__c, 'API_Request__c should match the input.');
        System.assertEquals(responseBody, resultErrorLog.API_Response__c, 'API_Response__c should match the input.');
        System.assertEquals('An error occurred during the External Reviewer Sync job. See other fields for details.', resultErrorLog.Description__c);
    }

    @isTest
    static void testCreateErrorLog_WithoutException() {
        // Arrange: Define the input parameters for a non-exception error (e.g., HTTP error).
        String errorType = 'API Callout';
        String subject = 'Failed to connect to External Service';
        String requestBody = '{"data": "sample"}';
        String responseBody = '{"error": "Not Found"}';
        String statusCode = '404';

        // Act: Call the method with a null Exception object.
        Test.startTest();
        Error__c resultErrorLog = ErrorLoggingApex.createErrorLog(
            errorType, subject, requestBody, responseBody, statusCode, null
        );
        Test.stopTest();

        // Assert: Verify that the fields are populated correctly for the HTTP error scenario.
        System.assertNotEquals(null, resultErrorLog, 'The returned Error__c object should not be null.');
        
        // --- Verify fields populated in the "null exception" branch ---
        System.assertEquals('HTTP Status Code Error', resultErrorLog.Name, 'Name should be the default for HTTP errors.');
        System.assertEquals('The endpoint returned a non-success status code: ' + statusCode, resultErrorLog.Error_Message__c, 'Error_Message__c should contain the status code.');
        System.assertEquals(null, resultErrorLog.Error_Trace__c, 'Error_Trace__c should be null when there is no exception.');

        // --- Verify fields populated from method arguments ---
        System.assertEquals(errorType, resultErrorLog.Error_Type__c, 'Error_Type__c should match the input.');
        System.assertEquals(subject, resultErrorLog.Subject__c, 'Subject__c should match the input.');
        System.assertEquals(requestBody, resultErrorLog.API_Request__c, 'API_Request__c should match the input.');
        System.assertEquals(responseBody, resultErrorLog.API_Response__c, 'API_Response__c should match the input.');
    }
}