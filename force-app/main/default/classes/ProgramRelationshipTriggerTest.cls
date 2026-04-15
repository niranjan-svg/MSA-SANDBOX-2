@isTest
public class ProgramRelationshipTriggerTest {


    @isTest
    static void testBeforeInsertValid() {
        
        Id orgRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Organization Account').getRecordTypeId();

        Account cp = new Account(name = 'Cordinating Program',Program_Type__c = 'Coordinating Program',recordtypeId = orgRecordTypeId,Person_Last_Name__c = 'Tes LName');
        cp.Person_Email__c = 'test@test.com'; 
        insert cp;
        
        Account lp = new Account(name = 'Cordinating Program',Program_Type__c = 'Local Program',recordtypeId = orgRecordTypeId,Person_Last_Name__c = 'Tes LName');
        lp.Person_Email__c = 'test@test.com'; 
        lp.Coordinating_Program__c = cp.Id;
        insert lp;
        
        Test.startTest();
        Program_Relationship__c pr = new Program_Relationship__c(
            Local_Program__c = lp.Id,
            Coordinating_Program__c = cp.Id,
            Status__c = 'Active',
            Term_Start_Date__c = Date.today(),
            Term_End_Date__c = Date.today().addyears(1),
            Relationship_Type__c = 'Jurisdictional',
            Is_PR_Created_From_Account__c = false
        );
        insert pr;
        
        pr.Is_PR_Created_From_Account__c = true;
        update pr;
        
        Test.stopTest();
    }
    
    @isTest
    static void test2() {
        
        Id orgRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Organization Account').getRecordTypeId();

        Account cp = new Account(name = 'Cordinating Program',Program_Type__c = 'Coordinating Program',recordtypeId = orgRecordTypeId,Person_Last_Name__c = 'Tes LName');
        cp.Person_Email__c = 'test@test.com'; 
        insert cp;
        
        Account lp = new Account(name = 'Cordinating Program',Program_Type__c = 'Local Program',recordtypeId = orgRecordTypeId,Person_Last_Name__c = 'Tes LName');
        lp.Person_Email__c = 'test@test.com'; 
        lp.Coordinating_Program__c = cp.Id;
        insert lp;
        
        Test.startTest();
        Program_Relationship__c pr = new Program_Relationship__c(
            Local_Program__c = lp.Id,
            Coordinating_Program__c = cp.Id,
            Status__c = 'Inactive',
            Term_Start_Date__c = Date.today(),
            Term_End_Date__c = Date.today().addyears(1),
            Relationship_Type__c = 'Jurisdictional',
            Is_PR_Created_From_Account__c = false
        );
        insert pr;
        
        pr.Status__c = 'Active';
        update pr;
        
        Program_Relationship__c pr1 = new Program_Relationship__c(
            Local_Program__c = lp.Id,
            Coordinating_Program__c = cp.Id,
            Status__c = 'Active',
            Term_Start_Date__c = Date.today(),
            Term_End_Date__c = Date.today().addyears(1),
            Relationship_Type__c = 'Jurisdictional',
            Is_PR_Created_From_Account__c = false
        );
        try{
            insert pr1;
        } catch (DmlException e){
            //System.assert(e.getMessage().contains('already related with another CP'), 'Expected LP already related error but got: ' + e.getMessage());
        }
        
        Test.stopTest();

    }

}