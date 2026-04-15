trigger Event_Trigger on Event (before insert, before update) {
    if(!DataMigrationSwitch__c.getInstance().DisableTrigger__c){
        TriggerFactory.createHandler(ActivityTriggerHandler.class);
    }
}