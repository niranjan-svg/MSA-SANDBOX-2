/**
 * Batch class to send membership renewal reminder emails.
 * Processes memberships in two states:
 * 1. Pre-expiration (30, 60, 90 days before expiry) - Renewal Reminders
 * 2. Grace Period (30, 60, 90 days after expiry) - Grace Period Reminders
 * 
 * Scheduled to run daily via SendMembershipRenewalReminderSchedule
 */
global class SendMembershipRenewalReminderBatch_New implements Database.Batchable<sObject>, Schedulable {

    private static final String RENEWAL_REMINDER_TEMPLATE = 'Renewal_Reminder_Notification_1745315275773';
    private static final String GRACE_PERIOD_30_TEMPLATE = 'X30_Days_Membership_Post_Expiration_Notice_1755182552925';
    private static final String GRACE_PERIOD_60_TEMPLATE = 'X60_Days_Membership_Post_Expiration_Notice_1755011573819';
    private static final String GRACE_PERIOD_90_TEMPLATE = 'X90_Days_Membership_Post_Expiration_Notice_1755011610827';
    private static final String SENDER_EMAIL = 'membership@mainstreet.org';
    
    Map<String, Id> templateMap = new Map<String, Id>();
    
    global SendMembershipRenewalReminderBatch_New() {
        List<EmailTemplate> templates = [SELECT Id, DeveloperName FROM EmailTemplate WHERE DeveloperName IN :new Set<String>{RENEWAL_REMINDER_TEMPLATE,
        								GRACE_PERIOD_30_TEMPLATE, GRACE_PERIOD_60_TEMPLATE, GRACE_PERIOD_90_TEMPLATE}];

		for (EmailTemplate t : templates) {
    		templateMap.put(t.DeveloperName, t.Id);
		}
        System.debug('templateMap..>'+templateMap.size());
    }

    
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new SendMembershipRenewalReminderBatch_New(), 200);
    }

    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('Start Method started..>');
        return Database.getQueryLocator(
            'SELECT Id,Membership__c, PersonContactId, IsPersonAccount, Primary_Contact__c, ' +
            'Primary_Contact__r.IsEmailBounced, PersonContact.IsEmailBounced, ' +
            'Term_End_Date__c, Membership__r.Membership_Status__c ' +
            'FROM Account ' +
            'WHERE Membership__c <> null AND Term_End_Date__c <> null ' +
            'AND Membership__r.Renewal_Reminder__c = true AND Membership__r.Is_Active__c = true ' +
            'AND Membership__r.Membership_Status__c IN (\'Membership Activated\', \'In Grace Period\')' 
        );
    }

    
    global void execute(Database.BatchableContext bc, List<Account> scope) {
        System.debug('Executed method started..>');
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

        // Collect Account Ids from scope
    	Set<Id> accountIds = new Set<Id>();
    	for (Account acc : scope) {
        	accountIds.add(acc.Id);
    	}

    	// Find accounts which already have Queued Membership
    	Set<Id> accountsWithQueuedMembership = new Set<Id>();

    	for (Memberships__c mem : [SELECT Id, Account__c FROM Memberships__c 
                                   WHERE Account__c IN :accountIds AND Membership_Status__c = 'Queued' AND TermEndDate__c != null]) 
        {
        	accountsWithQueuedMembership.add(mem.Account__c);
    	}
    	System.debug('accountsWithQueuedMembership size => ' + accountsWithQueuedMembership.size());
        
        // Get the org-wide email address ID once for all emails
        String orgWideEmailId = getOrgWideEmailAddress(SENDER_EMAIL);

        for (Account memberAccount : scope) {
            try {
                
            	if (accountsWithQueuedMembership.contains(memberAccount.Id)) {
                	System.debug('Skipping email because Queued membership exists for Account => ' + memberAccount.Id);
                	continue;
            	}
                
                Id membershipId = memberAccount.Membership__c;

                Integer daysDifference = calculateDaysDifference(memberAccount.Term_End_Date__c);
				System.debug('daysDifference..>'+daysDifference);
                
                if (!isReminderDay(daysDifference)) {
                    continue;
                }

                // Determine recipient contact ID based on account type
                String recipientContactId = getRecipientContactId(memberAccount);
                if (String.isBlank(recipientContactId)) {
                    continue;
                }

                if (isEmailBounced(memberAccount)) {
                    continue;
                }

                // Determine email template based on status and days
                String emailTemplateId = getEmailTemplate(memberAccount.Membership__r.Membership_Status__c , daysDifference);

                if (emailTemplateId == null) continue;
                
                // Create email message
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setTemplateId(emailTemplateId);
                email.setTargetObjectId(recipientContactId);
                email.setWhatId(membershipId);
                if (orgWideEmailId != null) {
                    email.setOrgWideEmailAddressId(orgWideEmailId);
                }
                //email.setTreatMissingEmailAsError(false);

                emailsToSend.add(email);
				System.debug('emailsToSend..>'+emailsToSend);
            } catch (Exception e) {
                System.debug('Error processing account ' + memberAccount.Id + ': ' + e.getMessage());
            }
        }

        // Send all emails in batch
        if (!emailsToSend.isEmpty()) {
            try {
                System.debug('emailsToSend.size...>'+emailsToSend.size());
                List<Messaging.SendEmailResult> results = Messaging.sendEmail(emailsToSend); // commented for testing
                logEmailResults(results);
            } catch (Exception e) {
                System.debug('Error sending emails: ' + e.getMessage());
            }
        }
    }

    
    global void finish(Database.BatchableContext bc) {
        System.debug('SendMembershipRenewalReminderBatch_New completed');
    }

    
    private Boolean isReminderDay(Integer daysDifference) {
        Integer absDays = Math.abs(daysDifference);
        return absDays == 30 || absDays == 60 || absDays == 90;
    }

    
    private Integer calculateDaysDifference(Date termEndDate) {
        if (termEndDate == null) {
            return 0;
        }
        return termEndDate.daysBetween(System.today());
    }

    // Determine the appropriate email template based on membership status and days
    private String getEmailTemplate(String membershipStatus, Integer daysDifference) {
        Integer absDays = Math.abs(daysDifference);
        
        System.debug('membershipStatus-176..>'+membershipStatus);
        System.debug('daysDifference-177..>'+daysDifference);
        
        if (membershipStatus == 'Membership Activated') {
            return templateMap.get(RENEWAL_REMINDER_TEMPLATE);
        }
        
        if (membershipStatus == 'In Grace Period') {
            if (absDays == 30) {
                return templateMap.get(GRACE_PERIOD_30_TEMPLATE);
            } else if (absDays == 60) {
                return templateMap.get(GRACE_PERIOD_60_TEMPLATE);
            } else if (absDays == 90) {
                return templateMap.get(GRACE_PERIOD_90_TEMPLATE);
            }
        }
    	return null;
    }

    // Determine the appropriate recipient contact ID
    private String getRecipientContactId(Account memberAccount) {
        if (memberAccount.IsPersonAccount) {
            return memberAccount.PersonContactId;
        }
        return memberAccount.Primary_Contact__c;
    }

    // Check if contact email is bounced
    private Boolean isEmailBounced(Account memberAccount) {
        if (memberAccount.IsPersonAccount && memberAccount.PersonContact != null) {
            return memberAccount.PersonContact.IsEmailBounced;
        }
        if (!memberAccount.IsPersonAccount && memberAccount.Primary_Contact__r != null) {
            return memberAccount.Primary_Contact__r.IsEmailBounced;
        }
        return false;
    }

    // Get the Org-wide email address ID for the sender email
    private String getOrgWideEmailAddress(String senderEmail) {
        try {
            List<OrgWideEmailAddress> owea = [SELECT Id FROM OrgWideEmailAddress WHERE Address = :senderEmail LIMIT 1];
            return !owea.isEmpty() ? owea[0].Id : null;
        } catch (Exception e) {
            System.debug('Could not find org wide email address: ' + e.getMessage());
            return null;
        }
    }

    // Log email send results for debugging
    private void logEmailResults(List<Messaging.SendEmailResult> results) {
        Integer successCount = 0;
        Integer failureCount = 0;

        for (Messaging.SendEmailResult result : results) {
            if (result.isSuccess()) {
                successCount++;
            } else {
                failureCount++;
                for (Messaging.SendEmailError error : result.getErrors()) {
                    System.debug('Email error: ' + error.getMessage());
                }
            }
        }
        System.debug('Emails sent: ' + successCount + ', Failed: ' + failureCount);
    }
}