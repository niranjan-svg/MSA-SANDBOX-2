public class SubmittableSubmissionSyncSchedule {
    public void execute(SchedulableContext sc) {
        // Create a map of the Salesforce ID to the Submittable Project ID.
        // This is more efficient than passing whole SObjects.
        Map<Id, String> opportunityIdToProjectIdMap = new Map<Id, String>();
        
        for (FundingOpportunity fo : [
            SELECT Id, Submittable_Project_ID__c
            FROM FundingOpportunity
            WHERE Submittable_Project_ID__c != null
        ]) {
            opportunityIdToProjectIdMap.put(fo.Id, fo.Submittable_Project_ID__c);
        }
        
        // If there are opportunities to process, start the Queueable job chain.
        if (!opportunityIdToProjectIdMap.isEmpty()) {
            //System.enqueueJob(new SubmittableSubmissionQueueable(opportunityIdToProjectIdMap));
        }
    }
}