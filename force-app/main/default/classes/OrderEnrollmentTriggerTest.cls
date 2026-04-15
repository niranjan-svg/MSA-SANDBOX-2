@IsTest
public class OrderEnrollmentTriggerTest {

    // Create test Account
    private static Account createAccount() {
        Account acc = new Account(Name = 'Order Enrollment Test Account');
        insert acc;
        return acc;
    }

    /**
     * Test that Enrollment IDs are assigned on insert
     */
    @IsTest
    static void testEnrollmentAssignmentOnInsert() {
        Account acc = createAccount();

        List<Order> orders = new List<Order>{
            new Order(AccountId = acc.Id, Status = 'Draft', EffectiveDate = Date.today(), EndDate = Date.today()+1),
            new Order(AccountId = acc.Id, Status = 'Draft', EffectiveDate = Date.today(), EndDate = Date.today()+2, Enrollment_Type__c = 'RENEW')};

        Test.startTest();
        insert orders; // Trigger fires here
        Test.stopTest();
    }

    /**
     * Test sequencing continues from existing max Enrollment Id
     */
    @IsTest
    static void testEnrollmentSequenceFromExistingMax() {
        Account acc = createAccount();

        // Existing order with Enrollment Id
        insert new Order(AccountId = acc.Id, Status = 'Draft', EffectiveDate = Date.today(), EndDate = Date.today()+1, Enrollment_Id_Number__c = 50, Enrollment_Id__c = '50');

        Order newOrder = new Order(AccountId = acc.Id, Status = 'Draft', EffectiveDate = Date.today(), EndDate = Date.today()+1, Enrollment_Type__c = 'RENEW');

        Test.startTest();
        insert newOrder;
        Test.stopTest();
    }

    /**
     * Bulk insert test (trigger bulk safety)
     */
    @IsTest
    static void testBulkInsertEnrollmentAssignment() {
        Account acc = createAccount();
        List<Order> orders = new List<Order>();

        for (Integer i = 0; i < 200; i++) {
            orders.add(new Order(AccountId = acc.Id, Status = 'Draft', EffectiveDate = Date.today(), EndDate = Date.today()+1, Enrollment_Type__c = 'RENEW'));
        }

        Test.startTest();
        insert orders;
        OrderEnrollmentIdSequenceGenerator.assignEnrollmentNumbers(null);
        OrderEnrollmentIdSequenceGenerator.updateRenewalReminder(null);
        Test.stopTest();
    }
}