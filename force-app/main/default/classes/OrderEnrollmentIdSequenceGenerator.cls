public with sharing class OrderEnrollmentIdSequenceGenerator {

    /**
     * Assign Enrollment_Id_Number__c for new Orders
     * Called from BEFORE INSERT trigger
     */
    private static String COORDINATING_PROGRAM = 'Coordinating Program';
    private static String LOCAL_PROGRAM = 'Local Program';
    private static String PAID_BY_COORDINATING_PROGRAM = 'Paid By Coordinating Program';
    
    public static void assignEnrollmentNumbers(List<Order> incomingOrders) {

        if (incomingOrders == null || incomingOrders.isEmpty()) {
            return;
        }

        // Only orders that need Enrollment Id
        List<Order> ordersNeedingNumbers = new List<Order>();
        for (Order ord : incomingOrders) {
            if (ord != null && ord.Enrollment_Id_Number__c == null) {
                ordersNeedingNumbers.add(ord);
            }
        }

        if (ordersNeedingNumbers.isEmpty()) {
            return;
        }

        // Get current max Enrollment Id Number
        Decimal currentMax = fetchCurrentMaxEnrollmentNumber();

        // Assign sequential numbers
        for (Order ord : ordersNeedingNumbers) {
            currentMax++;
            ord.Enrollment_Id_Number__c = currentMax;
            ord.Enrollment_Id__c = String.valueOf(currentMax);
        }
    }

    /**
     * Fetch maximum Enrollment_Id_Number__c from Order
     */
    public static Decimal fetchCurrentMaxEnrollmentNumber() {

        Decimal maxValue = 0;

        AggregateResult[] results = [SELECT MAX(Enrollment_Id_Number__c) maxNumber FROM Order WHERE Enrollment_Id_Number__c != null];

        if (!results.isEmpty() && results[0].get('maxNumber') != null) {
            maxValue = (Decimal) results[0].get('maxNumber');
        }

        System.debug('Current Max Enrollment Id => ' + maxValue);
        return maxValue;
    }
    
    public static void updateRenewalReminder(List<Order> listOfOrder){
        if (listOfOrder == null || listOfOrder.isEmpty()) {
            return;
        }
        // Collect Account Ids
        Set<Id> accountIds = new Set<Id>();
        Set<Id> membershipTypeIds = new Set<Id>();
        
        for (Order o : listOfOrder) {
            if (o.AccountId != null) {
                accountIds.add(o.AccountId);
            }
            if (o.Membership_Type__c != null){
                membershipTypeIds.add(o.Membership_Type__c);
            } 
        }

        if (accountIds.isEmpty()) {
            return;
        }

        // Query Accounts once
        Map<Id, Account> accountMap = new Map<Id, Account>([SELECT Id, Program_Type__c, IsPersonAccount FROM Account WHERE Id IN :accountIds]);
        
        Map<Id, Membership_Type__c> membershipTypeMap = membershipTypeIds.isEmpty() ? new Map<Id, Membership_Type__c>()
        					: new Map<Id, Membership_Type__c>([SELECT Id, Name FROM Membership_Type__c WHERE Id IN :membershipTypeIds]);
        
		Map<String, Staff_Membership_Type__c> csMembershipType = Staff_Membership_Type__c.getAll();
        
        // Apply rules with clear precedence
        for (Order o : listOfOrder) {

            Account acc = accountMap.get(o.AccountId);
            Membership_Type__c mt = membershipTypeMap.get(o.Membership_Type__c);
            
            if (acc == null) continue;
            
            if(String.isBlank(acc.Program_Type__c) && (mt <> null && csMembershipType.containsKey(mt.Name))){
                o.Auto_Renewal__c = false;
                continue;
            }
			
            // RULE 1: Coordinating Program → never send
            if(acc.Program_Type__c == COORDINATING_PROGRAM){
                o.Auto_Renewal__c = false;
                //o.Billing_Type__c = 'Self-Pay';
                continue;
            }

            // RULE 2: Person Account + Individual Membership
            if(acc.IsPersonAccount && o.Membership_Type__c <> null && (mt <> null && !csMembershipType.containsKey(mt.Name))){
                o.Auto_Renewal__c = true;
                continue;
            }
            if(mt <> null && csMembershipType.containsKey(mt.Name)){
                o.Auto_Renewal__c = false;
                continue;
            }
            if(acc.Program_Type__c == LOCAL_PROGRAM && o.Billing_Type__c == PAID_BY_COORDINATING_PROGRAM){
                o.Auto_Renewal__c = false;
                continue;
            }
            // RULE 3: Local Program
            if(acc.Program_Type__c == LOCAL_PROGRAM){
                o.Auto_Renewal__c = true;
            }
            System.debug('Order..>'+o);
        }
    }
}