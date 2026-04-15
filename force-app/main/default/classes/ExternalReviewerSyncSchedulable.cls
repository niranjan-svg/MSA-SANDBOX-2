public class ExternalReviewerSyncSchedulable implements Schedulable, Database.AllowsCallouts {   
    public void execute(SchedulableContext sc) {
        ExternalReviewerSyncHandler.getReviewers();
    }  
}