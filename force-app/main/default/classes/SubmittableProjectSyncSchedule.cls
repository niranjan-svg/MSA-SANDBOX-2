public class SubmittableProjectSyncSchedule {
    public void execute(SchedulableContext sc) {
        SubmittableProjectSyncHelper.syncProjects();
    }
}