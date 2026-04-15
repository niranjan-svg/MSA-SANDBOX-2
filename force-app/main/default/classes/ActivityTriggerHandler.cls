public with sharing class ActivityTriggerHandler implements TriggerInterface {

    // Common Data Structures
    Set<Id> accountIds = new Set<Id>();
    Map<Id, Account> accMap = new Map<Id, Account>();
    Map<Id, Account> parentAccMap = new Map<Id, Account>();

    // Collect account ids from Tasks
    public void collectAccountIdsFromTasks(List<Task> taskList){
        for(Task t : taskList){
            if(t.WhatId != null && String.valueOf(t.WhatId).startsWith('001')){
                accountIds.add(t.WhatId);
            }
        }
    }
	// Collect account ids from Events
    public void collectAccountIdsFromEvents(List<Event> eventList){
        for(Event e : eventList){
            if(e.WhatId != null && String.valueOf(e.WhatId).startsWith('001')){
                accountIds.add(e.WhatId);
            }
        }
    }

    /**
     * bulkBefore
     */
    public void bulkBefore(){

        // Collect Account Ids from Trigger
        if(Trigger.isInsert || Trigger.isUpdate){
            
            if(Trigger.new != null){
                for(SObject so : Trigger.new){
                    
                    if(so instanceof Task){
                        Task t = (Task)so;
                        if(t.WhatId != null && String.valueOf(t.WhatId).startsWith('001')){
                            accountIds.add(t.WhatId);
                        }
                    }
                    else if(so instanceof Event){
                        Event e = (Event)so;
                        if(e.WhatId != null && String.valueOf(e.WhatId).startsWith('001')){
                            accountIds.add(e.WhatId);
                        }
                    }
                }
            }
        }
        
        if(accountIds.isEmpty()) return;

        // Person Accounts
        accMap = new Map<Id, Account>(
            [SELECT Id, IsPersonAccount, Parent_Account__c, PersonContactId FROM Account WHERE Id IN :accountIds]);

        // Parent Accounts
        Set<Id> parentIds = new Set<Id>();
        for(Account acc : accMap.values()){
            if(acc.Parent_Account__c != null){
                parentIds.add(acc.Parent_Account__c);
            }
        }

        if(!parentIds.isEmpty()){
            parentAccMap = new Map<Id, Account>([SELECT Id, Primary_Contact__c FROM Account WHERE Id IN :parentIds]);
        }
    }

    /**
     * BEFORE INSERT
     */
    public void beforeInsert(SObject so){

        if(so instanceof Task){
            Task t = (Task)so;
            updateTaskParent(t);
        }
        else if(so instanceof Event){
            Event e = (Event)so;
            updateEventParent(e);
        }
    }

    /**
     * BEFORE UPDATE
     */
    public void beforeUpdate(SObject oldSo, SObject so){

        if(so instanceof Task){
            Task t = (Task)so;
            updateTaskParent(t);
        }
        else if(so instanceof Event){
            Event e = (Event)so;
            updateEventParent(e);
        }
    }

    /**
     * Common Logic - Task
     */
    private void updateTaskParent(Task t){

        if(t.WhatId == null) return;

        Account acc = accMap.get(t.WhatId);

        if(acc != null && acc.IsPersonAccount && acc.Parent_Account__c != null){

            Account parentAcc = parentAccMap.get(acc.Parent_Account__c);

            if(parentAcc != null && parentAcc.Primary_Contact__c == acc.PersonContactId){
                t.WhatId = acc.Parent_Account__c;
            }
        }
    }

    /**
     * Common Logic - Event
     */
    private void updateEventParent(Event e){

        if(e.WhatId == null) return;

        Account acc = accMap.get(e.WhatId);

        if(acc != null && acc.IsPersonAccount && acc.Parent_Account__c != null){

            Account parentAcc = parentAccMap.get(acc.Parent_Account__c);

            if(parentAcc != null && parentAcc.Primary_Contact__c == acc.PersonContactId){
                e.WhatId = acc.Parent_Account__c;
            }
        }
    }

    public void bulkAfter(){}

    public void afterInsert(SObject so){}

    public void afterUpdate(SObject oldSo, SObject so){}

    public void beforeDelete(SObject so){}

    public void afterDelete(SObject so){}

    public void andFinally(){}
}