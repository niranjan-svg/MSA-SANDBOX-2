trigger OrderEnrollmentTrigger on Order (before insert, before update) {
    if(!DataMigrationSwitch__c.getInstance().DisableTrigger__c){
    	OrderEnrollmentIdSequenceGenerator.assignEnrollmentNumbers(Trigger.new);
    	OrderEnrollmentIdSequenceGenerator.updateRenewalReminder(Trigger.new);
    }
}