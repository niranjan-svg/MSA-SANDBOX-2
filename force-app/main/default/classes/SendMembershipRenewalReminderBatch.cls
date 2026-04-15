/**
 * @description Batch class to send membership renewal reminder emails.
 * Processes memberships in two states:
 * 1. Pre-expiration (30, 60, 90 days before expiry) - Renewal Reminders
 * 2. Grace Period (30, 60, 90 days after expiry) - Grace Period Reminders
 * 
 * Scheduled to run daily via SendMembershipRenewalReminderSchedule
 * 
 * @author Niranjan
 * @since 2025-10-28
 */
global class SendMembershipRenewalReminderBatch implements Database.Batchable<sObject>, Schedulable {

    /**
     * Email template IDs for different reminder types
     */
    private static final String RENEWAL_REMINDER_TEMPLATE = '00XaJ000004W7aWUAS';
    private static final String GRACE_PERIOD_30_TEMPLATE = '00XaJ000004W7aaUAC';
    private static final String GRACE_PERIOD_60_TEMPLATE = '00XaJ000004W7abUAC';
    private static final String GRACE_PERIOD_90_TEMPLATE = '00XaJ000004W7acUAC';
    private static final String SENDER_EMAIL = 'membership@mainstreet.org';

    /**
     * @description Constructor
     */
    global SendMembershipRenewalReminderBatch() {
    }

    /**
     * @description Schedulable execute method - creates and enqueues batch job
     * @param sc SchedulableContext
     */
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new SendMembershipRenewalReminderBatch(), 200);
    }

    /**
     * @description Start method - queries all membership records that need renewal reminders
     * Includes both pre-expiration and grace period memberships
     * @param bc BatchableContext
     * @return Database.QueryLocator
     */
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT Id, AccountId__c, TermEndDate__c, Membership_Status__c, Account__r.PersonContactId, ' +
            'Account__r.IsPersonAccount, Account__r.Primary_Contact__c, ' +
            'Account__r.Primary_Contact__r.IsEmailBounced, Account__r.PersonContact.IsEmailBounced ' +
            'FROM Memberships__c ' +
            'WHERE Renewal_Reminder__c = true ' +
            'AND (Membership_Status__c = \'Membership Activated\' OR Membership_Status__c = \'In Grace Period\')'
        );
    }

    /**
     * @description Execute method - processes batch of records
     * @param bc BatchableContext
     * @param scope List of Memberships__c records
     */
    global void execute(Database.BatchableContext bc, List<Memberships__c> scope) {
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        Set<Id> membershipIds = new Set<Id>();
        
        // Collect all membership IDs for this batch
        for (Memberships__c membership : scope) {
            membershipIds.add(membership.Id);
        }

        // Query all related Account records in one query (no N+1)
        Map<Id, Account> accountMap = new Map<Id, Account>();
        if (!membershipIds.isEmpty()) {
            List<Account> accounts = [
                SELECT Id, PersonContactId, IsPersonAccount, Primary_Contact__c,
                       Primary_Contact__r.IsEmailBounced, PersonContact.IsEmailBounced
                FROM Account
                WHERE Membership__c IN :membershipIds
            ];
            for (Account acc : accounts) {
                accountMap.put(acc.Id, acc);
            }
        }

        // Get the org-wide email address ID
        String orgWideEmailId = getOrgWideEmailAddressId(SENDER_EMAIL);

        // Process each membership record
        for (Memberships__c membership : scope) {
            try {
                // Determine days until/since expiration
                Integer daysDifference = calculateDaysDifference(membership.TermEndDate__c);

                // Check if this membership qualifies for a reminder (30, 60, or 90 days)
                if (!isReminderDay(daysDifference)) {
                    continue;
                }

                Account memberAccount = accountMap.get(membership.Account__c);
                if (memberAccount == null) {
                    continue;
                }

                // Determine recipient contact ID based on account type
                String recipientContactId = getRecipientContactId(memberAccount);

                // Check if email is bounced
                if (isEmailBounced(memberAccount)) {
                    continue;
                }

                // Determine email template based on status and days
                String emailTemplateId = getEmailTemplate(membership.Membership_Status__c, daysDifference);

                // Create email message
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setTemplateId(emailTemplateId);
                email.setTargetObjectId(recipientContactId);
                email.setWhatId(membership.Id);
                if (orgWideEmailId != null) {
                    email.setOrgWideEmailAddressId(orgWideEmailId);
                }
                //email.setTreatMissingEmailAsError(false);

                emailsToSend.add(email);

            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error processing membership ' + membership.Id + ': ' + e.getMessage());
                // Continue processing other records
            }
        }

        // Send all emails in batch
        if (!emailsToSend.isEmpty()) {
            try {
                List<Messaging.SendEmailResult> results = Messaging.sendEmail(emailsToSend);
                logEmailResults(results);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error sending emails: ' + e.getMessage());
            }
        }
    }

    /**
     * @description Finish method - runs after batch completes
     * @param bc BatchableContext
     */
    global void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, 'SendMembershipRenewalReminderBatch completed');
        // Add any cleanup or notification logic here
    }

    /**
     * @description Helper method to determine if a date is a reminder day
     * @param daysDifference The difference in days (positive for future, negative for past)
     * @return Boolean True if it's a 30, 60, or 90 day reminder
     */
    private Boolean isReminderDay(Integer daysDifference) {
        Integer absDays = Math.abs(daysDifference);
        return absDays == 30 || absDays == 60 || absDays == 90;
    }

    /**
     * @description Calculate days between today and term end date
     * Positive value = future expiration (pre-expiration)
     * Negative value = past expiration (grace period)
     * @param termEndDate The membership term end date
     * @return Integer Number of days difference
     */
    private Integer calculateDaysDifference(Date termEndDate) {
        if (termEndDate == null) {
            return 0;
        }
        return termEndDate.daysBetween(System.today());
    }

    /**
     * @description Determine the appropriate email template based on membership status and days
     * @param membershipStatus The membership status
     * @param daysDifference The difference in days
     * @return String Template ID
     */
    private String getEmailTemplate(String membershipStatus, Integer daysDifference) {
        Integer absDays = Math.abs(daysDifference);
        
        // For active memberships (pre-expiration), use the standard renewal template
        if (membershipStatus == 'Membership Activated') {
            return RENEWAL_REMINDER_TEMPLATE;
        }
        
        // For grace period memberships, use different templates based on days elapsed
        if (membershipStatus == 'In Grace Period') {
            if (absDays == 30) {
                return GRACE_PERIOD_30_TEMPLATE;
            } else if (absDays == 60) {
                return GRACE_PERIOD_60_TEMPLATE;
            } else if (absDays == 90) {
                return GRACE_PERIOD_90_TEMPLATE;
            }
        }
        
        return RENEWAL_REMINDER_TEMPLATE;
    }

    /**
     * @description Determine the appropriate recipient contact ID
     * @param memberAccount The account record
     * @return String Contact ID or null
     */
    private String getRecipientContactId(Account memberAccount) {
        if (memberAccount.IsPersonAccount) {
            return memberAccount.PersonContactId;
        }
        return memberAccount.Primary_Contact__c;
    }

    /**
     * @description Check if contact email is bounced
     * @param memberAccount The account record
     * @return Boolean True if email is bounced
     */
    private Boolean isEmailBounced(Account memberAccount) {
        if (memberAccount.IsPersonAccount && memberAccount.PersonContact != null) {
            return memberAccount.PersonContact.IsEmailBounced;
        }
        if (!memberAccount.IsPersonAccount && memberAccount.Primary_Contact__r != null) {
            return memberAccount.Primary_Contact__r.IsEmailBounced;
        }
        return false;
    }

    /**
     * @description Get the Org-wide email address ID for the sender email
     * @param senderEmail The email address to match
     * @return String The Org-wide email address ID or null
     */
    private String getOrgWideEmailAddressId(String senderEmail) {
        try {
            List<OrgWideEmailAddress> owea = [
                SELECT Id
                FROM OrgWideEmailAddress
                WHERE Address = :senderEmail
                LIMIT 1
            ];
            return !owea.isEmpty() ? owea[0].Id : null;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Could not find org wide email address: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Log email send results for debugging
     * @param results List of SendEmailResult objects
     */
    private void logEmailResults(List<Messaging.SendEmailResult> results) {
        Integer successCount = 0;
        Integer failureCount = 0;

        for (Messaging.SendEmailResult result : results) {
            if (result.isSuccess()) {
                successCount++;
            } else {
                failureCount++;
                for (Messaging.SendEmailError error : result.getErrors()) {
                    System.debug(LoggingLevel.WARN, 'Email error: ' + error.getMessage());
                }
            }
        }

        System.debug(LoggingLevel.INFO, 'Emails sent: ' + successCount + ', Failed: ' + failureCount);
    }
}