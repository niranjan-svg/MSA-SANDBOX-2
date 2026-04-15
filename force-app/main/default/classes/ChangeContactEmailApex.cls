public with sharing class ChangeContactEmailApex {

    /**
     * Inner class to define the input variables for the Invocable Method.
     * This allows the method to be easily used within a Salesforce Flow.
     */
    public class InvocableRequest {
        @InvocableVariable(label='Encrypted User ID' description='The pre-encrypted Craft User ID.' required=true)
        public String userId;

        @InvocableVariable(label='Encrypted Person Contact ID' description='The pre-encrypted Person Contact ID.' required=true)
        public String personContactId;

        @InvocableVariable(label='New Email Address' description='The new email address for the user.' required=true)
        public String newEmail;
    }

    /**
     * Inner class to define the output variable for the Invocable Method.
     */
    public class InvocableResponse {
        @InvocableVariable(label='Result' description='The result of the operation, e.g., "Success" or "Failed".')
        public String result;
    }

    /**
     * This method is invokable by a Salesforce Flow. It takes a list of requests
     * to initiate an email change for a user via an external API.
     */
    @InvocableMethod(label='Change Contact Email' description='Sends a request to the CMS to change a contact\'s email address.')
    public static List<InvocableResponse> changeEmail(List<InvocableRequest> requests) {
        List<InvocableResponse> responses = new List<InvocableResponse>();
        
        // Even though it's a list, a Flow typically sends one request at a time.
        for (InvocableRequest req : requests) {
            String result = processEmailChange(req.userId, req.personContactId, req.newEmail);
            InvocableResponse res = new InvocableResponse();
            res.result = result;
            responses.add(res);
        }
        
        return responses;
    }

    /**
     * Private helper method to handle the core logic of the API callout.
     */
    private static String processEmailChange(String encryptedUserId, String encryptedPersonContactId, String newEmail) {
        System.debug('ChangeContactEmailApex.processEmailChange --- START ---');

        // --- Step 1: Validate Input Parameters ---
        if (String.isBlank(encryptedUserId) || String.isBlank(encryptedPersonContactId) || String.isBlank(newEmail)) {
            logError('ChangeContactEmailApex.processEmailChange', 'Critical Error: One or more required parameters (userId, personContactId, newEmail) are blank.', null);
            return 'Failed';
        }
        
        // --- Step 2: Create the body for the POST request ---
        System.debug('Step 2: Building HTTP request body.');
        String requestBody = 'userId=' + EncodingUtil.urlEncode(encryptedUserId, 'UTF-8') +
                             '&personContactId=' + EncodingUtil.urlEncode(encryptedPersonContactId, 'UTF-8') +
                             '&newEmail=' + EncodingUtil.urlEncode(newEmail, 'UTF-8');
        System.debug('Request Body built successfully.');

        // --- Step 3: Perform the API Callout ---
        System.debug('Step 3: Preparing for API Callout.');
        List<CMS_Base_URL__mdt> keyRecords = [SELECT Base_URL__c FROM CMS_Base_URL__mdt LIMIT 1];
        // NOTE: Replace '/platform/change-email' with the actual endpoint for this functionality.
        String baseUrl = (!keyRecords.isEmpty()) ? keyRecords[0].Base_URL__c + '/platform/change-email' : '';
        
        if (String.isBlank(baseUrl)) {
            System.debug('FATAL ERROR: CMS Base URL not configured in custom metadata.');
            logError('ChangeContactEmailApex.processEmailChange', 'Critical Error: CMS_Base_URL__mdt not configured.', null);
            return 'Failed';
        }
        
        System.debug('Sending POST request to endpoint: ' + baseUrl);
        
        HttpRequest request = new HttpRequest();
        request.setEndpoint(baseUrl);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        request.setBody(requestBody);
        
        Http http = new Http();
        HttpResponse response;
        
        try {
            response = http.send(request);

            // --- Handle 301 Redirect ---
            if (response.getStatusCode() == 301) {
                String newUrl = response.getHeader('Location');
                System.debug('Redirect detected (301). New URL: ' + newUrl);

                if (String.isNotBlank(newUrl)) {
                    HttpRequest redirectRequest = new HttpRequest();
                    redirectRequest.setEndpoint(newUrl);
                    redirectRequest.setMethod('POST');
                    redirectRequest.setHeader('Content-Type', 'application/x-www-form-urlencoded');
                    redirectRequest.setBody(requestBody); 
                    
                    System.debug('Sending POST request to redirected URL: ' + newUrl);
                    response = http.send(redirectRequest);
                } else {
                     System.debug('ERROR: 301 Redirect received but Location header is blank.');
                }
            }
            
            // --- Step 4: Handle the FINAL Response ---
            System.debug('Step 4: Handling API Response.');
            System.debug('Response Status Code: ' + response.getStatusCode());
            System.debug('Response Status: ' + response.getStatus());
            System.debug('Response Body: ' + response.getBody());
            
            if (response.getStatusCode() == 200) {
                System.debug('SUCCESS: Email change processed successfully with 200 OK response.');
                return 'Success';
            } else {
                System.debug('ERROR: API returned a non-200 status code.');
                String errorMessage = 'API Error: ' + response.getStatusCode() + ' - ' + response.getStatus() + ' - ' + response.getBody();
                logError('ChangeContactEmailApex.processEmailChange', errorMessage, null);
                return 'Failed';
            }
            
        } catch (Exception e) {
            System.debug('FATAL ERROR: Apex Callout Exception. Type: ' + e.getTypeName() + '. Message: ' + e.getMessage());
            String errorMessage = 'Apex Callout Exception: ' + e.getTypeName() + ' - ' + e.getMessage();
            logError('ChangeContactEmailApex.processEmailChange', errorMessage, null);
            return 'Failed';
        }
    }
    
    /**
     * Logs an error to the custom Error__c object.
     */
    private static void logError(String classNameMethod, String errorMessage, Id relatedRecordId) {
        System.debug('logError method called. Logging error to Error__c object.');
        System.debug('Error Details --- Class/Method: ' + classNameMethod + ' --- Message: ' + errorMessage);
        try {
            Error__c errorLog = new Error__c(
                Error_Trace__c = classNameMethod,
                Error_Message__c = errorMessage,
                Error_Type__c  = relatedRecordId 
            );
            insert errorLog;
        } catch (Exception ex) {
            System.debug('CRITICAL FAILURE: Could not insert record into Error__c object. Reason: ' + ex.getMessage());
        }
    }
}