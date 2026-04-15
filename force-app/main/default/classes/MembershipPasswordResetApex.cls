public with sharing class MembershipPasswordResetApex {

    // Inner wrapper class to easily deserialize the JSON response from the external API
    public class ApiResponse {
        public Boolean success;
        public String message;
        public Data data;
    }

    // Inner class representing the 'data' object in the JSON response
    public class Data {
        public Integer userId;
        public String email;
    }

    @AuraEnabled(cacheable=false)
    public static String processWebhook(Id recordId) {
        // --- START OF PROCESS ---
        System.debug('MembershipPasswordResetApex.processWebhook --- START ---');
        System.debug('Processing webhook for Record ID: ' + recordId);
        
        // --- Step 1: Query for the encryption key ---
        System.debug('Step 1: Querying for Custom Metadata Type [Membership_Shared_Secret__mdt]');
        Membership_Shared_Secret__mdt keyRecord;
        try {
            keyRecord = [
                SELECT Base_64_Key__c
                FROM Membership_Shared_Secret__mdt 
                WHERE DeveloperName = 'Membership_Secret'
                LIMIT 1
            ];
        } catch (QueryException e) {
            System.debug('FATAL ERROR: Query for encryption key failed. Message: ' + e.getMessage());
            logError('MembershipPasswordResetApex.processWebhook', 'Critical Error: Membership_Shared_Secret__mdt query failed. ' + e.getMessage(), recordId);
            return 'Password reset failed, Please contact your administrator!';
        }
        
        if (keyRecord == null || String.isBlank(keyRecord.Base_64_Key__c)) {
            System.debug('FATAL ERROR: Encryption key record not found or the key is blank.');
            logError('MembershipPasswordResetApex.processWebhook', 'Critical Error: Membership_Shared_Secret__mdt record not found or Base_64_Key__c is blank.', recordId);
            return 'Password reset failed, Please contact your administrator!';
        }
        System.debug('Success: Encryption key record found.');
        
        String userId;
        String personContactId;
        
        // --- Step 2: Determine record type and query for necessary Ids ---
        System.debug('Step 2: Querying for Account details.');
        try {
            List<Account> accounts = [SELECT RecordType.DeveloperName, Primary_Contact__c, Craft_User_Id__pc, PersonContactId FROM Account WHERE Id = :recordId LIMIT 1];
            if (accounts.isEmpty()) {
                System.debug('ERROR: No Account record found for the provided ID.');
                logError('MembershipPasswordResetApex.processWebhook', 'Error: Account record not found for ID: ' + recordId, recordId);
                return 'Password reset failed, Please contact your administrator!';
            }
            
            Account acc = accounts[0];
            System.debug('Account found. RecordType DeveloperName: ' + acc.RecordType.DeveloperName);
            
            if (acc.RecordType.DeveloperName == 'Organization_Account') {
                System.debug('Account is an Organization Account. Looking for Primary Contact.');
                if (acc.Primary_Contact__c != null) {
                    personContactId = acc.Primary_Contact__c;
                    System.debug('Primary Contact ID found: ' + personContactId);
                    List<Contact> primaryContacts = [SELECT Craft_User_Id__c FROM Contact WHERE Id = :acc.Primary_Contact__c LIMIT 1];
                    if (!primaryContacts.isEmpty()) {
                        userId = primaryContacts[0].Craft_User_Id__c;
                        System.debug('Craft User ID from Primary Contact: ' + userId);
                    }
                }
            } else { // Assumes Person Account
                System.debug('Account is a Person Account.');
                userId = acc.Craft_User_Id__pc;
                personContactId = acc.PersonContactId;
                System.debug('Craft User ID from Person Account: ' + userId);
                System.debug('PersonContactId from Person Account: ' + personContactId);
            }
            
            if (String.isBlank(userId) || String.isBlank(personContactId)) {
                System.debug('ERROR: Could not find a valid userId or personContactId.');
                logError('MembershipPasswordResetApex.processWebhook', 'Error: Could not determine userId or personContactId for Account ID: ' + recordId, recordId);
                return 'Password reset failed, Please contact your administrator!';
            }
            
        } catch (Exception e) {
            System.debug('ERROR: Exception during Account query. Message: ' + e.getMessage());
            logError('MembershipPasswordResetApex.processWebhook', 'Error querying Account details: ' + e.getMessage(), recordId);
            return 'Password reset failed, Please contact your administrator!';
        }
        
        // --- Step 3: Encrypt the IDs ---
        System.debug('Step 3: Encrypting IDs. User ID to encrypt: [' + userId + '], PersonContactID to encrypt: [' + personContactId + ']');
        String encryptedUserId;
        String encryptedPersonContactId;
        
        try {
            Blob cryptoKey = EncodingUtil.base64Decode(keyRecord.Base_64_Key__c);
            
            Blob userIdBlob = Blob.valueOf(userId);
            Blob encryptedUserIdBlob = Crypto.encryptWithManagedIV('AES256', cryptoKey, userIdBlob);
            encryptedUserId = EncodingUtil.base64Encode(encryptedUserIdBlob);
            
            Blob personContactIdBlob = Blob.valueOf(personContactId);
            Blob encryptedPersonContactIdBlob = Crypto.encryptWithManagedIV('AES256', cryptoKey, personContactIdBlob);
            encryptedPersonContactId = EncodingUtil.base64Encode(encryptedPersonContactIdBlob);

            System.debug('Success: Encryption complete.');
            
        } catch (Exception e) {
            System.debug('FATAL ERROR: Encryption failed. Message: ' + e.getMessage());
            logError('MembershipPasswordResetApex.processWebhook', 'Encryption failed: ' + e.getMessage(), recordId);
            return 'Password reset failed, Please contact your administrator!';
        }
        
        // --- Step 4: Create the body for the POST request ---
        System.debug('Step 4: Building HTTP request body.');
        String requestBody = 'userId=' + EncodingUtil.urlEncode(encryptedUserId, 'UTF-8') +
            '&personContactId=' + EncodingUtil.urlEncode(encryptedPersonContactId, 'UTF-8');
        System.debug('Request Body built successfully.');

        // --- Step 5: Perform the API Callout ---
        System.debug('Step 5: Preparing for API Callout.');
        List<CMS_Base_URL__mdt> keyRecords = [SELECT Base_URL__c FROM CMS_Base_URL__mdt LIMIT 1];
        String baseUrl = (!keyRecords.isEmpty()) ? keyRecords[0].Base_URL__c + '/platform/initiate-password-reset' : '';
        
        if (String.isBlank(baseUrl)) {
            System.debug('FATAL ERROR: CMS Base URL not configured in custom metadata.');
            logError('MembershipPasswordResetApex.processWebhook', 'Critical Error: CMS_Base_URL__mdt not configured.', recordId);
            return 'Password reset failed, Please contact your administrator!';
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
            
            // --- Step 6: Handle and Validate the FINAL Response ---
            System.debug('Final Response Status Code: ' + response.getStatusCode());
            System.debug('Final Response Body: ' + response.getBody());
            
            if (response.getStatusCode() == 200) {
                String responseBody = response.getBody();
                try {
                    // Deserialize the JSON response into our wrapper class
                    ApiResponse apiResponse = (ApiResponse)JSON.deserialize(responseBody, ApiResponse.class);

                    // Check if the response contains the expected success values
                    if (apiResponse.success == true &&
                        'OK'.equalsIgnoreCase(apiResponse.message) &&
                        apiResponse.data != null &&
                        apiResponse.data.userId != null &&
                        String.isNotBlank(apiResponse.data.email))
                    {
                        System.debug('SUCCESS: API response validated successfully.');
                        return 'Password reset initiated successfully';
                    } else {
                        // The API returned 200 OK, but the body content indicates a failure
                        String validationError = 'API response validation failed. Response: ' + responseBody;
                        System.debug('ERROR: ' + validationError);
                        logError('MembershipPasswordResetApex.processWebhook', validationError, recordId);
                        return 'Password reset failed, Please contact your administrator!';
                    }

                } catch (Exception e) {
                    // This catches errors if the response body is not valid JSON
                    String parseError = 'Failed to parse API response body. Body: ' + responseBody + '. Error: ' + e.getMessage();
                    System.debug('ERROR: ' + parseError);
                    logError('MembershipPasswordResetApex.processWebhook', parseError, recordId);
                    return 'Password reset failed, Please contact your administrator!';
                }
            } else {
                // The API call itself failed (e.g., 404, 500 error)
                String errorMessage = 'API Error: ' + response.getStatusCode() + ' - ' + response.getStatus() + ' - ' + response.getBody();
                System.debug('ERROR: API returned a non-200 status code.');
                logError('MembershipPasswordResetApex.processWebhook', errorMessage, recordId);
                return 'Password reset failed, Please contact your administrator!';
            }
            
        } catch (Exception e) {
            System.debug('FATAL ERROR: Apex Callout Exception. Type: ' + e.getTypeName() + '. Message: ' + e.getMessage());
            String errorMessage = 'Apex Callout Exception: ' + e.getTypeName() + ' - ' + e.getMessage();
            logError('MembershipPasswordResetApex.processWebhook', errorMessage, recordId);
            return 'Password reset failed, Please contact your administrator!';
        }
    }
    
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
            // If the error log fails, we can't do much but write to the main debug log.
            System.debug('CRITICAL FAILURE: Could not insert record into Error__c object. Reason: ' + ex.getMessage());
        }
    }
}