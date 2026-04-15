public class MembershipAuditCreationHandler {
    public static void handleMembershipUpdate(List<Memberships__c> newRecords, List<Memberships__c> oldRecords) {
        List<Audit_Log__c> auditLogs = new List<Audit_Log__c>();
        
        // List of system fields to exclude
        Set<String> systemFields = new Set<String>{
            'createdbyid', 'createddate', 'lastmodifiedbyid', 'lastmodifieddate', 'systemmodstamp'
        };

        // Get the fields of the Memberships__c object
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Memberships__c.fields.getMap();

        for (Integer i = 0; i < newRecords.size(); i++) {
            Memberships__c newRecord = newRecords[i];
            Memberships__c oldRecord = oldRecords[i];

            // Create a change description for each field that has changed
            String changeDescription = '';

            for (String fieldName : fieldMap.keySet()) {
                // Skip system fields
                if (systemFields.contains(fieldName)) {
                    continue;
                }
                system.debug('fieldName-----'+fieldName);

                Object newValue = newRecord.get(fieldName);
                Object oldValue = oldRecord.get(fieldName);

                // Check if the value has changed
                if (newValue != oldValue) {
                    // Get the field label
                    String fieldLabel = fieldMap.get(fieldName).getDescribe().getLabel();
                    changeDescription += fieldLabel + ' was updated from \'' + String.valueOf(oldValue) + '\' to \'' + String.valueOf(newValue) + '\'. ';
                    system.debug('changeDescription---'+changeDescription);
                }
            }

            // Create an audit log entry regardless of whether there were changes
            Audit_Log__c logEntry = new Audit_Log__c();
            logEntry.Membership_Record__c = newRecord.Id; // Lookup to the current record
            logEntry.ModificationTime__c = System.now(); // Timestamp of modification
            logEntry.Modified_By__c = UserInfo.getUserId(); // ID of the user who made the modification
            logEntry.Name = 'Membership - ' + newRecord.Id; // Name field with Membership Record Id
            logEntry.Change_Description__c = changeDescription.trim(); // Store the change description

            auditLogs.add(logEntry);
        }

        // Insert all audit log entries at once
        if (!auditLogs.isEmpty()) {
            insert auditLogs;
        }
    }
}