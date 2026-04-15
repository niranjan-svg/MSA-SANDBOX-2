/**
* @description Batch Apex class to calculate and update the Remaining Fund on Funding Opportunity records.
* It sums the Amounts from all related Funding Disbursements and subtracts this from the Total Received Amount.
*/
public class FundingOpportunityBatchCalculator implements Database.Batchable<sObject> {
    
    /**
* @description The start method collects all Funding Opportunity records to be processed.
*/
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Assuming your object names are indeed standard. If they are custom (e.g., Funding_Opportunity__c),
        // you will need to change the object and field API names here.
        return Database.getQueryLocator([
            SELECT Id, Total_Amount_Received__c 
            FROM FundingOpportunity
        ]);
    }
    
    /**
* @description The execute method processes a chunk of Funding Opportunities.
*/
    public void execute(Database.BatchableContext bc, List<FundingOpportunity> scope) {
        
        // Get the IDs of the Funding Opportunities in the current scope
        Set<Id> opportunityIdsInScope = new Map<Id, SObject>(scope).keySet();
        
        Map<Id, Decimal> disbursedTotalsMap = new Map<Id, Decimal>();
        
        // **FIX 2: OPTIMIZED QUERY**
        // The query is now filtered to only include disbursements related to the opportunities
        // in this specific batch execution. This is much more efficient.
        // I have also corrected the relationship path to `FundingAward.FundingOpportunityId`.
        for (AggregateResult ar : [
            SELECT SUM(Amount) totalDisbursed, FundingAward.FundingOpportunityId opportunityId
            FROM FundingDisbursement 
            WHERE FundingAward.FundingOpportunityId IN :opportunityIdsInScope
            AND Status = 'Paid'
            GROUP BY FundingAward.FundingOpportunityId
        ]) {
            Id oppId = (Id) ar.get('opportunityId');
            
            // **FIX 1: THE NULL CHECK**
            // This is the most critical fix. We check if the oppId is not null
            // before trying to use it as a key in the map.
            if (oppId != null) {
                Decimal total = (Decimal) ar.get('totalDisbursed');
                // It's also good practice to handle a null sum, defaulting to 0.
                disbursedTotalsMap.put(oppId, total == null ? 0 : total);
            }
        }
        
        List<FundingOpportunity> opportunitiesToUpdate = new List<FundingOpportunity>();
        
        for (FundingOpportunity opp : scope) {
            Decimal totalReceived = opp.Total_Amount_Received__c != null ? opp.Total_Amount_Received__c : 0;
            Decimal totalDisbursed = disbursedTotalsMap.containsKey(opp.Id) ? disbursedTotalsMap.get(opp.Id) : 0;
            Decimal remainingFund = totalReceived - totalDisbursed;
            
            opportunitiesToUpdate.add(new FundingOpportunity(
                Id = opp.Id,
                Remaining_Fund__c = remainingFund
            ));
        }
        
        if (!opportunitiesToUpdate.isEmpty()) {
            update opportunitiesToUpdate;
        }
    }
    
    /**
* @description The finish method can be used to send a confirmation email or other post-processing.
*/
    public void finish(Database.BatchableContext bc) {
        System.debug('Funding Opportunity remaining fund calculation batch job finished.');
    }
}