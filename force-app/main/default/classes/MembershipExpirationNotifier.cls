global class MembershipExpirationNotifier implements Database.Batchable<SObject>, Database.Stateful {
    global Database.QueryLocator start(Database.BatchableContext BC) {
        // Query to get all active memberships
        return Database.getQueryLocator([
            SELECT Id, TermEndDate__c 
            FROM Memberships__c 
            WHERE TermEndDate__c != NULL 
            AND TermEndDate__c >= :Date.today() AND Is_Active__c =true
        ]);
    }

    global void execute(Database.BatchableContext BC, List<SObject> scope) {
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        
        for (SObject obj : scope) {
            Memberships__c membership = (Memberships__c)obj; // Cast to Membership__c
            Date expirationDate = membership.TermEndDate__c;
            Date todayDate = Date.today();
            Integer daysBeforeExpiry = getReminderSettings();
                if (expirationDate == todayDate.addDays(daysBeforeExpiry)) {
                    // Get the associated Account's Primary Contact email
                    system.debug('membership.Id---'+membership.Id);
                    Account constituent = [SELECT Primary_Contact__r.Email FROM Account WHERE Membership__c =: membership.Id LIMIT 1];
                    String emailAddress = constituent.Primary_Contact__r.Email;
                    system.debug('emailAddress----'+emailAddress);

                    if (emailAddress != null) {
                        system.debug('emailAddress----'+emailAddress);
                        // Create and send the email
                        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                        email.setToAddresses(new String[] { emailAddress });
                        email.setTemplateId('00Xdp00000087AnEAI'); // Replace with your Email Template ID
                        email.setTargetObjectId(constituent.Primary_Contact__c); // Set the target object for merge fields
                        email.setWhatId(membership.Id); // Set the membership record for merge fields
                        emailsToSend.add(email);
                    }
                }
            
        }

        // Send all emails at once
        if (!emailsToSend.isEmpty()) {
            Messaging.sendEmail(emailsToSend);
        }
    }

    global void finish(Database.BatchableContext BC) {
        // Optionally, you can implement any final logic here, such as logging or cleanup.
    }
    public static Integer getReminderSettings() {
        Integer days;
        // Query custom metadata records for reminder settings
        List<Membership_Reminder_Frequency__mdt> metadataRecords = [SELECT Frequency__c FROM Membership_Reminder_Frequency__mdt];
        for (Membership_Reminder_Frequency__mdt record : metadataRecords) {
            days = (Integer)record.Frequency__c;
        }
        return days;
    }
}