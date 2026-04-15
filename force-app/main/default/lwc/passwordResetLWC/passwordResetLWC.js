import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import initiateReset from '@salesforce/apex/MembershipPasswordResetApex.processWebhook';

export default class InitiatePasswordReset extends LightningElement {
    @api recordId;
    isLoading = false;

    // Handles the "Yes" button click
    async handleConfirm() {
        this.isLoading = true;

        try {
            // Call the Apex controller method which returns a simple string
            const result = await initiateReset({ recordId: this.recordId });

            // Check the definitive string returned from Apex
            if (result === 'Password reset initiated successfully') {
                // Show success toast
                this.showToast('Success', result, 'success');
            } else {
                // Show error toast with the failure message from Apex
                this.showToast('Error', result, 'error');
            }

            // Close the quick action modal
            this.dispatchEvent(new CloseActionScreenEvent());

        } catch (error) {
            // This will catch any unexpected framework or network errors
            const errorMessage = error.body?.message || error.message || 'An unexpected error occurred';
            this.showToast('Error Initiating Password Reset', errorMessage, 'error');
            
            // Close the modal
            this.dispatchEvent(new CloseActionScreenEvent());

        } finally {
            this.isLoading = false;
        }
    }

    // Handles the "No" button click
    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    // Helper function for showing toast notifications
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}