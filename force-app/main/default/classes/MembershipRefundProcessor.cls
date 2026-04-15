public with sharing class MembershipRefundProcessor {

    @AuraEnabled(cacheable=false)
    public static String processRefund(Id refundId) {
        
        System.debug('=== RefundProcessor Started ===');
        System.debug('Input refundId: ' + refundId);
        
        // --- Step 1: Query for the encryption key ---
        System.debug('Step 1: Querying encryption key...');
        Membership_Shared_Secret__mdt keyRecord;
        try {
            keyRecord = [
                SELECT Base_64_Key__c
                FROM Membership_Shared_Secret__mdt 
                WHERE DeveloperName = 'Membership_Secret'
                LIMIT 1
            ];
            System.debug('Encryption key found: ' + (keyRecord != null));
        } catch (QueryException e) {
            System.debug('ERROR - Encryption key query failed: ' + e.getMessage());
            logError('RefundProcessor.processRefund', 'Critical Error: Membership_Shared_Secret__mdt query failed. ' + e.getMessage(), refundId);
            return 'Refund Failed';
        }

        if (keyRecord == null || String.isBlank(keyRecord.Base_64_Key__c)) {
            System.debug('ERROR - Encryption key is null or blank');
            logError('RefundProcessor.processRefund', 'Critical Error: Membership_Shared_Secret__mdt record not found or Base_64_Key__c is blank.', refundId);
            return 'Refund Failed';
        }
        System.debug('Step 1 COMPLETE: Encryption key validated');

        // --- Step 2: Determine refund type and query Commerce Reference ID ---
        System.debug('Step 2: Detecting refund object type...');
        String commerceReferenceId;
        Id transactionId;
        
        String objectType = refundId.getSObjectType().getDescribe().getName();
        System.debug('Detected object type: ' + objectType);
        
        try {
            if (objectType == 'GiftRefund') {
                System.debug('Processing GiftRefund...');
                List<GiftRefund> giftRefunds = [
                    SELECT Id, GiftTransaction.Id, GiftTransaction.Craft_Commerce_Reference_Id__c
                    FROM GiftRefund 
                    WHERE Id = :refundId 
                    LIMIT 1
                ];
                
                System.debug('GiftRefund query results: ' + giftRefunds.size());
                if (giftRefunds.isEmpty()) {
                    System.debug('ERROR - GiftRefund not found');
                    logError('RefundProcessor.processRefund', 'Error: GiftRefund record not found for ID: ' + refundId, refundId);
                    return 'Refund Failed';
                }
                
                GiftRefund giftRefundRecord = giftRefunds[0];
                transactionId = giftRefundRecord.GiftTransaction.Id;
                commerceReferenceId = giftRefundRecord.GiftTransaction.Craft_Commerce_Reference_Id__c;
                System.debug('GiftRefund - TransactionId: ' + transactionId + ', CommerceRefId: ' + commerceReferenceId);
                
            } else if (objectType == 'Membership_Refund__c') {
                System.debug('Processing Membership_Refund__c...');
                List<Membership_Refund__c> refunds = [
                    SELECT Id, Membership_Transaction__r.Id, Membership_Transaction__r.Craft_Commerce_Reference_Id__c 
                    FROM Membership_Refund__c 
                    WHERE Id = :refundId 
                    LIMIT 1
                ];
                
                System.debug('Membership_Refund__c query results: ' + refunds.size());
                if (refunds.isEmpty()) {
                    System.debug('ERROR - Membership_Refund__c not found');
                    logError('RefundProcessor.processRefund', 'Error: Membership_Refund__c record not found for ID: ' + refundId, refundId);
                    return 'Refund Failed';
                }
                
                Membership_Refund__c refundRecord = refunds[0];
                transactionId = refundRecord.Membership_Transaction__r.Id;
                commerceReferenceId = refundRecord.Membership_Transaction__r.Craft_Commerce_Reference_Id__c;
                System.debug('MembershipRefund - TransactionId: ' + transactionId + ', CommerceRefId: ' + commerceReferenceId);
                
            } else {
                System.debug('ERROR - Unsupported object type: ' + objectType);
                logError('RefundProcessor.processRefund', 'Error: Unsupported refund object type: ' + objectType + ' for ID: ' + refundId, refundId);
                return 'Refund Failed';
            }
        } catch (Exception e) {
            System.debug('ERROR - Query failed: ' + e.getMessage());
            logError('RefundProcessor.processRefund', 'Query failed for refund ID ' + refundId + ': ' + e.getMessage(), refundId);
            return 'Refund Failed';
        }

        if (String.isBlank(commerceReferenceId)) {
            System.debug('ERROR - Commerce Reference ID is blank');
            logError('RefundProcessor.processRefund', 'Error: Craft_Commerce_Reference_Id__c not found on the related transaction.', refundId);
            return 'Refund Failed';
        }
        System.debug('Step 2 COMPLETE: CommerceRefId validated - ' + commerceReferenceId);

        // --- Step 3: Encrypt the IDs ---
        System.debug('Step 3: Starting encryption...');
        String encryptedRefundIdString;
        String encryptedCommerceIdString;

        try {
            Blob cryptoKey = EncodingUtil.base64Decode(keyRecord.Base_64_Key__c);
            System.debug('Crypto key decoded successfully');
            
            Blob transactionIdBlob = Blob.valueOf(String.valueOf(transactionId));
            Blob encryptedRefundId = Crypto.encryptWithManagedIV('AES256', cryptoKey, transactionIdBlob);
            encryptedRefundIdString = EncodingUtil.base64Encode(encryptedRefundId);
            System.debug('Transaction ID encrypted: ' + encryptedRefundIdString.substring(0, 20) + '...');

            Blob commerceIdBlob = Blob.valueOf(commerceReferenceId);
            Blob encryptedCommerceId = Crypto.encryptWithManagedIV('AES256', cryptoKey, commerceIdBlob);
            encryptedCommerceIdString = EncodingUtil.base64Encode(encryptedCommerceId);
            System.debug('Commerce ID encrypted: ' + encryptedCommerceIdString.substring(0, 20) + '...');

        } catch (Exception e) {
            System.debug('ERROR - Encryption failed: ' + e.getMessage());
            logError('RefundProcessor.processRefund', 'Encryption failed: ' + e.getMessage(), refundId);
            return 'Refund Failed';
        }
        System.debug('Step 3 COMPLETE: Both IDs encrypted');

        // --- Step 4: Create the JSON Body ---
        System.debug('Step 4: Creating JSON payload...');
        Map<String, String> requestBodyMap = new Map<String, String>();
        requestBodyMap.put('transactionId', encryptedRefundIdString);
        requestBodyMap.put('commerceReferenceId', encryptedCommerceIdString);
        requestBodyMap.put('type', 'membership');

        String jsonBody = JSON.serialize(requestBodyMap);
        System.debug('JSON Payload: ' + jsonBody);
        
        List<CMS_Base_URL__mdt> keyRecords = [SELECT Base_URL__c FROM CMS_Base_URL__mdt LIMIT 1];
        String baseUrl = (!keyRecords.isEmpty()) ? keyRecords[0].Base_URL__c + '/commerce/refund' : '';
        System.debug('baseUrl: ' + baseUrl);
        System.debug('Step 4 COMPLETE: JSON payload ready');

        // --- Step 5: Perform API Callout ---
        System.debug('Step 5: Making API callout to: ' + baseUrl);
        HttpRequest request = new HttpRequest();
        request.setEndpoint(baseUrl);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json;charset=UTF-8');
        request.setBody(jsonBody);
        
        Http http = new Http();
        HttpResponse response;

        try {
            System.debug('Sending HTTP request...');
            response = http.send(request);
            System.debug('Initial response status: ' + response.getStatusCode() + ' ' + response.getStatus());

            // Handle 301 Redirect
            if (response.getStatusCode() == 301) {
                String newUrl = response.getHeader('Location');
                System.debug('301 Redirect detected. New URL: ' + newUrl);

                if (String.isNotBlank(newUrl)) {
                    HttpRequest redirectRequest = new HttpRequest();
                    redirectRequest.setEndpoint(newUrl);
                    redirectRequest.setMethod('POST');
                    redirectRequest.setHeader('Content-Type', 'application/json;charset=UTF-8');
                    redirectRequest.setBody(jsonBody); 
                    
                    System.debug('Sending redirect request...');
                    response = http.send(redirectRequest);
                    System.debug('Redirect response status: ' + response.getStatusCode() + ' ' + response.getStatus());
                }
            }
            
            // --- Step 6: Handle Response ---
            System.debug('Final response status: ' + response.getStatusCode());
            System.debug('Final response body: ' + response.getBody());
            
            if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                System.debug('SUCCESS: API call completed successfully');
                return 'Refund Processing';
            } else {
                String errorMessage = 'API Error: ' + response.getStatusCode() + ' - ' + response.getStatus() + ' - ' + response.getBody();
                System.debug('ERROR - API failed: ' + errorMessage);
                logError('RefundProcessor.processRefund', errorMessage, refundId);
                return 'Refund Failed';
            }

        } catch (Exception e) {
            String errorMessage = 'Apex Callout Exception: ' + e.getTypeName() + ' - ' + e.getMessage();
            System.debug('ERROR - Callout exception: ' + errorMessage);
            logError('RefundProcessor.processRefund', errorMessage, refundId);
            return 'Refund Failed';
        }
    }

    private static void logError(String classNameMethod, String errorMessage, Id relatedRecordId) {
        System.debug('Logging error to Error__c: ' + errorMessage);
        try {
            Error__c errorLog = new Error__c(
                Error_Trace__c = classNameMethod,
                Error_Message__c = errorMessage,
                Error_Type__c  = relatedRecordId
            );
            insert errorLog;
            System.debug('Error logged successfully to Error__c');
        } catch (Exception ex) {
            System.debug('Failed to log error to Error__c object: ' + ex.getMessage());
        }
    }
}