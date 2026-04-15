/**
 * @description This is a public, top-level helper class for handling the asynchronous
 * metadata deployment callback in an Apex test. It must be a top-level class
 * to be correctly recognized by the Test.enqueueDeploy method.
 */
public class TestMetadataDeployCallback implements Metadata.DeployCallback {
    public void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context) {
        if (result.status != Metadata.DeployStatus.Succeeded) {
            // Fail the test if the metadata deployment has any issues.
            String errors = '';
            for (Metadata.DeployMessage msg : result.details.componentFailures) {
                errors += msg.problem + '; ';
            }
            System.assert(false, 'Metadata deployment failed: ' + errors);
        }
    }
}