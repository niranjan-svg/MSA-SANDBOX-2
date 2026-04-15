public class SubmittableFormSyncQueueable implements Queueable, Database.AllowsCallouts {
    
    private Map<Id, String> individualAppIdToSubmissionIdMap;
    
    public SubmittableFormSyncQueueable(Map<Id, String> appMap) {
        this.individualAppIdToSubmissionIdMap = appMap;
    }
    
    public void execute(QueueableContext context) {
        if (individualAppIdToSubmissionIdMap == null || individualAppIdToSubmissionIdMap.isEmpty()) {
            return;
        }
        
        // Process one application at a time
        Id individualAppId = individualAppIdToSubmissionIdMap.keySet().iterator().next();
        String submissionId = individualAppIdToSubmissionIdMap.get(individualAppId);
        
        processFormsForSubmission(individualAppId, submissionId);
        
        // Remove the processed item and re-enqueue if necessary
        individualAppIdToSubmissionIdMap.remove(individualAppId);
        if (!individualAppIdToSubmissionIdMap.isEmpty()) {
            System.enqueueJob(new SubmittableFormSyncQueueable(this.individualAppIdToSubmissionIdMap));
        }
    }
    
    private void processFormsForSubmission(Id individualAppId, String submissionId) {
        // 1. Get Form Data
        List<Object> formEntries = getFormEntries(submissionId);
        if (formEntries == null || formEntries.isEmpty()) return;
        //Map<String, Map<String, String>> formIdToQuestionMap = getFormMetadata(formEntries);
        Map<String, Map<String, Object>> formIdToFieldDefinitionMap = getFormMetadata(formEntries);
        
        // 2. Prepare Records for Processing
        IndividualApplication appToUpdate = new IndividualApplication(Id = individualAppId);
        List<ApplicationReview> reviewsToProcess = new List<ApplicationReview>();
        Map<String, String> entryIdToReviewerIdMap = new Map<String, String>();
        
        // This now correctly references the public FileToSync class and will compile
        List<FileToSync> filesToSync = new List<FileToSync>();
        
        Set<String> reviewEntryIds = new Set<String>();
        
        // 3. Loop through API response to build records
        for (Object formEntryObj : formEntries) {
            Map<String, Object> formEntry = (Map<String, Object>) formEntryObj;
            String formType = (String) formEntry.get('formType');
            Map<String, Object> entryData = (Map<String, Object>) formEntry.get('entry');
            if (entryData == null) continue;
            
            String formId = (String) entryData.get('formId');
            String entryId = (String) entryData.get('entryId');
            List<Object> fieldDataList = (List<Object>) entryData.get('fieldData');
            
            
            // Pass the filesToSync list into the helper method
            //String richTextContent = buildRichText(fieldDataList, formIdToQuestionMap.get(formId), individualAppId, filesToSync);
            String richTextContent = buildRichText(fieldDataList, formIdToFieldDefinitionMap.get(formId), individualAppId, filesToSync);
            
            // NOTE: Please ensure these Field API names match your Salesforce org exactly.
            if ('initial'.equalsIgnoreCase(formType)){
                appToUpdate.FundingRequestPurpose = richTextContent;
                 appToUpdate.Initial_Form_Id__c = formId;
            } 
            else if ('eligibility'.equalsIgnoreCase(formType)){
                appToUpdate.Eligibility_Form__c = richTextContent;
                 appToUpdate.Eligibility_Form_Id__c = formId;
            } 
            else if ('internal'.equalsIgnoreCase(formType)){
                appToUpdate.Internal_Form__c = richTextContent;
                appToUpdate.Internal_Form_Id__c = formId;
            } 
            else if ('additional'.equalsIgnoreCase(formType)){
                 appToUpdate.Additional_Form__c = richTextContent;
                	appToUpdate.Additional_Form_Id__c = formId;
            }
            else if ('review'.equalsIgnoreCase(formType) && entryId != null) {
                reviewEntryIds.add(entryId);
                ApplicationReview review = new ApplicationReview();
                review.ApplicationId = individualAppId;
                review.Submittable_Entry_ID__c = entryId;
                review.Submittable_Review_Stage_Id__c = (String) entryData.get('stageId');
                review.Submittable_Review_Form_Id__c = formId;
                review.Status = (String) entryData.get('status');
                review.Review_Form__c = richTextContent;
                review.Score__c = (Decimal) entryData.get('score');
                if(entryData.get('completedAt') != null){
                    String completedAtStr = (String)entryData.get('completedAt');
                    review.EndDate = ((Datetime)JSON.deserialize('"' + completedAtStr + '"', DateTime.class)).date();
                }
                String reviewerId = (String) entryData.get('reviewerId');
                if(reviewerId != null) entryIdToReviewerIdMap.put(entryId, reviewerId);
                reviewsToProcess.add(review);
            }
            
            
        }
        
        // 4. Link Reviewers and sort reviews into insert/update lists
        Map<String, Id> submittableIdToReviewerIdMap = new Map<String, Id>();
        if(!entryIdToReviewerIdMap.isEmpty()){
            // NOTE: Ensure the field API Name `Submittable_User_ID__c` on External_Reviewer__c is correct.
            for(External_Reviewer__c er : [SELECT Id, Submittable_User_ID__c FROM External_Reviewer__c WHERE Submittable_User_ID__c IN :entryIdToReviewerIdMap.values()]){
                submittableIdToReviewerIdMap.put(er.Submittable_User_ID__c, er.Id);
            }
        }
        
        Map<String, ApplicationReview> existingReviewsMap = new Map<String, ApplicationReview>();
        if(!reviewEntryIds.isEmpty()){
            for(ApplicationReview ar : [SELECT Id, Submittable_Entry_ID__c FROM ApplicationReview WHERE Submittable_Entry_ID__c IN :reviewEntryIds]){
                existingReviewsMap.put(ar.Submittable_Entry_ID__c, ar);
            }
        }
        
        List<ApplicationReview> reviewsToInsert = new List<ApplicationReview>();
        List<ApplicationReview> reviewsToUpdate = new List<ApplicationReview>();
        
        for(ApplicationReview review : reviewsToProcess) {
            String reviewerId = entryIdToReviewerIdMap.get(review.Submittable_Entry_ID__c);
            if(reviewerId != null && submittableIdToReviewerIdMap.containsKey(reviewerId)){
                // NOTE: Ensure the lookup field API Name `External_Reviewer__c` on ApplicationReview is correct.
                review.External_Reviewer__c = submittableIdToReviewerIdMap.get(reviewerId);
            }
            if(existingReviewsMap.containsKey(review.Submittable_Entry_ID__c)){
                review.Id = existingReviewsMap.get(review.Submittable_Entry_ID__c).Id;
                reviewsToUpdate.add(review);
            } else {
                reviewsToInsert.add(review);
            }
        }
        
        // 5. Perform DML
        try {
            update appToUpdate;
            if (!reviewsToInsert.isEmpty()) insert reviewsToInsert;
            if (!reviewsToUpdate.isEmpty()) update reviewsToUpdate;
            
            // 6. Call the Future method for file sync if needed
            if (!filesToSync.isEmpty()) {
                String filesJson = JSON.serialize(filesToSync);
                SubmittableFileSyncHelper.syncFiles(filesJson);
            }
        } catch (Exception e) {
            System.debug('DML Exception in Form Sync: ' + e.getMessage());
        }
    }
    
    // --- HELPER METHODS ---
    
    private List<Object> getFormEntries(String submissionId) {
        List<Error__c> errorsToInsert = new List<Error__c>();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Submittable_API/v4/entries/submissions/' + submissionId);
        req.setMethod('GET');
        try {
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() == 200) {
                Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                return (List<Object>) results.get('formEntries');
            }
            else{
                errorsToInsert.add(ErrorLoggingApex.createErrorLog(
                    'Endpoint Error',
                    'External Reviewer Sync Job Failed',
                    req.getBody(),
                    res.getBody(),
                    String.valueOf(res.getStatusCode()),
                    null // No Apex exception object in this case
                ));
            }
        } catch (Exception ex) { 
            Error__c errorLog = new Error__c();
            errorLog.Name = ex.getTypeName();
            errorLog.Error_Message__c = ex.getMessage();
            errorLog.Error_Trace__c = ex.getStackTraceString();
            insert errorLog;
            System.debug('Failed to get entries for ' + submissionId + ': ' + ex.getMessage()); 
        }
        return null;
    }
    
    private Map<String, Map<String, Object>> getFormMetadata(List<Object> formEntries) {
        List<Error__c> errorsToInsert = new List<Error__c>();
        Set<String> formIds = new Set<String>();
        for (Object formEntryObj : formEntries) {
            Map<String, Object> entryData = (Map<String, Object>)((Map<String, Object>) formEntryObj).get('entry');
            if (entryData != null && entryData.get('formId') != null) {
                formIds.add((String) entryData.get('formId'));
            }
        }
        
        Map<String, Map<String, Object>> formIdToFieldMap  = new Map<String, Map<String, Object>>();
        for (String formId : formIds) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Submittable_API/v4/forms/' + formId);
            req.setMethod('GET');
            try {
                HttpResponse res = new Http().send(req);
                if (res.getStatusCode() == 200) {
                    Map<String, Object> formData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    List<Object> fields = (List<Object>) formData.get('fields');
                    Map<String, Object> fieldDefinitionMap  = new Map<String, Object>();
                    if (fields != null) {
                        for (Object fieldObj : fields) {
                            Map<String, Object> field = (Map<String, Object>) fieldObj;
                            fieldDefinitionMap.put((String) field.get('formFieldId'), field);
                        }
                    }
                    formIdToFieldMap.put(formId, fieldDefinitionMap);
                }
                else{
                    errorsToInsert.add(ErrorLoggingApex.createErrorLog(
                        'Endpoint Error',
                        'External Reviewer Sync Job Failed',
                        req.getBody(),
                        res.getBody(),
                        String.valueOf(res.getStatusCode()),
                        null // No Apex exception object in this case
                    ));
                }
            } catch (Exception ex) {
                Error__c errorLog = new Error__c();
                errorLog.Name = ex.getTypeName();
                errorLog.Error_Message__c = ex.getMessage();
                errorLog.Error_Trace__c = ex.getStackTraceString();
                insert errorLog;
                System.debug('Failed to get metadata for form ' + formId + ': ' + ex.getMessage());
            }
        }
        return formIdToFieldMap;
    }
    
    /*private String buildRichText(List<Object> fieldDataList, Map<String, String> questionMap, Id parentId, List<FileToSync> filesToSync) {
        if (fieldDataList == null || fieldDataList.isEmpty() || questionMap == null) return '';
        
        String result = '';
        for (Object fieldDataObj : fieldDataList) {
            Map<String, Object> fieldData = (Map<String, Object>) fieldDataObj;
            String formFieldId = (String) fieldData.get('formFieldId');
            String label = questionMap.get(formFieldId);
            if (String.isBlank(label)) continue;
            
            String value = '';
            if (fieldData.get('value') != null && String.valueOf(fieldData.get('value')) != '') {
                value = String.valueOf(fieldData.get('value')).escapeHtml4();
            } else if (fieldData.get('options') != null) {
                value = String.valueOf(fieldData.get('options')).escapeHtml4();
            } else if (fieldData.get('files') != null && !((List<Object>)fieldData.get('files')).isEmpty()) {
                List<Object> files = (List<Object>)fieldData.get('files');
                for(Object fileObj : files){
                    Map<String, Object> fileMap = (Map<String, Object>)fileObj;
                    String fileName = (String)fileMap.get('fileName');
                    String downloadUrl = (String)fileMap.get('getDownloadUrl');
                    value += '<a href="' + downloadUrl + '" target="_blank">' + fileName.escapeHtml4() + '</a><br/>';
                    
                    // This now correctly calls the constructor of the public FileToSync class
                    filesToSync.add(new FileToSync(fileName, downloadUrl, parentId));
                }
            }
            
            if(String.isNotBlank(value)){
                result += '<b>' + label.escapeHtml4() + ':</b><br/>' + value + '<br/><br/>';
            }
        }
        return result;
    }*/
    // *** MODIFIED: Method signature is updated for the new metadata map type ***
    private String buildRichText(List<Object> fieldDataList, Map<String, Object> formFieldMap, Id parentId, List<FileToSync> filesToSync) {
        if (fieldDataList == null || fieldDataList.isEmpty() || formFieldMap == null) return '';

        String result = '';
        for (Object fieldDataObj : fieldDataList) {
            Map<String, Object> fieldData = (Map<String, Object>) fieldDataObj;
            String formFieldId = (String) fieldData.get('formFieldId');
            
            // Get the entire field definition from our new map
            Map<String, Object> fieldDefinition = (Map<String, Object>)formFieldMap.get(formFieldId);
            if (fieldDefinition == null) continue;

            String label = (String)fieldDefinition.get('label');
            if (String.isBlank(label)) continue;

            String value = '';
            if (fieldData.get('value') != null && String.valueOf(fieldData.get('value')) != '') {
                value = String.valueOf(fieldData.get('value')).escapeHtml4();
            } else if (fieldData.get('options') != null) {
                // *** MODIFIED: Call the new helper method to resolve option IDs to labels ***
                value = getOptionLabels((List<Object>)fieldData.get('options'), fieldDefinition);
            } else if (fieldData.get('files') != null && !((List<Object>)fieldData.get('files')).isEmpty()) {
                List<Object> files = (List<Object>)fieldData.get('files');
                for(Object fileObj : files){
                    Map<String, Object> fileMap = (Map<String, Object>)fileObj;
                    String fileName = (String)fileMap.get('fileName');
                    String downloadUrl = (String)fileMap.get('getDownloadUrl');
                    value += '<a href="' + downloadUrl + '" target="_blank">' + fileName.escapeHtml4() + '</a><br/>';
                    
                    // This now correctly calls the constructor of the public FileToSync class
                    filesToSync.add(new FileToSync(fileName, downloadUrl, parentId));
                }
            }
            
            if(String.isNotBlank(value)){
               result += '<b>' + label.escapeHtml4() + ':</b><br/>' + value + '<br/><br/>';
            }
        }
        return result;
    }
     /**
     * @description NEW HELPER METHOD. Resolves a list of selected option IDs into a comma-separated string of their labels.
     * @param selectedOptionIds List of GUIDs from the submission entry's 'options' array.
     * @param fieldDefinition The full metadata map for the corresponding form field.
     * @return A string of the selected option labels, e.g., "Yes, No".
     */
    private String getOptionLabels(List<Object> selectedOptionIds, Map<String, Object> fieldDefinition) {
        if (selectedOptionIds == null || selectedOptionIds.isEmpty() || fieldDefinition == null || !fieldDefinition.containsKey('options')) {
            return '';
        }

        // Create a fast lookup map of Option ID -> Option Label for this specific field
        Map<String, String> optionIdToLabelMap = new Map<String, String>();
        List<Object> allPossibleOptions = (List<Object>)fieldDefinition.get('options');
        for(Object optionObj : allPossibleOptions) {
            Map<String, Object> option = (Map<String, Object>)optionObj;
            optionIdToLabelMap.put((String)option.get('formOptionId'), (String)option.get('label'));
        }

        List<String> resolvedLabels = new List<String>();
        for(Object selectedIdObj : selectedOptionIds) {
            String selectedId = (String)selectedIdObj;
            if(optionIdToLabelMap.containsKey(selectedId)) {
                resolvedLabels.add(optionIdToLabelMap.get(selectedId));
            }
        }
        
        return String.join(resolvedLabels, ', ').escapeHtml4();
    }

}