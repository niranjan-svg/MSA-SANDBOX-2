public class SubmittableFileSyncHelper {
    
    // NOTE: This future method now calls the main logic method.
    // This is a best practice allowing you to test the logic without a callout.
    @future(callout=true)
    public static void syncFiles(String filesJson) {
        processFiles(filesJson);
    }
    
    // Main logic is now in a public static method for testability.
    public static void processFiles(String filesJson) {
        List<FileToSync> filesToProcess = (List<FileToSync>) JSON.deserialize(filesJson, List<FileToSync>.class);
        if (filesToProcess == null || filesToProcess.isEmpty()) {
            return;
        }
        
        // --- Step 1: Parse all incoming file IDs from the URLs ---
        // This map links the unique file ID to the full data packet for that file.
        Map<String, FileToSync> fileIdToSyncDataMap = new Map<String, FileToSync>();
        for (FileToSync file : filesToProcess) {
            if (String.isNotBlank(file.downloadUrl)) {
                // Split the URL string to extract the ID
                List<String> urlParts = file.downloadUrl.split('/files/');
                if (urlParts.size() > 1) {
                    String fileId = urlParts[1];
                    fileIdToSyncDataMap.put(fileId, file);
                }
            }
        }
        
        if (fileIdToSyncDataMap.isEmpty()) {
            return; // No valid file IDs were parsed.
        }
        
        // --- Step 2: Query for any of these files that already exist in Salesforce ---
        Set<String> existingFileIds = new Set<String>();
        for (ContentVersion cv : [
            SELECT Submittable_File_ID__c FROM ContentVersion 
            WHERE Submittable_File_ID__c IN :fileIdToSyncDataMap.keySet()
        ]) {
            existingFileIds.add(cv.Submittable_File_ID__c);
        }
        
        // --- Step 3: Prepare lists for bulk DML operations ---
        List<ContentVersion> cvListToInsert = new List<ContentVersion>();
        
        // --- Step 4: Loop through files, perform callouts, and ADD TO LISTS (NO DML inside) ---
        for (String fileId : fileIdToSyncDataMap.keySet()) {
            // ** CRITICAL CHECK: If the file ID is already in Salesforce, skip it. **
            if (existingFileIds.contains(fileId)) {
                continue; 
            }
            
            FileToSync file = fileIdToSyncDataMap.get(fileId);
            
            try {
                List<Error__c> errorsToInsert = new List<Error__c>();
                HttpRequest req = new HttpRequest();
                req.setEndpoint(file.downloadUrl);
                
                // You can replace this with a Named Credential or a more secure method
                String username = 'de5102924c074124b2fc3463c2be7261'; 
                String password = '';
                String authString = username + ':' + password;
                String encodedAuthString = EncodingUtil.base64Encode(Blob.valueOf(authString));
                req.setHeader('Authorization', 'Basic ' + encodedAuthString);
                
                req.setMethod('GET');
                req.setTimeout(120000);
                
                HttpResponse res = new Http().send(req);
                
                if (res.getStatusCode() == 200) {
                    ContentVersion cv = new ContentVersion();
                    cv.Submittable_File_ID__c = fileId; // Store the parsed ID
                    cv.Title = file.fileName;
                    cv.PathOnClient = file.fileName;
                    cv.VersionData = res.getBodyAsBlob();
                    cv.Origin = 'H';
                    
                    // Add the new ContentVersion to the list instead of inserting it here.
                    cvListToInsert.add(cv);
                } else {
                    errorsToInsert.add(ErrorLoggingApex.createErrorLog(
                        'Endpoint Error',
                        'External Reviewer Sync Job Failed',
                        req.getBody(),
                        res.getBody(),
                        String.valueOf(res.getStatusCode()),
                        null // No Apex exception object in this case
                    ));
                }
                System.debug('Failed to download file: ' + file.fileName + '. Status: ' + res.getStatusCode());
            
        } catch (Exception ex) {
            Error__c errorLog = new Error__c();
            errorLog.Name = ex.getTypeName();
            errorLog.Error_Message__c = ex.getMessage();
            errorLog.Error_Trace__c = ex.getStackTraceString();
            insert errorLog;
            System.debug('Error during HTTP callout for file ' + file.fileName + ': ' + ex.getMessage());
        }
    }
    
    // --- Step 5: Perform all DML operations in BULK, outside the loop ---
    try {
        if (!cvListToInsert.isEmpty()) {
            // DML Operation #1: Insert all new ContentVersions at once.
            insert cvListToInsert;
            
            // Query for the ContentDocumentIds of ONLY the records we just inserted.
            Map<Id, Id> cvIdToContentDocIdMap = new Map<Id, Id>();
            for (ContentVersion cv : [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :cvListToInsert]) {
                cvIdToContentDocIdMap.put(cv.Id, cv.ContentDocumentId);
            }
            
            List<ContentDocumentLink> cdlListToInsert = new List<ContentDocumentLink>();
            
            // Create the links for the new files.
            for(ContentVersion newCv : cvListToInsert){
                Id contentDocId = cvIdToContentDocIdMap.get(newCv.Id);
                // We get the parentId from our original map using the Submittable File ID as the key
                Id parentId = fileIdToSyncDataMap.get(newCv.Submittable_File_ID__c).parentId;
                
                if(contentDocId != null && parentId != null){
                    ContentDocumentLink cdl = new ContentDocumentLink();
                    cdl.ContentDocumentId = contentDocId;
                    cdl.LinkedEntityId = parentId;
                    cdl.ShareType = 'V';
                    cdl.Visibility = 'AllUsers';
                    cdlListToInsert.add(cdl);
                }
            }
            
            // DML Operation #2: Insert all new ContentDocumentLinks at once.
            if(!cdlListToInsert.isEmpty()){
                insert cdlListToInsert;
            }
        }
    } catch (Exception e) {
        System.debug('Error during DML processing of files: ' + e.getMessage());
    }
}
}