public class ApplicationReviewCalloutHandler {

    // Main method called by the trigger. No changes needed here.
    public static void handleAfterUpdate(List<ApplicationReview> newReviews, Map<Id, ApplicationReview> oldReviewMap) {
        Set<Id> reviewIdsForCallout = new Set<Id>();
        for (ApplicationReview review : newReviews) {
            ApplicationReview oldReview = oldReviewMap.get(review.Id);
            if (oldReview.External_Reviewer__c == null && review.External_Reviewer__c != null) {
                reviewIdsForCallout.add(review.Id);
            }
        }
        if (!reviewIdsForCallout.isEmpty()) {
            makeHttpRequest(reviewIdsForCallout);
        }
    }

    // Asynchronous method to perform the callout.
    @future(callout=true)
    public static void makeHttpRequest(Set<Id> reviewIds) {
        
        List<ApplicationReview> reviewsToProcess = [
            SELECT Id, Submission_Id__c, External_Reviewer__c, External_Reviewer__r.IsActive__c, External_Reviewer__r.Submittable_User_Id__c
            FROM ApplicationReview 
            WHERE Id IN :reviewIds
        ];

        // ====================================================================
        // NEW LOGIC: Initialize lists to aggregate IDs for a single bulk callout.
        // ====================================================================
        List<String> submissionIds = new List<String>();
        List<String> assignTeamMemberUserIds = new List<String>();
        List<String> unAssignTeamMemberUserIds = new List<String>(); // Per requirement, this will be empty.

        for (ApplicationReview review : reviewsToProcess) {
            // Only include reviewers that are active.
            if (review.External_Reviewer__r != null && review.External_Reviewer__r.IsActive__c == true) {
                // Add the IDs from the valid records to our lists.
                submissionIds.add(review.Submission_Id__c);
                assignTeamMemberUserIds.add(review.External_Reviewer__r.Submittable_User_Id__c); // This field holds the Submittable_User_Id__c
            } else {
                System.debug('SKIPPED: Assignment for Review ID ' + review.Id + 
                             ' was not included because the assigned reviewer (' + review.External_Reviewer__r.Submittable_User_Id__c + ') is inactive or null.');
            }
        }

        // ====================================================================
        // NEW LOGIC: Perform a single callout only if there are valid records to process.
        // ====================================================================
        if (!submissionIds.isEmpty()) {
            
            HttpRequest request = new HttpRequest();
            request.setEndpoint('callout:Submittable_API/v4/submissions/assignments');
            request.setMethod('PUT'); // Set method to PUT
            request.setHeader('Content-Type', 'application/json;charset=UTF-8');
            
            // Build the request body with the new structure
            Map<String, List<String>> bodyMap = new Map<String, List<String>>();
            bodyMap.put('submissionIds', submissionIds);
            bodyMap.put('assignTeamMemberUserIds', assignTeamMemberUserIds);
            bodyMap.put('unAssignTeamMemberUserIds', unAssignTeamMemberUserIds);

            String jsonBody = JSON.serialize(bodyMap);
            request.setBody(jsonBody);
            
            System.debug('API Request Body: ' + jsonBody);

            try {
                Http http = new Http();
                HttpResponse response = http.send(request);

                System.debug('API Status Code: ' + response.getStatusCode());
                System.debug('API Response Body: ' + response.getBody());

                if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                    // Log an error for the entire bulk request.
                    insert createErrorLog(
                        'Endpoint Error', 'Bulk API Assignment Error',
                        jsonBody, response.getBody(), String.valueOf(response.getStatusCode()), null
                    );
                } else {
                    System.debug('SUCCESS: Bulk assignment callout completed successfully. Status Code: ' + response.getStatusCode());
                }

            } catch (System.CalloutException e) {
                // Log a system error if the callout fails to send.
                insert createErrorLog(
                    'System Error', 'Bulk Callout Failure for Application Review Assignment',
                    jsonBody, null, null, e
                );
            }
        } else {
            System.debug('SKIPPED: Callout was not made because no active reviewers were assigned.');
        }
    }

    // Helper method to build the Error__c object. No changes needed.
    private static Error__c createErrorLog(String errorType, String subject, String requestBody, String responseBody, String statusCode, Exception ex) {
        Error__c errorLog = new Error__c();

        errorLog.Error_Type__c = errorType;
        errorLog.Subject__c = subject;
        errorLog.API_Request__c = requestBody;
        errorLog.API_Response__c = responseBody;
        errorLog.Description__c = 'An error occurred during a bulk HTTP callout for Application Review updates.';
        
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