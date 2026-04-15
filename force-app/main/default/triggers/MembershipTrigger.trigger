trigger MembershipTrigger on Memberships__c (before insert,before update, after insert, after update, after delete){
    if(!DataMigrationSwitch__c.getInstance().DisableTrigger__c){
        TriggerFactory.createHandler(MembershipTriggerHandler.class);
        /*if(Trigger.isAfter && Trigger.isUpdate){
        	MembershipAuditCreationHandler.handleMembershipUpdate(Trigger.new, Trigger.old);
    	}*/ 
    } 
}