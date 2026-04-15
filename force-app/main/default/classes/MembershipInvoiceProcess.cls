public class MembershipInvoiceProcess {
    
    @future(callout=true)
    public static void generateAndSendInvoice(List<Id> paidInvoiceIds) {
        if (paidInvoiceIds == null || paidInvoiceIds.isEmpty()) return;
        
        // --- 1. GATHER DATA ---
        // <-- FIXED: Added Bill_To_Contact__c and PersonContactId to get the ID for the template.
        List<Invoice__c> invoicesToProcess = [
            SELECT Id, Name, Bill_To_Account__c, Bill_To_Account__r.Name, Bill_To_Account__r.PersonEmail,
                   Bill_To_Account__r.IsPersonAccount, Bill_To_Account__r.PersonContactId, // <-- ADDED
                   Bill_To_Account__r.BillingCity,Bill_To_Account__r.BillingStreet,Bill_To_Account__r.BillingState,
                   Bill_To_Account__r.BillingCountry, Bill_To_Account__r.BillingPostalCode, Related_Order__r.EndDate,
                   Bill_To_Contact__c, Bill_To_Contact__r.Email, // <-- ADDED Bill_To_Contact__c
                   Related_Order__r.Billing_Type__c
            FROM Invoice__c
            WHERE Id IN :paidInvoiceIds
        ];
        System.debug('invoicesToProcess..>'+invoicesToProcess);
        Map<Id, Membership_Transaction__c> invoiceIdToTransactionMap = new Map<Id, Membership_Transaction__c>();

        // 2. Run ONE query to get all related transactions for the invoices we are processing.
        //    (You MUST replace 'Invoice__c' with the actual API name of the lookup field on Membership Transaction)
        List<Membership_Transaction__c> relatedTransactions = [
            SELECT Id, Invoice__c // <-- **** VERIFY THIS API NAME IS CORRECT ****
            FROM Membership_Transaction__c 
            WHERE Invoice__c IN :paidInvoiceIds
        ];
		System.debug('relatedTransactions..>'+relatedTransactions);
        // 3. Loop through the results and populate the map for easy access later.
        for(Membership_Transaction__c trans : relatedTransactions) {
            invoiceIdToTransactionMap.put(trans.Invoice__c, trans);
        }
        
        OrgWideEmailAddress owa = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'membership@mainstreet.org' LIMIT 1];
        // Make sure your template's API Name is correct here
        EmailTemplate template = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Membership_Invoice_Generation_1761677737258' LIMIT 1];
        
        // --- 2. PREPARE EMAILS BASED ON LOGIC ---
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        List<ContentVersion> filesToInsert = new List<ContentVersion>();
        
        for (Invoice__c currentInvoice : invoicesToProcess) {
            
            Membership_Transaction__c relatedTransaction = invoiceIdToTransactionMap.get(currentInvoice.Id);
            
            String recipientEmail = '';
            Id targetContactId = null; // <-- FIXED: Declared the variable to hold the Contact ID.
            
            // --- Determine the Recipient Email AND Contact ID ---
            
            // **Scenario 1: Self-Paying Member**
            if (currentInvoice.Related_Order__r.Billing_Type__c == 'Self-Pay') {
                if(currentInvoice.Bill_To_Account__r.IsPersonAccount == false){
                    recipientEmail = currentInvoice.Bill_To_Contact__r.Email;
                    targetContactId = currentInvoice.Bill_To_Contact__c; // <-- FIXED: Populate the ID
                } else { // It is a Person Account
                    recipientEmail = currentInvoice.Bill_To_Account__r.PersonEmail;
                    targetContactId = currentInvoice.Bill_To_Account__r.PersonContactId; // <-- FIXED: Populate the ID
                }
                
            // **Scenario 2: LP Paid by a CP**
            } else if (currentInvoice.Related_Order__r.Billing_Type__c == 'Paid by Coordinating Program') {
                Date termYear = currentInvoice.Related_Order__r.EndDate;
                // <-- FIXED: Query for the Contact ID
                List<Program_Relationship__c> relationships = [
                    SELECT Coordinating_Program__r.Primary_Contact__c, // <-- ADDED
                           Coordinating_Program__r.Primary_Contact__r.Email
                    FROM Program_Relationship__c 
                    WHERE Local_Program__c = :currentInvoice.Bill_To_Account__c AND Status__c = 'Active'
                    AND TermYear__c = :Decimal.valueOf(termYear.year()) AND Relationship_Type__c = 'Pays LP Membership'
                    LIMIT 1
                ];
                
                if (!relationships.isEmpty()) {
                    recipientEmail = relationships[0].Coordinating_Program__r.Primary_Contact__r.Email;
                    targetContactId = relationships[0].Coordinating_Program__r.Primary_Contact__c; // <-- FIXED: Populate the ID
                }
            }
            
            // <-- FIXED: Updated the check to also look for the ID
            if (String.isBlank(recipientEmail) || targetContactId == null || relatedTransaction == null) {
                continue;
            }
            
            // --- A. GENERATE PDF --- (No changes needed here)
            PageReference pdfPage = Page.MembershipInvoicePDF;
            pdfPage.getParameters().put('id', currentInvoice.Id);
            Blob pdfBlob = Test.isRunningTest() ? Blob.valueOf('Test PDF Body') : pdfPage.getContentAsPDF();
            
            // --- B. PREPARE FILE FOR SALESFORCE --- (No changes needed here)
            ContentVersion cv = new ContentVersion();
            cv.Title = 'Receipt-' + currentInvoice.Name + '.pdf';
            cv.PathOnClient = 'Receipt-' + currentInvoice.Name + '.pdf';
            cv.VersionData = pdfBlob;
            cv.FirstPublishLocationId = currentInvoice.Id;
            filesToInsert.add(cv);
            
            // --- C. CONSTRUCT THE EMAIL MESSAGE ---
            // <-- FIXED: This section is now correct because the variables above are properly set.
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ recipientEmail });
            email.setOrgWideEmailAddressId(owa.Id);
            
            // Set template details
            email.setTemplateId(template.Id);
            email.setTargetObjectId(targetContactId); // This is the 'WhoId' (Contact)
            email.setWhatId(relatedTransaction.Id);       // This is the 'WhatId' (the Invoice record)
            
            // Attach the PDF
            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setBody(pdfBlob);
            attachment.setFileName('Receipt-' + currentInvoice.Name + '.pdf');
            email.setFileAttachments(new Messaging.EmailFileAttachment[]{ attachment });
            
            emailsToSend.add(email);
        }
        System.debug('filesToInsert..>'+filesToInsert);
        // --- 3. DML AND SEND OPERATIONS --- (No changes needed here)
        if (!filesToInsert.isEmpty()) {
            insert filesToInsert;
        }
        
        if (!emailsToSend.isEmpty()) {
            Messaging.sendEmail(emailsToSend);
            System.debug('Send Email');
        }
    }
}