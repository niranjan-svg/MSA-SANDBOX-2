public class TestApex {
    public static void getRelatedOpps(List<Id> accountIds){
        List<Opportunity> getOpps = [SELECT Id From Opportunity Where AccountId In:accountIds];
        if(getOpps!=null){
            for(Opportunity opp:getOpps){
                system.debug('Opportunity Name'+opp.Name);
            }
        }
    }
}