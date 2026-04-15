trigger AccountNumberTrigger on Account (before insert, after update) {
    if(Trigger.isBefore && Trigger.isInsert){
     	MembershipAccountIdSequenceGenerator.assignAccountNumbers(Trigger.new);   
    }
    if(Trigger.isAfter && Trigger.isUpdate){
        MembershipAccountIdSequenceGenerator.updatePrimaryContact(Trigger.new, Trigger.oldMap);
    }
}