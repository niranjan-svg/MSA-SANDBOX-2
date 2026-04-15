trigger AccountTrigger on Account (after insert, after update) {
    if (Trigger.isAfter) {
        //AccountMemberCountHandler.updateMemberCounts(Trigger.new);
        //AccountMemberCountHandler.handleAccountCreation(Trigger.new);
        if (Trigger.isAfter && Trigger.isInsert) {
            CreatePersonAccountFromOrgAccount.createPersonAccount(Trigger.new);
        }
    }
}