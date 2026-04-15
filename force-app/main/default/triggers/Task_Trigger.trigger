trigger Task_Trigger on Task (before insert, before update) {
    if(!DataMigrationSwitch__c.getInstance().DisableTrigger__c){
        TriggerFactory.createHandler(ActivityTriggerHandler.class);
    }
}