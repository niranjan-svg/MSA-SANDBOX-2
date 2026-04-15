public with sharing class MembershipInvoiceProcess_1 {

    // =============================
    // ENTRY POINT (QUEUEABLE)
    // =============================
    public static void processInvoicesAsync(Set<Id> invoiceIds) {
        if (invoiceIds == null || invoiceIds.isEmpty()) return;
        System.enqueueJob(new InvoiceQueueable(invoiceIds));
    }

    public class InvoiceQueueable implements Queueable, Database.AllowsCallouts {
        private Set<Id> invoiceIds;

        public InvoiceQueueable(Set<Id> invoiceIds) {
            this.invoiceIds = invoiceIds;
        }

        public void execute(QueueableContext context) {
            processInvoices(invoiceIds);
        }
    }

    // =============================
    // CORE METHOD
    // =============================
    private static void processInvoices(Set<Id> invoiceIds) {

        List<Invoice__c> invoices = fetchInvoices(invoiceIds);
        Map<Id, Membership_Transaction__c> txnMap = fetchTransactions(invoiceIds);

        EmailTemplate template = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Membership_Invoice_Generation_1761677737258' LIMIT 1];
        OrgWideEmailAddress owa = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'membership@mainstreet.org' LIMIT 1];

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<ContentVersion> files = new List<ContentVersion>();

        // Pre-fetch CP relationships (bulkified)
        Map<Id, Program_Relationship__c> cpMap = fetchCPRelationships(invoices);

        for (Invoice__c inv : invoices) {
            try {
                Membership_Transaction__c txn = txnMap.get(inv.Id);

                RecipientWrapper recipient = resolveRecipient(inv, cpMap);

                if (!recipient.isValid() || txn == null) continue;

                Blob pdf = generatePDF(inv.Id);

                files.add(buildFile(inv, pdf));
                emails.add(buildEmail(inv, txn, recipient, pdf, template, owa));

            } catch (Exception e) {
                logError('Invoice Processing Failed', inv.Id, e);
            }
        }

        if (!files.isEmpty()) insert files;
        if (!emails.isEmpty()) Messaging.sendEmail(emails);
    }

    // =============================
    // DATA FETCH METHODS
    // =============================

    private static List<Invoice__c> fetchInvoices(Set<Id> ids) {
        return [SELECT Id, Name, Bill_To_Account__c, Bill_To_Account__r.PersonEmail, Bill_To_Account__r.IsPersonAccount,Bill_To_Account__r.PersonContactId, 
            		Bill_To_Contact__c, Bill_To_Contact__r.Email, Related_Order__r.Billing_Type__c, Related_Order__r.EndDate
            		FROM Invoice__c WHERE Id IN :ids];
    }

    private static Map<Id, Membership_Transaction__c> fetchTransactions(Set<Id> invoiceIds) {
        Map<Id, Membership_Transaction__c> mapData = new Map<Id, Membership_Transaction__c>();

        for (Membership_Transaction__c txn : [SELECT Id, Invoice__c FROM Membership_Transaction__c WHERE Invoice__c IN :invoiceIds]) {
            mapData.put(txn.Invoice__c, txn);
        }
        return mapData;
    }

    // BULK CP PR FETCH
    private static Map<Id, Program_Relationship__c> fetchCPRelationships(List<Invoice__c> invoices) {

        Set<Id> accountIds = new Set<Id>();

        for (Invoice__c inv : invoices) {
            if (inv.Related_Order__r.Billing_Type__c == 'Paid by Coordinating Program') {
                accountIds.add(inv.Bill_To_Account__c);
            }
        }

        Map<Id, Program_Relationship__c> result = new Map<Id, Program_Relationship__c>();

        if (accountIds.isEmpty()) return result;

        for (Program_Relationship__c pr : [SELECT Local_Program__c, Coordinating_Program__r.Primary_Contact__c, 
                                           Coordinating_Program__r.Primary_Contact__r.Email
            								FROM Program_Relationship__c
            								WHERE Local_Program__c IN :accountIds AND Status__c = 'Active']) {
            result.put(pr.Local_Program__c, pr);
        }
        return result;
    }

    // =============================
    // RECIPIENT RESOLUTION
    // =============================

    private static RecipientWrapper resolveRecipient(Invoice__c inv, Map<Id, Program_Relationship__c> cpMap) {

        RecipientWrapper wrapper = new RecipientWrapper();

        if (inv.Related_Order__r.Billing_Type__c == 'Self-Pay') {

            if (!inv.Bill_To_Account__r.IsPersonAccount) {
                wrapper.email = inv.Bill_To_Contact__r.Email;
                wrapper.contactId = inv.Bill_To_Contact__c;
            } else {
                wrapper.email = inv.Bill_To_Account__r.PersonEmail;
                wrapper.contactId = inv.Bill_To_Account__r.PersonContactId;
            }

        } else if (inv.Related_Order__r.Billing_Type__c == 'Paid by Coordinating Program') {

            Program_Relationship__c pr = cpMap.get(inv.Bill_To_Account__c);

            if (pr != null) {
                wrapper.email = pr.Coordinating_Program__r.Primary_Contact__r.Email;
                wrapper.contactId = pr.Coordinating_Program__r.Primary_Contact__c;
            }
        }
        return wrapper;
    }

    // =============================
    // PDF + FILE
    // =============================

    private static Blob generatePDF(Id invoiceId) {
        if (Test.isRunningTest()) {
            return Blob.valueOf('TEST PDF');
        }

        PageReference ref = Page.MembershipInvoicePDF;
        ref.getParameters().put('id', invoiceId);

        return ref.getContentAsPDF();
    }

    private static ContentVersion buildFile(Invoice__c inv, Blob pdf) {
        ContentVersion cv = new ContentVersion();
        cv.Title = 'Receipt-' + inv.Name + '.pdf';
        cv.PathOnClient = 'Receipt-' + inv.Name + '.pdf';
        cv.VersionData = pdf;
        cv.FirstPublishLocationId = inv.Id;
        return cv;
    }

    // =============================
    // EMAIL
    // =============================

    private static Messaging.SingleEmailMessage buildEmail(Invoice__c inv, Membership_Transaction__c txn,
        													RecipientWrapper recipient, Blob pdf, EmailTemplate template, 
                                                           	OrgWideEmailAddress owa) {

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();

        email.setToAddresses(new List<String>{ recipient.email });
        email.setTemplateId(template.Id);
        email.setTargetObjectId(recipient.contactId);
        email.setWhatId(txn.Id);
        email.setOrgWideEmailAddressId(owa.Id);

        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setBody(pdf);
        attachment.setFileName('Receipt-' + inv.Name + '.pdf');

        email.setFileAttachments(new Messaging.EmailFileAttachment[]{ attachment });

        return email;
    }

    // =============================
    // WRAPPER
    // =============================

    public class RecipientWrapper {
        public String email;
        public Id contactId;

        public Boolean isValid() {
            return !String.isBlank(email) && contactId != null;
        }
    }

    // =============================
    // ERROR LOGGING
    // =============================

    private static void logError(String context, Id recordId, Exception e) {
        System.debug('ERROR: ' + context + ' | Record: ' + recordId + ' | ' + e.getMessage());
        // Future: Custom Object / Platform Event
    }
}