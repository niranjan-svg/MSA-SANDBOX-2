global class MembershipGracePeriodHandlerBatch implements Database.Batchable<sObject>, Schedulable {
    
    // --- Batchable part: The main processing logic ---

    // The 'start' method gathers all the records we need to check.
    global Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('=== START METHOD INITIATED ===');
       
            // Find all memberships that expired yesterday. This is our "scope".
            String query = 'SELECT Id FROM Memberships__c ' +
                           'WHERE Membership_Status__c = \'Membership Activated\' ' +
                           'AND Is_Active__c = true ' +
                           'AND TermEndDate__c = YESTERDAY';
            System.debug('Query constructed: ' + query);
            
            Database.QueryLocator queryLocator = Database.getQueryLocator(query);
            System.debug('QueryLocator created successfully');
            System.debug('=== START METHOD COMPLETED SUCCESSFULLY ===');
            return queryLocator;
        
    }

    // The 'execute' method runs for each batch of records found by the 'start' method.
    global void execute(Database.BatchableContext bc, List<sObject> scope) {
        System.debug('=== EXECUTE METHOD INITIATED ===');
        System.debug('Processing batch with ' + scope.size() + ' records');
        
      
            // Cast the generic sObject list to the specific list of Membership__c.
            List<Memberships__c> expiringMemberships = (List<Memberships__c>)scope;
            System.debug('Successfully cast scope to Memberships__c list');

            // --- Step 1: Collect Account IDs from the Expiring Memberships in this batch ---
            Set<Id> expiringMembershipIds = new Map<Id, SObject>(expiringMemberships).keySet();
            System.debug('Step 1: Collected ' + expiringMembershipIds.size() + ' membership IDs');
            
            Map<Id, Id> membershipIdToAccountIdMap = new Map<Id, Id>();
            
            try {
                for (Account acc : [SELECT Id, Membership__c FROM Account WHERE Membership__c IN :expiringMembershipIds]) {
                    membershipIdToAccountIdMap.put(acc.Membership__c, acc.Id);
                }
                System.debug('Step 1: Created membership to account mapping with ' + membershipIdToAccountIdMap.size() + ' entries');
                System.debug('membershipIdToAccountIdMap: ' + membershipIdToAccountIdMap);
            } catch (QueryException qe) {System.debug('ERROR in Account query: ' + qe.getMessage());return; }

            // --- Step 2: Find All Accounts in this batch that ALREADY have a Queued Membership ---
            Set<Id> accountIdsInScope = new Set<Id>(membershipIdToAccountIdMap.values());
            System.debug('Step 2: Processing ' + accountIdsInScope.size() + ' account IDs');

            Set<Id> accountsWithQueuedMembership = new Set<Id>();
            
            try {
                for (Memberships__c queuedMembership : [
                    SELECT Id, Account__c 
                    FROM Memberships__c 
                    WHERE Membership_Status__c = 'Queued' 
                      AND Account__c IN :accountIdsInScope
                ]) {
                    accountsWithQueuedMembership.add(queuedMembership.Account__c);
                }
                System.debug('Step 2: Found ' + accountsWithQueuedMembership.size() + ' accounts with queued memberships');
                System.debug('accountsWithQueuedMembership: ' + accountsWithQueuedMembership);
            } catch (QueryException qe) {System.debug('ERROR in Queued Membership query: ' + qe.getMessage());return; }

            // --- Step 3: Identify Memberships to be updated to "In Grace Period" ---
            List<Memberships__c> membershipsToUpdate = new List<Memberships__c>();
            System.debug('Step 3: Starting membership evaluation for grace period');

            for (Memberships__c expiringMembership : expiringMemberships) {
                try {
                    Id accountId = membershipIdToAccountIdMap.get(expiringMembership.Id);
                    System.debug('Processing membership: ' + expiringMembership.Id + ', Account: ' + accountId);

                    if (accountId != null && !accountsWithQueuedMembership.contains(accountId)) {
                        membershipsToUpdate.add(new Memberships__c(
                            Id = expiringMembership.Id,
                            Membership_Status__c = 'In Grace Period'
                        ));
                        System.debug('Added membership ' + expiringMembership.Id + ' to grace period update list');
                    } else {
                        System.debug('Skipped membership ' + expiringMembership.Id + ' - has queued membership or no account');
                    }
                } catch (Exception ex) { System.debug('ERROR processing individual membership ' + expiringMembership.Id + ': ' + ex.getMessage()); }
            }
            
            System.debug('Step 3: Identified ' + membershipsToUpdate.size() + ' memberships for grace period update');

            // --- Step 4: Perform a single, bulk DML operation for this batch ---
            if (!membershipsToUpdate.isEmpty()) {
                System.debug('Step 4: Starting DML update operation');
                try {
                    Database.SaveResult[] updateResults = Database.update(membershipsToUpdate, false);
                    
                    Integer successCount = 0;
                    Integer failureCount = 0;
                    
                    for (Integer i = 0; i < updateResults.size(); i++) {
                        Database.SaveResult sr = updateResults[i];
                        if (sr.isSuccess()) {
                            successCount++;
                            System.debug('Successfully updated membership: ' + membershipsToUpdate[i].Id);
                        } else {
                            failureCount++;
                            String errorMsg = 'Failed to update membership: ' + membershipsToUpdate[i].Id + '. ';
                            for (Database.Error err : sr.getErrors()) {
                                errorMsg += err.getStatusCode() + ': ' + err.getMessage() + '. ';
                            }
                            System.debug('ERROR updating membership: ' + errorMsg);
                           // logError('DML update failure', errorMsg, '', 'DMLException');
                        }
                    }
                    
                    System.debug('Step 4: DML completed - Success: ' + successCount + ', Failures: ' + failureCount);
                } catch (DmlException dmlEx) {System.debug('ERROR in DML operation: ' + dmlEx.getMessage()); }
            } else {
                System.debug('Step 4: No memberships to update, skipping DML operation');
            }

            System.debug('=== EXECUTE METHOD COMPLETED SUCCESSFULLY ===');

    }

    // The 'finish' method runs once after all batches are complete.
    global void finish(Database.BatchableContext bc) {
     
    }
    
    // --- Schedulable part: To run this job once a year ---
    global void execute(SchedulableContext sc) {
        System.debug('=== SCHEDULABLE EXECUTE METHOD INITIATED ===');
        try {
            System.debug('Starting batch execution with batch size 200');
            Database.executeBatch(new MembershipGracePeriodHandlerBatch(), 200);
            System.debug('=== SCHEDULABLE EXECUTE METHOD COMPLETED SUCCESSFULLY ===');
        } catch (Exception ex) {System.debug('ERROR in schedulable execute: ' + ex.getMessage());}
    }
    
    // --- Simplified Error Logging Helper Method ---
    /*private static void logError(String context, String errorMessage, String stackTrace, String errorType) {
        try {
            Error__c errorLog = new Error__c();
            errorLog.Error_Message__c = errorMessage?.length() > 32000 ? errorMessage.substring(0, 32000) : errorMessage;
            errorLog.Error_Trace__c = stackTrace?.length() > 32000 ? stackTrace.substring(0, 32000) : stackTrace;
            errorLog.Error_Type__c = errorType?.length() > 255 ? errorType.substring(0, 255) : errorType;
            
            Database.SaveResult logResult = Database.insert(errorLog, false);
            
            if (logResult.isSuccess()) {
                System.debug('Error logged successfully for context: ' + context);
            } else {
                System.debug('Failed to insert error log: ' + logResult.getErrors());
            }
            
        } catch (Exception logEx) {
            System.debug('CRITICAL ERROR in error logging: ' + logEx.getMessage());
            System.debug('Original error context: ' + context + ', Message: ' + errorMessage);
        }
    }*/
}