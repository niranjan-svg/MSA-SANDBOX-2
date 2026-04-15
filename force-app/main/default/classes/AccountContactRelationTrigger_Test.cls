@isTest
public class AccountContactRelationTrigger_Test {

     /* ----------------------------------------------------------
       Test Setup – reusable data for all test methods
       ---------------------------------------------------------- */
    @testSetup
    static void setupData() {
        
        // Standard Pricebook
        Id stdPb = Test.getStandardPricebookId();
        Pricebook2 pb = new Pricebook2(Id = stdPb, IsActive = true);
        update pb;
        
        // Membership Type
        Membership_Type__c memType = new Membership_Type__c(Name = 'Gold', Max_Sub_Members__c = 10, IsActive__c=true, Description__c='test', Price__c = 100);
        insert memType;

        // Membership
        Memberships__c membership = new Memberships__c(Membership_Type__c = memType.Id, TermStartDate__c = Date.today());
        insert membership;

        Id personRtId;
        Id orgRtId;
		Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();

        if (rtMap.containsKey('PersonAccount')) {
            personRtId = rtMap.get('PersonAccount').getRecordTypeId();
        }
        if (rtMap.containsKey('Organization_Account')) {
            orgRtId = rtMap.get('Organization_Account').getRecordTypeId();
        }
        
        // Account
        List<Account> accList = new List<Account>();
        Account acc = new Account(LastName = 'Testing', Membership__c = membership.Id, RecordTypeId = personRtId, personEmail = 'testAcc101@gmail.com');
        Account acc1 = new Account(LastName = 'Testing2', Membership__c = membership.Id, RecordTypeId = personRtId, personEmail = 'testAcc102@gmail.com');
        accList.add(acc);
        accList.add(acc1);
        Account acct = new Account(Name = 'org Test', Program_Type__c = 'Coordinating Program', Person_Last_Name__c = 'pc-cont',
                                   Orgnanization_Email__c  = 'test101@gmail.com', Membership__c = membership.Id, RecordTypeId = orgRtId);
        accList.add(acct);
        insert accList;
    }
	/* ----------------------------------------------------------
       Test: Insert ACR within max limit
       ---------------------------------------------------------- */
    @IsTest
    static void testInsertACRWithinLimit() {
		Account personAcc = [SELECT Id, PersonContactId FROM Account WHERE IsPersonAccount = true LIMIT 1];
        Account acc = [SELECT Id FROM Account WHERE IsPersonAccount = false LIMIT 1];
		
        Test.startTest();

        AccountContactRelation acr = new AccountContactRelation(AccountId = acc.Id, ContactId = personAcc.PersonContactId, Roles = 'Primary Contact');
        insert acr;

        Test.stopTest();
    }
	
    @IsTest
    static void testAfterUpdate_PrimaryContactSwap() {
        
        List<Account> personAcc = [SELECT Id, PersonContactId FROM Account WHERE IsPersonAccount = true LIMIT 2];
        Account acc = [SELECT Id FROM Account WHERE IsPersonAccount = false LIMIT 1];

        AccountContactRelation acr = new AccountContactRelation(AccountId = acc.Id, ContactId = personAcc[0].PersonContactId, Roles = 'Primary Contact');
        insert acr;
        
        AccountContactRelation acrToUpdate = new AccountContactRelation(AccountId = acc.Id,
            ContactId = personAcc[1].PersonContactId,
            Roles = 'Admin'
        );
        insert acrToUpdate;

        Test.startTest();
		AccountContactRelation acrToBeUpdated = [select id from AccountContactRelation where roles = 'admin' limit 1];
        acrToBeUpdated.Roles = 'Primary Contact';
        update acrToBeUpdated;
		
        Test.stopTest();
    }
    
	@IsTest
    static void deleteACR(){
        List<Account> personAcc = [SELECT Id, PersonContactId FROM Account WHERE IsPersonAccount = true LIMIT 2];
        Account acc = [SELECT Id FROM Account WHERE IsPersonAccount = false LIMIT 1];

        AccountContactRelation acr = new AccountContactRelation(AccountId = acc.Id, ContactId = personAcc[0].PersonContactId, Roles = 'Primary Contact');
        insert acr;
        
        AccountContactRelation acrToUpdate = new AccountContactRelation(AccountId = acc.Id,
            ContactId = personAcc[1].PersonContactId,
            Roles = 'Admin'
        );
        insert acrToUpdate;
        AccountContactRelation acrDelete = [SELECT Id, AccountId FROM AccountContactRelation LIMIT 1];

        Test.startTest();
        delete acrDelete;
        Test.stopTest();
    }
}