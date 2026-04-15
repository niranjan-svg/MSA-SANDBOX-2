global class OldInvoicePDFBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    global Database.QueryLocator start(Database.BatchableContext bc) {

        return Database.getQueryLocator([
            SELECT Id, Name
            FROM Invoice__c
            WHERE Status__c IN ('Paid', 'Paid By CP')
            AND Id NOT IN (
                SELECT FirstPublishLocationId 
                FROM ContentVersion 
                WHERE Title LIKE 'Receipt-%'
            )
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Invoice__c> scope) {

        List<ContentVersion> filesToInsert = new List<ContentVersion>();

        for (Invoice__c inv : scope) {

            try {
                PageReference pdfPage = Page.MembershipInvoicePDF;
                pdfPage.getParameters().put('id', inv.Id);

                Blob pdfBlob = Test.isRunningTest()
                    ? Blob.valueOf('Test PDF')
                    : pdfPage.getContentAsPDF();

                ContentVersion cv = new ContentVersion();
                cv.Title = 'Receipt-' + inv.Name + '.pdf';
                cv.PathOnClient = 'Receipt-' + inv.Name + '.pdf';
                cv.VersionData = pdfBlob;
                cv.FirstPublishLocationId = inv.Id;

                filesToInsert.add(cv);

            } catch (Exception e) {
                System.debug('PDF Failed for Invoice: ' + inv.Id + ' | ' + e.getMessage());
            }
        }

        if (!filesToInsert.isEmpty()) {
            insert filesToInsert;
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('Old Invoice PDF Batch Completed');
    }
}