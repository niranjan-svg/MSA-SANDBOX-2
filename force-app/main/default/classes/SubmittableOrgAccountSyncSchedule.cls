public class SubmittableOrgAccountSyncSchedule implements Schedulable {
    /*To run once a week*/
    public void execute(SchedulableContext sc) {
        SubmittableOrgAccountSyncHelper.syncOrganizations();
    }
}