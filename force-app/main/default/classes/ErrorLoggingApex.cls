public class ErrorLoggingApex {
    public static Error__c createErrorLog(String errorType, String subject, String requestBody, String responseBody, String statusCode, Exception ex) {
        Error__c errorLog = new Error__c();
        errorLog.Error_Type__c = errorType;
        errorLog.Subject__c = subject;
        errorLog.API_Request__c = requestBody;
        errorLog.API_Response__c = responseBody;
        errorLog.Description__c = 'An error occurred during the External Reviewer Sync job. See other fields for details.';
        
        if (ex != null) {
            errorLog.Name = ex.getTypeName();
            errorLog.Error_Message__c = ex.getMessage();
            errorLog.Error_Trace__c = ex.getStackTraceString();
        } else {
            errorLog.Name = 'HTTP Status Code Error';
            errorLog.Error_Message__c = 'The endpoint returned a non-success status code: ' + statusCode;
        }
        return errorLog;
    }
}