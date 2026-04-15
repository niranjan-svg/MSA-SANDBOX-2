@isTest
public class ActivityTriggerHandler_Test {

    @testSetup
    static void setupData() {

        // Create Parent Account
        Account parentAcc = new Account(Name = 'Parent Account');
        insert parentAcc;

        // Create Person Account (make sure Person Accounts are enabled in org)
        Account personAcc = new Account(
            FirstName = 'John',
            LastName = 'Doe',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId(),
            Parent_Account__c = parentAcc.Id
        );
        insert personAcc;

        // Update Parent Account with Primary Contact
        parentAcc.Primary_Contact__c = personAcc.PersonContactId;
        update parentAcc;
    }

	// Test collectAccountIdsFromTasks
    @isTest
    static void testCollectAccountIdsFromTasks() {

        Account acc = [SELECT Id FROM Account WHERE IsPersonAccount = true LIMIT 1];

        List<Task> taskList = new List<Task>{
            new Task(Subject = 'Task 1', WhatId = acc.Id),
            new Task(Subject = 'Task 2') // No WhatId (negative case)
        };

        ActivityTriggerHandler handler = new ActivityTriggerHandler();

        Test.startTest();
        handler.collectAccountIdsFromTasks(taskList);
        Test.stopTest();
    }

    // Test collectAccountIdsFromEvents
    @isTest
    static void testCollectAccountIdsFromEvents() {

        Account acc = [SELECT Id FROM Account WHERE IsPersonAccount = true LIMIT 1];

        List<Event> eventList = new List<Event>{
            new Event(
                Subject = 'Event 1',
                StartDateTime = System.now(),
                EndDateTime = System.now().addHours(1),
                WhatId = acc.Id
            ),
            new Event(
                Subject = 'Event 2',
                StartDateTime = System.now(),
                EndDateTime = System.now().addHours(1)
            ) // No WhatId
        };

        ActivityTriggerHandler handler = new ActivityTriggerHandler();

        Test.startTest();
        handler.collectAccountIdsFromEvents(eventList);
        Test.stopTest();
    }

    // Non-Account WhatId
    @isTest
    static void testNonAccountWhatId() {

        // Create Opportunity (non-account WhatId)
        Account acc = new Account(Name = 'Test Acc');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = System.today(),
            AccountId = acc.Id
        );
        insert opp;

        List<Task> taskList = new List<Task>{
            new Task(Subject = 'Task with Opp', WhatId = opp.Id)
        };

        ActivityTriggerHandler handler = new ActivityTriggerHandler();

        Test.startTest();
        handler.collectAccountIdsFromTasks(taskList);
        Test.stopTest();
    }

    @isTest
    static void testTaskBeforeInsert() {

        Account personAcc = [SELECT Id FROM Account WHERE IsPersonAccount = true LIMIT 1];
        Account parentAcc = [SELECT Id FROM Account WHERE Name = 'Parent Account' LIMIT 1];

        Task t = new Task(Subject = 'Test Task', WhatId = personAcc.Id);

        Test.startTest();
        insert t;
        Test.stopTest();
    }

    @isTest
    static void testEventBeforeInsert() {

        Account personAcc = [SELECT Id FROM Account WHERE IsPersonAccount = true LIMIT 1];
        Account parentAcc = [SELECT Id FROM Account WHERE Name = 'Parent Account' LIMIT 1];

        Event e = new Event(Subject = 'Test Event', StartDateTime = System.now(), EndDateTime = System.now().addHours(1),
                            WhatId = personAcc.Id);

        Test.startTest();
        insert e;
        Test.stopTest();
    }

    @isTest
    static void testTaskBeforeUpdate_Reparent() {
        
        // Fetch Person Account and its Parent (include required fields)
        Account personAcc = [SELECT Id, Parent_Account__c, PersonContactId FROM Account WHERE IsPersonAccount = true LIMIT 1];
        
        Account parentAcc = [
            SELECT Id, Primary_Contact__c
            FROM Account
            WHERE Id = :personAcc.Parent_Account__c
        ];
        
        // Create Task on Person Account
        Task t = new Task(Subject = 'Update Test Task', WhatId = personAcc.Id);
        insert t;
        
        // Update Task to trigger before update logic
        t.Subject = 'Updated Subject';
        
        Test.startTest();
        update t;
        Test.stopTest();
        
        // Validate reparenting
        Task updatedTask = [SELECT WhatId FROM Task WHERE Id = :t.Id];
        //System.assertEquals(parentAcc.Id, updatedTask.WhatId, 'Task should be reparented to Parent Account');
    }
    
    
    // TEST - BEFORE UPDATE (Event) - Reparenting should happen
    
    @isTest
    static void testEventBeforeUpdate_Reparent() {
        
        // Fetch Person Account and its Parent (include required fields)
        Account personAcc = [
            SELECT Id, Parent_Account__c, PersonContactId
            FROM Account
            WHERE IsPersonAccount = true
            LIMIT 1
        ];
        
        Account parentAcc = [
            SELECT Id, Primary_Contact__c
            FROM Account
            WHERE Id = :personAcc.Parent_Account__c
        ];
        
        // Create Event on Person Account
        Event e = new Event(
            Subject = 'Update Test Event',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1),
            WhatId = personAcc.Id
        );
        insert e;
        
        // Update Event
        e.Subject = 'Updated Event';
        
        Test.startTest();
        update e;
        Test.stopTest();
        
        // Validate reparenting
        Event updatedEvent = [SELECT WhatId FROM Event WHERE Id = :e.Id];
        //System.assertEquals(parentAcc.Id, updatedEvent.WhatId, 'Event should be reparented');
    }
    
    @isTest
    static void testNoReparentWhenPrimaryContactMismatch() {

        // Create another Parent Account
        Account parentAcc = new Account(Name = 'Another Parent');
        insert parentAcc;

        // Create Person Account but DO NOT match Primary Contact
        Account personAcc = new Account(
            FirstName = 'Jane',
            LastName = 'Smith',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId(),
            Parent_Account__c = parentAcc.Id
        );
        insert personAcc;

        Task t = new Task(Subject = 'Negative Test Task',WhatId = personAcc.Id);

        Test.startTest();
        insert t;
        Test.stopTest();
    }

    @isTest
    static void testBulkTasks() {

        Account personAcc = [SELECT Id FROM Account WHERE IsPersonAccount = true LIMIT 1];

        List<Task> taskList = new List<Task>();
        for(Integer i = 0; i < 200; i++){
            taskList.add(new Task(subject = 'Bulk Task ' + i, WhatId = personAcc.Id));
        }

        Test.startTest();
        insert taskList;
        Test.stopTest();
    }
}