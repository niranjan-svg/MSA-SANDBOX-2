import { LightningElement, api, track } from 'lwc';

export default class CustomLookupResult extends LightningElement {
    // @api rec = {}
    @api recordVal;
    @api iconName;
    @api objectApiName;
    @api key;
    @track accountRecord = false;
    @track carrierRecord = false;
    @track prospectRecord = false;
    @track defaultRecord = false;


    connectedCallback() {
       

        this.updateRecordTypeFlags();
    }

 
    updateRecordTypeFlags() {
        this.accountRecord = this.objectApiName === 'Account';
        this.carrierRecord = this.objectApiName === 'Carrier__c';
        this.prospectRecord = this.objectApiName === 'Prospect__c';
        this.defaultRecord = !this.accountRecord && !this.carrierRecord && !this.prospectRecord;
    }
    /*get accountRecord() {
        debugger;
        console.log('objectApiName---'+this.objectApiName);
        
        if(this.objectApiName === 'Account'){
            return true;
        }
        
    }
    
    get carrierRecord() {
        return this.objectApiName === 'Carrier__c';
    }

    get prospectRecord() {
        return this.objectApiName === 'Prospect__c';
    }

    get     () {
        console.log('get method---'+objectApiName);
        return !this.accountRecord && !this.carrierRecord && !this.prospectRecord;
    }*/

    selectRecord() {
        const selectEvent = new CustomEvent('selectrecord', {
            detail: this.recordVal
        });
        this.dispatchEvent(selectEvent);
    }
}