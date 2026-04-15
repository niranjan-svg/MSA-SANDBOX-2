import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import encryptRecordId from '@salesforce/apex/PaymentGatewayController.encryptRecordId';

export default class ProcessPaymentButton extends NavigationMixin(LightningElement) {
    @api recordId;

    // The headless quick action framework calls this method when the button is clicked.
    @api async invoke() {
        console.log('Invoke method called for recordId:', this.recordId);
        try {
            // Call the Apex method to get the encrypted record ID
            const encryptedId = await encryptRecordId({ recordId: this.recordId });
            
            // Construct the full URL for the payment gateway
            const paymentGatewayUrl = `http://members.msa.preview.rygn.io/secure/payment-gateway?transactionId=${encodeURIComponent(encryptedId)}`;

            console.log('Navigating to URL:', paymentGatewayUrl);

            // Use NavigationMixin to navigate to the external web page
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: paymentGatewayUrl
                }
            });
        } catch (error) {
            console.error('Error processing payment:', error);
            // Optionally, you can show a toast notification to the user upon error
        }
    }
}