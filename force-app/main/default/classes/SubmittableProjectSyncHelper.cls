public class SubmittableProjectSyncHelper {

    // Wrapper class (no changes)
    public class ProjectWrapper {
        public String projectId;
        public String name;
        public String initialFormId;
        public DateTime startDate;
        public DateTime endDate;
        public Boolean isHidden;
        public String guidelinesHtml;
        public Boolean isLive;
    }

    @future(callout=true)
    public static void syncProjects() {
        List<Error__c> errorsToInsert = new List<Error__c>();
        Map<String, ProjectWrapper> submittableProjects = new Map<String, ProjectWrapper>();
        String continuationToken = '';

        // Step 1: Retrieve all projects from Submittable (no changes here)
        do {
            HttpRequest req = new HttpRequest();
            String endpoint = 'callout:Submittable_API/v4/projects' + (String.isBlank(continuationToken) ? '' : '?continuationToken=' + EncodingUtil.urlEncode(continuationToken, 'UTF-8'));
            req.setEndpoint(endpoint);
            req.setMethod('GET');

            try {
                Http http = new Http();
                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200) {
                    Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    List<Object> items = (List<Object>) results.get('items');
                    if (items != null) {
                        for (Object item : items) {
                            Map<String, Object> projectData = (Map<String, Object>) item;
                            ProjectWrapper pw = new ProjectWrapper();
                            pw.projectId = (String) projectData.get('projectId');
                            pw.name = (String) projectData.get('name');
                            pw.guidelinesHtml = (String) projectData.get('guidelinesHtml');
                            pw.isHidden = (Boolean)projectData.get('isHidden') == true;
                            pw.isLive = (Boolean)projectData.get('isLive') == true;
                            pw.startDate = parseIsoDatetime((String) projectData.get('startsAt'));
                            pw.endDate = parseIsoDatetime((String) projectData.get('endsAt'));
                            pw.initialFormId = (String) projectData.get('initialFormId');
                            submittableProjects.put(pw.projectId, pw);
                        }
                    }
                    continuationToken = (String) results.get('continuationToken');
                } else {
                    system.debug('getStatusCode-------------36'+res.getStatusCode());
                    system.debug('getbody-------------37'+res.getStatusCode());
                    errorsToInsert.add(ErrorLoggingApex.createErrorLog(
                        'Endpoint Error',
                        'External Reviewer Sync Job Failed',
                        req.getBody(),
                        res.getBody(),
                        String.valueOf(res.getStatusCode()),
                        null // No Apex exception object in this case
                    ));
                    System.debug('Submittable API Error: ' + res.getStatusCode() + ' | ' + res.getBody());
                    continuationToken = null;
                }
            } catch (Exception ex) {
                Error__c errorLog = new Error__c();
                errorLog.Name = ex.getTypeName();
                errorLog.Error_Message__c = ex.getMessage();
                errorLog.Error_Trace__c = ex.getStackTraceString();
                insert errorLog;
                //System.debug('DML Exception during submission sync: ' + ex.getMessage());
                System.debug('An exception occurred during project sync: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
                continuationToken = null;
            }
        } while (!String.isBlank(continuationToken));

        if (submittableProjects.isEmpty()) {
            return;
        }

        // Step 2: Query for existing records and put them in a map
        Map<String, FundingOpportunity> existingOpportunitiesMap = new Map<String, FundingOpportunity>();
        for (FundingOpportunity fo : [
            SELECT Id, Submittable_Project_ID__c, Name, ApplicationInstructions, Is_Hidden__c, Is_Live__c, StartDate, EndDate, Initial_Form_Id__c
            FROM FundingOpportunity
            WHERE Submittable_Project_ID__c IN :submittableProjects.keySet()
        ]) {
            existingOpportunitiesMap.put(fo.Submittable_Project_ID__c, fo);
        }

        // Step 3: Create two lists: one for inserts, one for updates
        List<FundingOpportunity> opportunitiesToInsert = new List<FundingOpportunity>();
        List<FundingOpportunity> opportunitiesToUpdate = new List<FundingOpportunity>();

        for (ProjectWrapper pw : submittableProjects.values()) {
            // Check if the project already exists in our map
            if (existingOpportunitiesMap.containsKey(pw.projectId)) {
                // It exists, so we update it
                FundingOpportunity foToUpdate = existingOpportunitiesMap.get(pw.projectId);
                
                // Map fields
                foToUpdate.Name = pw.name;
                foToUpdate.ApplicationInstructions = pw.guidelinesHtml;
                foToUpdate.Is_Hidden__c = pw.isHidden;
                foToUpdate.Is_Live__c = pw.isLive;
                foToUpdate.StartDate = pw.startDate;
                foToUpdate.EndDate = pw.endDate;
                foToUpdate.Initial_Form_Id__c = pw.initialFormId;
                
                opportunitiesToUpdate.add(foToUpdate);
            } else {
                // It does not exist, so we create a new one
                FundingOpportunity foToInsert = new FundingOpportunity();
                
                // Map fields
                foToInsert.Submittable_Project_ID__c = pw.projectId; // Set the ID for new records
                foToInsert.Name = pw.name;
                foToInsert.ApplicationInstructions = pw.guidelinesHtml;
                foToInsert.Is_Hidden__c = pw.isHidden;
                foToInsert.Is_Live__c = pw.isLive;
                foToInsert.StartDate = pw.startDate;
                foToInsert.EndDate = pw.endDate;
                foToInsert.Initial_Form_Id__c = pw.initialFormId;
                
                opportunitiesToInsert.add(foToInsert);
            }
        }

        // Step 4: Perform the DML operations
        try {
            if (!opportunitiesToInsert.isEmpty()) {
                insert opportunitiesToInsert;
            }
            if (!opportunitiesToUpdate.isEmpty()) {
                update opportunitiesToUpdate;
            }
        } catch (Exception e) {
            System.debug('DML Exception on Funding Opportunity sync: ' + e.getMessage());
        }
    }

    // Helper method to parse datetime (no changes)
    public static DateTime parseIsoDatetime(String isoString) {
        if (String.isBlank(isoString)) {
            return null;
        }
        try {
            return (DateTime)JSON.deserialize('"' + isoString + '"', DateTime.class);
        } catch (Exception e) {
            System.debug('Could not parse ISO datetime string: ' + isoString);
            return null;
        }
    }
}