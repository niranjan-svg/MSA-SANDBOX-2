({
    doInit : function(component, event, helper) {
        var action = component.get("c.getMembership");
        action.setParams({ accountId: component.get("v.recordId") });

        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                var membership = response.getReturnValue();
                component.set("v.membership", membership);

                if (membership) {
                    component.set("v.membershipId", membership.Id);

                    // *** FIX #1: Use the correct field name 'TermEndDate__c' ***
                    var termEndDate = new Date(membership.TermEndDate__c);
                    var today = new Date();

                    // *** FIX #2: Use the correct field name 'Is_Active__c' in the conditions ***
                    // This logic now matches your original request exactly.
                    // NOTE: With your sample data where Is_Active__c is TRUE, neither of these conditions will be met.
                    if (membership.Is_Active__c === false && termEndDate < today) {
                        component.set("v.message", "The Account's membership has expired. Please renew.");
                        component.set("v.bannerClass", "slds-theme_warning");
                        component.set("v.iconName", "utility:warning");
                        component.set("v.showBanner", true);
                    }
                    // **** OPTIONAL: Add a condition for when Is_Active__c is true ****
                    // If you want to show a banner for active memberships, you can add this block.
                    else if (membership.Is_Active__c === true) {
                        component.set("v.message", "This Account has an active membership.");
                        component.set("v.bannerClass", "slds-theme_success");
                        component.set("v.iconName", "utility:success");
                        component.set("v.showBanner", true);
                    }

                } else {
                    // This is the condition for when the lookup is empty.
                    component.set("v.message", "This account does not have any memberships.");
                    component.set("v.bannerClass", "slds-theme_shade"); // Using slds-theme_shade for grey
                    component.set("v.iconName", "utility:info");
                    component.set("v.showBanner", true);
                }
            } else if (state === "ERROR") {
                var errors = response.getError();
                if (errors) {
                    if (errors[0] && errors[0].message) {
                        console.error("Error message: " + errors[0].message);
                    }
                } else {
                    console.error("Unknown error");
                }
            }
        });
        $A.enqueueAction(action);
    }
})