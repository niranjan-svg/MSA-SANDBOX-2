import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

// Account fields
import ROLLUP_SUB_MEMBER from '@salesforce/schema/Account.Rollup_Sub_Member__c';
import MAX_SUB_MEMBER from '@salesforce/schema/Account.Max_Sub_Members__c';

const FIELDS = [
    ROLLUP_SUB_MEMBER,
    MAX_SUB_MEMBER
];

export default class AccountMembersBanner extends LightningElement {
    @api recordId;

    rollupSubMembers = 0;
    maxSubMembers = 0;
    isLoaded = false;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredAccount({ error, data }) {
        if (data) {
            this.rollupSubMembers =
                data.fields.Rollup_Sub_Member__c?.value ?? 0;

            this.maxSubMembers =
                data.fields.Max_Sub_Members__c?.value ?? 0;

            this.isLoaded = true;
        } else if (error) {
            // Fail gracefully
            this.rollupSubMembers = 0;
            this.maxSubMembers = 0;
            this.isLoaded = true;
            console.error('Error loading Account fields', error);
        }
    }
}