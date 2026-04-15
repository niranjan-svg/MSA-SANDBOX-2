@IsTest
public class SendMembershipRenewalReminderBatch_Test {

    // create Membership record
    private static Memberships__c createMembership(String status, Boolean renewalReminder, Boolean isActive, Date membershipTermEnd) {
        Memberships__c mem = new Memberships__c();
        mem.Membership_Status__c = status;
        mem.Renewal_Reminder__c = renewalReminder;
        mem.Is_Active__c = isActive;
        mem.TermStartDate__c = System.today();

        if (membershipTermEnd != null) {
            mem.put('TermEndDate__c', membershipTermEnd);
        }

        insert mem;
        return mem;
    }

    private static Contact createContact() {
        Contact con = new Contact(LastName = 'Test Contact', Email = 'test@email.com');
        insert con;
        return con;
    }

    //create Account (non-person) with Membership__c and Primary_Contact__c
    private static Account createBusinessAccount(Id membershipId, Id primaryContactId, Date termEndDate) {
        Account acc = new Account(Name = 'Test Business Account', Membership__c = membershipId, Primary_Contact__c = primaryContactId);
        insert acc;
        return acc;
    }

    @IsTest
    static void testBatch_MembershipActivated_30Days() {
        Date membershipTermEnd = System.today().addDays(30); // Active membership → future term end
        Memberships__c mem = createMembership('Membership Activated', true, true, membershipTermEnd);
        Contact con = createContact();

        Date accountTermEnd = System.today().addDays(30);
        createBusinessAccount(mem.Id, con.Id, accountTermEnd);

        Test.startTest();
        Database.executeBatch(new SendMembershipRenewalReminderBatch_New(), 200);
        Test.stopTest();
    }

    @IsTest
    static void testBatch_GracePeriod_30Days() {
        Date membershipTermEnd = System.today().addDays(-30); // Grace Period → term end in past
        Memberships__c mem = createMembership('In Grace Period', true, true, membershipTermEnd);
        Contact con = createContact();

        Date accountTermEnd = System.today().addDays(-30);
        createBusinessAccount(mem.Id, con.Id, accountTermEnd);

        Test.startTest();
        Database.executeBatch(new SendMembershipRenewalReminderBatch_New(), 200);
        Test.stopTest();
    }

    @IsTest
    static void testBatch_GracePeriod_60Days() {
        Date membershipTermEnd = System.today().addDays(-60);
        Memberships__c mem = createMembership('In Grace Period', true, true, membershipTermEnd);
        Contact con = createContact();

        Date accountTermEnd = System.today().addDays(-60);
        createBusinessAccount(mem.Id, con.Id, accountTermEnd);

        Test.startTest();
        Database.executeBatch(new SendMembershipRenewalReminderBatch_New(), 200);
        Test.stopTest();
    }

    @IsTest
    static void testBatch_GracePeriod_90Days() {
        Date membershipTermEnd = System.today().addDays(-90);
        Memberships__c mem = createMembership('In Grace Period', true, true, membershipTermEnd);
        Contact con = createContact();

        Date accountTermEnd = System.today().addDays(-90);
        createBusinessAccount(mem.Id, con.Id, accountTermEnd);

        Test.startTest();
        Database.executeBatch(new SendMembershipRenewalReminderBatch_New(), 200);
        Test.stopTest();
    }

    @IsTest
    static void testBatch_Skip_NotReminderDay() {
        Date membershipTermEnd = System.today().addDays(10);
        Memberships__c mem = createMembership('Membership Activated', true, true, membershipTermEnd);
        Contact con = createContact();

        Date accountTermEnd = System.today().addDays(10);
        createBusinessAccount(mem.Id, con.Id, accountTermEnd);

        Test.startTest();
        Database.executeBatch(new SendMembershipRenewalReminderBatch_New(), 200);
        Test.stopTest();
    }

    @IsTest
    static void testBatch_Skip_EmailBounced() {
        Date membershipTermEnd = System.today().addDays(30);
        Memberships__c mem = createMembership('Membership Activated', true, true, membershipTermEnd);
        Contact con = createContact(); // bounced

        Date accountTermEnd = System.today().addDays(30);
        createBusinessAccount(mem.Id, con.Id, accountTermEnd);

        Test.startTest();
        Database.executeBatch(new SendMembershipRenewalReminderBatch_New(), 200);
        Test.stopTest();
    }

    @IsTest
    static void testBatch_Skip_NoPrimaryContact() {
        Date membershipTermEnd = System.today().addDays(30);
        Memberships__c mem = createMembership('Membership Activated', true, true, membershipTermEnd);

        Account acc = new Account(Name = 'No Primary Contact Account', Membership__c = mem.Id);
        insert acc;

        Test.startTest();
        Database.executeBatch(new SendMembershipRenewalReminderBatch_New(), 200);
        Test.stopTest();
    }
}