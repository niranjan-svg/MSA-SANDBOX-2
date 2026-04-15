trigger ApplicationReviewTrigger on ApplicationReview (after update) {

    // Only execute logic for the "after update" event
    if (Trigger.isAfter && Trigger.isUpdate) {
        
        // Call the handler method, passing the new and old versions of the records
        ApplicationReviewCalloutHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
    
}