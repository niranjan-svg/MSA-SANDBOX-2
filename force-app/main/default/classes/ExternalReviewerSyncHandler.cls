public class ExternalReviewerSyncHandler {
    @Future(callout=true)
    public static void getReviewers(){
        List<Error__c> errorsToInsert = new List<Error__c>();
        String requestBody = null; // A GET request has no body, so this will be null.
        
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:Submittable_API/v4/organizations/team'); // Use your Named Credential
        request.setMethod('GET');
        request.setHeader('Content-Type', 'application/json');
        
        try {
            Http http = new Http();
            HttpResponse response = http.send(request);
            
            // Check if the callout was successful (status code in the 200-299 range)
            if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                ExternalReviewerResponseWrapper wrapper = (ExternalReviewerResponseWrapper)JSON.deserialize(response.getBody(), ExternalReviewerResponseWrapper.class);
                system.debug('statuscode---------19'+response.getStatusCode());
                system.debug('body---------20'+response.getbody());             
                
                if (wrapper != null && wrapper.teamMembers != null && !wrapper.teamMembers.isEmpty()) {
                    // Pass the list of potential errors to the processing method
                    errorsToInsert.addAll(processReviewerData(wrapper.teamMembers));
                }
            } else {
                system.debug('statuscode---------27'+response.getStatusCode());
                system.debug('body---------28'+response.getbody()); 
                // This is an Endpoint Error (e.g., 404 Not Found, 500 Server Error)
                errorsToInsert.add(ErrorLoggingApex.createErrorLog(
                    'Endpoint Error',
                    'External Reviewer Sync Job Failed',
                    requestBody,
                    response.getBody(),
                    String.valueOf(response.getStatusCode()),
                    null // No Apex exception object in this case
                ));
            }
        } catch (System.CalloutException e) {
            // This is a System Error (e.g., URL is wrong, timeout, unable to connect)
            system.debug('error message in catch-----'+e.getMessage());
            errorsToInsert.add(ErrorLoggingApex.createErrorLog(
                'System Error',
                'External Reviewer Sync Job Failed',
                requestBody,
                null, // No response body was received
                null, // No status code was received
                e     // The Apex exception object itself
            ));
        }
        
        // --- Final Step: Insert any errors that were logged ---
        if (!errorsToInsert.isEmpty()) {
            insert errorsToInsert;
        }
    }
    // This method now returns a list of any errors that occurred during DML
    private static List<Error__c> processReviewerData(List<ExternalReviewerResponseWrapper.TeamMember> membersFromResponse) {
        Set<String> userIdsFromResponse = new Set<String>();
        for(ExternalReviewerResponseWrapper.TeamMember member : membersFromResponse) {
            userIdsFromResponse.add(member.userId);
        }
        system.debug('userIdsFromResponse----'+userIdsFromResponse);
        
        Map<String, External_Reviewer__c> existingReviewersMap = new Map<String, External_Reviewer__c>();
        for (External_Reviewer__c existingReviewer : [SELECT Id, Submittable_User_Id__c FROM External_Reviewer__c WHERE Submittable_User_Id__c IN :userIdsFromResponse]) {
            existingReviewersMap.put(existingReviewer.Submittable_User_Id__c, existingReviewer);
        }
        
        List<External_Reviewer__c> reviewersToInsert = new List<External_Reviewer__c>();
        for (ExternalReviewerResponseWrapper.TeamMember member : membersFromResponse) {
            if (!existingReviewersMap.containsKey(member.userId)) {
                External_Reviewer__c newReviewer = new External_Reviewer__c();
                if (member.name != null) newReviewer.Name = member.name.full;
                newReviewer.Submittable_User_Id__c = member.userId;
                newReviewer.Email__c = member.email;
                newReviewer.Title__c = member.title;
                newReviewer.Last_login_date_on_Submittable__c = member.lastLoginDate;
                newReviewer.Permission_Level__c = member.permissionLevel;
                if (member.roles != null && !member.roles.isEmpty()) newReviewer.Role_Id__c = member.roles[0].id;
                newReviewer.IsActive__c = true;
                reviewersToInsert.add(newReviewer);
            }
        }
        
        List<Error__c> dmlErrors = new List<Error__c>();
        if (!reviewersToInsert.isEmpty()) {
            try {
                insert reviewersToInsert;
            } catch (DmlException e) {
                // This is a DML Error (e.g., validation rule failure, required field missing)
                for (Integer i = 0; i < e.getNumDml(); i++) {
                    // Get the record that failed
                    External_Reviewer__c failedReviewer = reviewersToInsert.get(e.getDmlIndex(i));
                    
                    // Serialize the failed record to log what we tried to insert
                    String failedRecordJson = JSON.serialize(failedReviewer);
                    
                    dmlErrors.add(ErrorLoggingApex.createErrorLog(
                        'DML Error',
                        'Failed to insert External Reviewer with UserID: ' + failedReviewer.Submittable_User_Id__c,
                        failedRecordJson, // Log the record data as the "request"
                        null,
                        null,
                        e
                    ));
                }
            }
        }
        return dmlErrors;
    }
    
    // Helper method to build the Error__c object, adapted from your example.
    /*private static Error__c createErrorLog(String errorType, String subject, String requestBody, String responseBody, String statusCode, Exception ex) {
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
    }*/
}