trigger ProgramRelationshipTrigger on Program_Relationship__c (before insert, before update, after insert, after update) {
    if(!DataMigrationSwitch__c.getInstance().DisableTrigger__c){
        TriggerFactory.createHandler(ProgramRelationshipTriggerHandler.class);
    }
}