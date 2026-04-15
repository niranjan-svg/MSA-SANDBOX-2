public class SubmittableSubmissionQueueable implements Queueable, Database.AllowsCallouts {
    
    private Map<Id, String> oppIdToProjectIdMap;
    // State variables to manage pagination across chained jobs
    private String continuationToken;
    private List<SubmissionWrapper> accumulatedSubmissions;
    
    // Main constructor called by the Schedulable class
    public SubmittableSubmissionQueueable(Map<Id, String> oppMap) {
        this.oppIdToProjectIdMap = oppMap;
        this.continuationToken = null;
        this.accumulatedSubmissions = new List<SubmissionWrapper>();
    }
    
    // Private constructor used internally for chaining pagination calls
    private SubmittableSubmissionQueueable(Map<Id, String> oppMap, String token, List<SubmissionWrapper> submissions) {
        this.oppIdToProjectIdMap = oppMap;
        this.continuationToken = token;
        this.accumulatedSubmissions = submissions;
    }
    
    public void execute(QueueableContext context) {
        // --- Step 1: Determine which API call to make ---
        HttpRequest req = new HttpRequest();
        String currentProjectId = null; // Used for logging
        
        if (String.isNotBlank(this.continuationToken)) {
            // We are in the middle of paginating, so use the token ONLY.
            req.setEndpoint('callout:Submittable_API/v4/submissions?continuationToken=' + EncodingUtil.urlEncode(this.continuationToken, 'UTF-8'));
        } else {
            // This is the start of a new project.
            if (oppIdToProjectIdMap == null || oppIdToProjectIdMap.isEmpty()) {
                return; // No more work to do.
            }
            Id fundingOppId = oppIdToProjectIdMap.keySet().iterator().next();
            currentProjectId = oppIdToProjectIdMap.get(fundingOppId);
            
            // Use the Project ID and the size=500 parameter for the initial call.
            req.setEndpoint('callout:Submittable_API/v4/submissions?Projects.Include=' + EncodingUtil.urlEncode(currentProjectId, 'UTF-8') + '&size=500');
        }
        
        req.setMethod('GET');
        String nextToken = null;
        
        try {
            HttpResponse res = new Http().send(req);
            List<Error__c> errorsToInsert = new List<Error__c>();
            if (res.getStatusCode() == 200) {
                Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> items = (List<Object>) results.get('items');
                if (items != null) {
                    for (Object item : items) {
                        Map<String, Object> subData = (Map<String, Object>) item;
                        SubmissionWrapper wrap = new SubmissionWrapper();
                        wrap.submissionId = (String) subData.get('submissionId');
                        wrap.projectId = (String) subData.get('projectId');
                        wrap.submitterId = (String) subData.get('submitterId');
                        wrap.firstName = (String) subData.get('submitterFirstName');
                        wrap.lastName = (String) subData.get('submitterLastName');
                        wrap.email = (String) subData.get('submitterEmail');
                        wrap.title = (String) subData.get('submissionTitle');
                        wrap.publicOrgId = (String) subData.get('publicOrgId');
                        wrap.submissionDate = SubmittableProjectSyncHelper.parseIsoDatetime((String) subData.get('submissionDate'));
                        wrap.submissionStatus = formatSubmissionStatus((String) subData.get('submissionStatus'));
                        this.accumulatedSubmissions.add(wrap);
                    }
                }
                nextToken = (String) results.get('continuationToken');
            } else {
                 errorsToInsert.add(ErrorLoggingApex.createErrorLog(
                    'Endpoint Error',
                    'External Reviewer Sync Job Failed',
                    req.getBody(),
                    res.getBody(),
                    String.valueOf(res.getStatusCode()),
                    null // No Apex exception object in this case
                ));
                System.debug('API Error: ' + res.getBody()); 
            }
        } catch (Exception ex) {
            Error__c errorLog = new Error__c();
            errorLog.Name = ex.getTypeName();
            errorLog.Error_Message__c = ex.getMessage();
            errorLog.Error_Trace__c = ex.getStackTraceString();
            insert errorLog;
            System.debug('Exception during API callout: ' + ex.getMessage()); 
        }
        
        // --- Step 2: Decide the next action based on the API response ---
        
        if (String.isNotBlank(nextToken)) {
            // The API response has another page. Re-enqueue with the new token.
            System.enqueueJob(new SubmittableSubmissionQueueable(this.oppIdToProjectIdMap, nextToken, this.accumulatedSubmissions));
        } else {
            // This was the LAST page for the current project.
            if (!this.accumulatedSubmissions.isEmpty()) {
                Id fundingOppId = oppIdToProjectIdMap.keySet().iterator().next();
                processCompleteSubmissionList(fundingOppId, this.accumulatedSubmissions);
            }
            
            // Move to the next project in the list.
            oppIdToProjectIdMap.remove(oppIdToProjectIdMap.keySet().iterator().next());
            
            if (!oppIdToProjectIdMap.isEmpty()) {
                // Start the process for the next project without a continuation token.
                System.enqueueJob(new SubmittableSubmissionQueueable(this.oppIdToProjectIdMap));
            }
        }
    }
    
    private void processCompleteSubmissionList(Id fundingOppId, List<SubmissionWrapper> submissionWrappers) {
        
        // --- Collect all IDs needed for querying Salesforce ---
        Set<String> submissionIds = new Set<String>();
        Set<String> orgIds = new Set<String>();
        Set<String> allSubmitterIds = new Set<String>();
        
        for (SubmissionWrapper wrap : submissionWrappers) {
            submissionIds.add(wrap.submissionId);
            if (String.isNotBlank(wrap.publicOrgId)) orgIds.add(wrap.publicOrgId);
            if (String.isNotBlank(wrap.submitterId)) allSubmitterIds.add(wrap.submitterId);
        }
        
        // --- Perform all SOQL queries at once to get existing records ---
        Id personAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        
        Map<String, IndividualApplication> existingAppsMap = new Map<String, IndividualApplication>();
        if(!submissionIds.isEmpty()) for(IndividualApplication app : [SELECT Id, Submittable_Submission_ID__c, AccountId FROM IndividualApplication WHERE Submittable_Submission_ID__c IN :submissionIds]) existingAppsMap.put(app.Submittable_Submission_ID__c, app);
        
        Map<String, Account> existingOrgAccountsMap = new Map<String, Account>();
        if(!orgIds.isEmpty()) for(Account acc : [SELECT Id, Submittable_Org_ID__c FROM Account WHERE Submittable_Org_ID__c IN :orgIds]) existingOrgAccountsMap.put(acc.Submittable_Org_ID__c, acc);
        
        Map<String, Account> existingPersonAccountsMap = new Map<String, Account>();
        Map<String, Contact> existingContactsMap = new Map<String, Contact>();
        if (!allSubmitterIds.isEmpty()) {
            for(Account acc : [SELECT Id, Submittable_Submitter_ID__c FROM Account WHERE Submittable_Submitter_ID__c IN :allSubmitterIds AND IsPersonAccount = true]) existingPersonAccountsMap.put(acc.Submittable_Submitter_ID__c, acc);
            for (Contact c : [SELECT Id, Submittable_Submitter_ID__c FROM Contact WHERE Submittable_Submitter_ID__c IN :allSubmitterIds]) existingContactsMap.put(c.Submittable_Submitter_ID__c, c);
        }
        
        // --- First Pass: Process wrappers and prepare DML lists ---
        List<Account> personAccountsToInsert = new List<Account>();
        List<Contact> contactsToInsert = new List<Contact>();
        List<IndividualApplication> appsToInsert = new List<IndividualApplication>();
        List<IndividualApplication> appsToUpdate = new List<IndividualApplication>();
        
        // ** NEW: Sets to track in-flight records we've decided to create in this job **
        Set<String> newPersonAccountSubmitterIds = new Set<String>();
        Set<String> newContactSubmitterIds = new Set<String>();
        
        for (SubmissionWrapper wrap : submissionWrappers) {
            Id relatedAccountId = null;
            
            if (String.isNotBlank(wrap.publicOrgId)) {
                Account orgAccount = existingOrgAccountsMap.get(wrap.publicOrgId);
                if (orgAccount != null) relatedAccountId = orgAccount.Id;
            } else {
                Account personAccount = existingPersonAccountsMap.get(wrap.submitterId);
                if (personAccount != null) relatedAccountId = personAccount.Id;
            }
            
            if (String.isNotBlank(wrap.publicOrgId)) {
                Account orgAccount = existingOrgAccountsMap.get(wrap.publicOrgId);
                // ** MODIFIED: Check if contact exists in DB AND that we haven't already decided to create it **
                if (orgAccount != null && !existingContactsMap.containsKey(wrap.submitterId) && !newContactSubmitterIds.contains(wrap.submitterId) && String.isNotBlank(wrap.submitterId)) {
                    Contact newContact = new Contact(FirstName = wrap.firstName, LastName = String.isBlank(wrap.lastName) ? wrap.firstName : wrap.lastName, Email = wrap.email, AccountId = orgAccount.Id, Submittable_Submitter_ID__c = wrap.submitterId);
                    contactsToInsert.add(newContact);
                    newContactSubmitterIds.add(wrap.submitterId); // Track it
                }
            } else if (!existingPersonAccountsMap.containsKey(wrap.submitterId) && !newPersonAccountSubmitterIds.contains(wrap.submitterId) && String.isNotBlank(wrap.submitterId)) {
                // ** MODIFIED: Check if account exists in DB AND that we haven't already decided to create it **
                Account newPersonAccount = new Account(RecordTypeId = personAccountRecordTypeId, FirstName = wrap.firstName, LastName = String.isBlank(wrap.lastName) ? wrap.firstName : wrap.lastName, PersonEmail = wrap.email, Submittable_Submitter_ID__c = wrap.submitterId);
                personAccountsToInsert.add(newPersonAccount);
                newPersonAccountSubmitterIds.add(wrap.submitterId); // Track it
            }
            
            IndividualApplication app = existingAppsMap.get(wrap.submissionId);
            if (app == null) {
                app = new IndividualApplication(Submittable_Submission_ID__c = wrap.submissionId);
                appsToInsert.add(app);
            } else { appsToUpdate.add(app); }
            
            app.ApplicationName = wrap.title;
            app.FundingOpportunityId = fundingOppId;
            app.Submittable_Submission_Id__c = wrap.submissionId;
            app.Submittable_Public_Org_Id__c = wrap.publicOrgId;
            app.Submittable_Submitter_Id__c =  wrap.submitterId;
            app.Submittable_Project_Id__c =  wrap.projectId;
            app.Status = wrap.submissionStatus;
            app.AppliedDate = wrap.submissionDate;
            app.Category = 'Grant Application';
            
            if (relatedAccountId != null) app.AccountId = relatedAccountId;
        }
        
        // --- Perform DML and Second Pass to Link New Records ---
        try {
            if (!personAccountsToInsert.isEmpty()) insert personAccountsToInsert;
            if (!contactsToInsert.isEmpty()) insert contactsToInsert;
            
            Map<String, Id> newPersonAccountIdsMap = new Map<String, Id>();
            for(Account acc : personAccountsToInsert) {
                newPersonAccountIdsMap.put(acc.Submittable_Submitter_ID__c, acc.Id);
            }
            
            for(IndividualApplication app : appsToInsert) {
                if(app.AccountId == null && app.Submittable_Submitter_Id__c != null) {
                    app.AccountId = newPersonAccountIdsMap.get(app.Submittable_Submitter_Id__c);
                }
            }
            for(IndividualApplication app : appsToUpdate) {
                if(app.AccountId == null && app.Submittable_Submitter_Id__c != null) {
                    app.AccountId = newPersonAccountIdsMap.get(app.Submittable_Submitter_Id__c);
                }
            }
            
            if (!appsToInsert.isEmpty()) insert appsToInsert;
            if (!appsToUpdate.isEmpty()) update appsToUpdate;
            
        } catch (Exception ex) {
            Error__c errorLog = new Error__c();
            errorLog.Name = ex.getTypeName();
            errorLog.Error_Message__c = ex.getMessage();
            errorLog.Error_Trace__c = ex.getStackTraceString();
            insert errorLog;
            System.debug('DML Exception during submission processing: ' + ex.getMessage());
        }
    }
    
    // --- HELPER FUNCTION and INNER CLASS ---
    private static String formatSubmissionStatus(String rawStatus) {
        if (String.isBlank(rawStatus)) { return null; }
        switch on rawStatus.toLowerCase() {
            when 'new' { return 'New'; }
            when 'in_progress' { return 'In-Progress'; }
            when 'accepted' { return 'Accepted'; }
            when 'declined' { return 'Declined'; }
            when 'withdrawn' { return 'Withdrawn'; }
            when else { return rawStatus; }
        }
    }
    
    private class SubmissionWrapper {
        String submissionId;
        String projectId;
        String submitterId;
        String firstName;
        String lastName;
        String email;
        String title;
        String publicOrgId;
        String submissionStatus;
        DateTime submissionDate;
    }
}