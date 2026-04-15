trigger AccountContactRelation_Trigger on AccountContactRelation (before insert,before update, after insert, after update, after delete) {
    if(!DataMigrationSwitch__c.getInstance().DisableTrigger__c){
        TriggerFactory.createHandler(AccountContactRelationTriggerHandler.class);
    }
}