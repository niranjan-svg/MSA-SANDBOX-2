import { api } from 'lwc';
import LightningModal from 'lightning/modal';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import processRefund from '@salesforce/apex/MembershipRefundProcessor.processRefund';

export default class RefundConfirmationModal extends LightningModal {
    @api recordId;
    isProcessing = false;

    // Handler for the "Yes" button click
    async handleYesClick() {
        this.isProcessing = true;
        try {
            const result = await processRefund({ refundId: this.recordId });

            if (result === 'Refund Processing') {
                this.showToast('Success', 'Refund is processing. Status will be updated shortly.', 'success');
                
                // Close the modal using the standard close method
                this.close('success');
                
                // Also dispatch CloseActionScreenEvent for quick action compatibility
                this.dispatchCloseActionEvent();
            } else {
                this.showToast('Error', 'Error during processing the refund.', 'error');
                this.isProcessing = false;
            }
        } catch (error) {
            this.showToast('System Error', 'An unexpected error occurred: ' + (error.body ? error.body.message : error.message), 'error');
            this.isProcessing = false;
        }
    }

    // Handler for the "No" button
    handleNoClick() {
        // Close the modal
        this.close('cancel');
        
        // Dispatch CloseActionScreenEvent for quick action compatibility
        this.dispatchCloseActionEvent();
    }

    // Helper method to dispatch CloseActionScreenEvent
    dispatchCloseActionEvent() {
        // Use bubbles: true and composed: true to ensure event propagates correctly
        this.dispatchEvent(new CloseActionScreenEvent({ bubbles: true, composed: true }));
    }

    // Helper function to show toast messages
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'sticky'
        });
        this.dispatchEvent(event);
    }
}