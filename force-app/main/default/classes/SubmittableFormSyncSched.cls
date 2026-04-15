/**
 * @description This Schedulable class runs on a schedule to sync detailed form entry data
 * for ALL Individual Applications that have a Submittable Submission ID.
 * It is designed to be idempotent and will re-process records to check for updates.
 */
public class SubmittableFormSyncSched implements Schedulable {

    public void execute(SchedulableContext sc) {
        
        // This map will hold all the work for the Queueable chain.
        // Key: Salesforce ID of the IndividualApplication
        // Value: The corresponding Submittable Submission ID needed for the API call
        Map<Id, String> appsToSyncForms = new Map<Id, String>();

        // Query for ALL applications that have a submission ID.
        // A limit is a good practice to prevent timeouts if the org has a very large data volume.
        for (IndividualApplication app : [
            SELECT Id, Submittable_Submission_ID__c 
            FROM IndividualApplication 
            WHERE Submittable_Submission_ID__c != null
            LIMIT 5000 
        ]) {
            appsToSyncForms.put(app.Id, app.Submittable_Submission_ID__c);
        }

        // Only start the process if there are applications to process.
        if (!appsToSyncForms.isEmpty()) {
            // Enqueue the Form Sync job ONCE with the full list of applications.
            // The Queueable class will handle processing them one by one in a chain.
            System.enqueueJob(new SubmittableFormSyncQueueable(appsToSyncForms));
        }
    }
}