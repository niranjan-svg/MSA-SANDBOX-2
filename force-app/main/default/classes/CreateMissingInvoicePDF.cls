global class CreateMissingInvoicePDF implements Database.Batchable<SObject>, Database.AllowsCallouts {

    global Database.QueryLocator start(Database.BatchableContext bc) {

        return Database.getQueryLocator([
            SELECT Id, Name
            FROM Invoice__c
            WHERE Status__c IN ('Paid', 'Paid By CP')
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Invoice__c> scope) {

        List<ContentVersion> filesToInsert = new List<ContentVersion>();

        for (Invoice__c inv : scope) {

            try {
                // Skip if PDF already exists
                List<ContentVersion> existing = [
                    SELECT Id 
                    FROM ContentVersion
                    WHERE FirstPublishLocationId = :inv.Id
                    AND Title LIKE 'Receipt-%'
                    LIMIT 1
                ];

                if (!existing.isEmpty()) {
                    continue;
                }

                PageReference pdfPage = Page.MembershipInvoicePDF;
                pdfPage.getParameters().put('id', inv.Id);

                Blob pdfBlob = Test.isRunningTest()
                    ? Blob.valueOf('Test PDF')
                    : pdfPage.getContentAsPDF();

                // Unique file name to avoid duplicates
                String uniqueName = 'Receipt-' + inv.Name + '-' + System.currentTimeMillis() + '.pdf';

                ContentVersion cv = new ContentVersion();
                cv.Title = uniqueName;
                cv.PathOnClient = uniqueName;
                cv.VersionData = pdfBlob;
                cv.FirstPublishLocationId = inv.Id;

                filesToInsert.add(cv);

            } catch (Exception e) {
                System.debug('PDF Failed for Invoice: ' + inv.Id + 
                             ' | ' + e.getMessage());
            }
        }

        if (!filesToInsert.isEmpty()) {
            insert filesToInsert;
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('Old Invoice PDF Batch Completed Successfully');
    }
}