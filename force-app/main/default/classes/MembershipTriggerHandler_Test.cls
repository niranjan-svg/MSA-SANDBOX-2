@isTest
private class MembershipTriggerHandler_Test {
    
    @isTest
    static void firstTestMethod() {
        
        // Standard Pricebook
        Id stdPb = Test.getStandardPricebookId();
        Pricebook2 pb = new Pricebook2(Id = stdPb, IsActive = true);
        update pb;
        
        // Membership Type
        Membership_Type__c memType = new Membership_Type__c(Name = 'Gold', Max_Sub_Members__c = 10, IsActive__c=true, Description__c='test', Price__c = 100);
        insert memType;

        // Membership
        Memberships__c membership = new Memberships__c(Membership_Type__c = memType.Id, TermStartDate__c = Date.today(), Membership_status__c = 'Payment Pending');
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
        Account acc = new Account(LastName = 'Testing', Membership__c = membership.Id, RecordTypeId = personRtId);
        Account acc1 = new Account(LastName = 'Testing2', Membership__c = membership.Id, RecordTypeId = personRtId);
        accList.add(acc);
        accList.add(acc1);
        Account acct = new Account(Name = 'org Test', Program_Type__c = 'Coordinating Program', Person_Last_Name__c = 'pc-cont',
                                   Person_Email__c = 'test101@gmail.com', Membership__c = membership.Id, RecordTypeId = orgRtId);
        accList.add(acct);
        insert accList;
        
        membership.Membership_Status__c ='Membership Activated';
        membership.Related_Account__c = accList[2].Id;
        update membership;
        
        membership.Membership_Status__c ='In Grace Period';
        membership.TermStartDate__c = Date.valueOf('2025-01-01');
        membership.TermEndDate__c = Date.valueOf('2025-12-31');
        update membership;
        
        // Associate the active membership with the account
        accList[2].Membership__c = membership.Id;
        update accList[2];
    }	
}