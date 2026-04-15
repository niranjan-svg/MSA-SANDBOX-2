import { LightningElement, track, wire } from 'lwc';
//import saveAccount from '@salesforce/apex/MembershipCreationFormApex.saveAccount';
//import linkFilesToAccount from '@salesforce/apex/MembershipCreationFormApex.linkFilesToAccount';
import accountAndSubMemberCreation from '@salesforce/apex/MembershipCreationFormApex.accountAndSubMemberCreation';
import uploadDocument from '@salesforce/apex/MembershipCreationFormApex.uploadDocument';
import createPaymentInstrument from '@salesforce/apex/MembershipCreationFormApex.createPaymentInstrument';
import TYPE_FIELD from '@salesforce/schema/PaymentInstrument.Type';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';

export default class MultiStepWizard extends LightningElement {
    @track currentStep = '1';
    @track accountDetails = {sobjectType: 'Account',Name: '', phone: '', fax: '', website: ''};
    @track addInfo = {
        sobjectType: 'Account',
        type: '',
        description: '',
        billingStreet: '',
        billingCity: '',
        billingState: '',
        billingZip: '',
        billingCountry: '',
        shippingStreet: '',
        shippingCity: '',
        shippingState: '',
        shippingZip: '',
        shippingCountry: ''
    };

    @track subMembers= [{ sobjectType: 'Account',key: '1', Name: '', Email: '', Type: '', Description: '' }];
    uploadedFiles = [];
    @track paymentInfo = {
        sobjectType: 'PaymentInstrument',
        accHolderName: '',
        type: '',
        last4Digits: '',
        walletProvider: ''
    };
    @track bankInfo = {
        sobjectType: 'PaymentInstrument',
        bankName: '',
        bankCode: '',
        accHolderType: '',
        accType: '',
        accNumber: ''
    };
    @track ccInfo = {
        sobjectType: 'PaymentInstrument',
        expiryMonth: '',
        expiryYear: '',
        cardBrand: ''
    };
    @track paymentProcessInfo = {
        sobjectType: 'PaymentInstrument',
        processorName: '',
        processorRef: '',
        gatewayName: '',
        gatewayRef: ''
    };
    @track uploadedFileIds = [];
    @track uploadedFileNames = [];
    @track paymentRecordId; 

   /* @wire(getPicklistValues, { recordTypeId: "012300000012BYNQAG", fieldApiName: TYPE_FIELD })
    wiredPolicyOptions({ error, data }) {
        console.log('data---',data);
        if (data) {
            this.paymentTypeOptions = data.values;
            console.log('data.values---',data.values);
            console.log('this.paymentTypeOptions---',this.paymentTypeOptions);
        } else if (error) {
            this.paymentTypeOptions = [];
        }
    }*/


    @wire(getPicklistValues, {
         recordTypeId: '012000000000000AAA',
         fieldApiName: TYPE_FIELD
     })
     wiredResponseTypeValues({ data, error }) {
         if (data) {
             this.paymentTypeOptions = data.values.map(value => ({
                 label: value.label,
                value: value.value
             }));
         } else if (error) {
             this.showToast('Error', 'Error loading Response Type options', 'error');
         }
     }


    steps = [
        { id: '1', label: 'Account Details' },
        { id: '2', label: 'Sub Member Details' },
        { id: '3', label: 'Supporting Documents' },
        { id: '4', label: 'Payment Info' },
        { id: '5', label: 'Review and Confirm' }
    ];

    get isStep1() { return this.currentStep === '1'; }
    get isStep2() { return this.currentStep === '2'; }
    get isStep3() { return this.currentStep === '3'; }
    get isStep4() { return this.currentStep === '4'; }
    get isStep5() { return this.currentStep === '5'; }

    handleFieldChange(event) {
        const { id, dataset: { key, subKey } } = event.target;
        if (key === 'accountDetails') {
            this.accountDetails[id] = event.target.value;
        } else if (key === 'addInfo') {
            this.addInfo[id] = event.target.value;
        } else if (key === 'subMembers') {
            this.subMembers[subKey][id] = event.target.value;
        } else if (key === 'paymentInfo') {
            this.paymentInfo[id] = event.target.value;
        } else if (key === 'bankInfo') {
            this.bankInfo[id] = event.target.value;
        } else if (key === 'ccInfo') {
            this.ccInfo[id] = event.target.value;
        } else if (key === 'paymentProcessInfo') {
            this.paymentProcessInfo[id] = event.target.value;
        }
    }

    addSubMember() {
        this.subMembers.push({ key: `${Date.now()}`, Name: '', Website: '', Type: '', Description: '' });
    }
    handleDeleteSubMember(event) {
        const index = event.target.dataset.index;
        this.subMembers.splice(index, 1);
        this.subMembers = [...this.subMembers];  // Reassign to trigger reactivity
    }
    handleNext() {
        debugger;
        
        console.log('currentStep----',this.currentStep);
        const accountNameInput = this.template.querySelector('lightning-input[data-id="accountName"]');
        
        if (this.currentStep === '1' && !accountNameInput.value) {
            this.showToast('Error', 'Account Name is required.', 'error');
            return;
        }
        else if(this.currentStep === '1'){
            this.accountDetails.Name = accountNameInput.value;
            console.log('account detaillssss-----',this.accountDetails.Name);
        }

        
            if (this.currentStep === '2') {
                const subMemberElements = this.template.querySelectorAll('[data-key="subMembers"]');
                console.log('subMemberElements----',subMemberElements);
                console.log('subMemberElements.length----',subMemberElements.length);
                subMemberElements.forEach(element => {
                    const index = element.dataset.subKey;
                    if(!this.subMembers[index]) {
                        this.subMembers[index] = {};
                    }
                    this.subMembers[index][element.dataset.field] = element.value;
                });
                console.log('Sub members:', this.subMembers);
            }
            if(this.currentStep==='4'){
                const accountHolder = this.template.querySelector('lightning-input[data-id="accHolderName"]');
                this.paymentInfo.accHolderName = accountHolder.value;
                console.log('accHolderName:',this.paymentInfo.accHolderName);
            }
            
        if (parseInt(this.currentStep, 10) < 5) {
            this.currentStep = String(parseInt(this.currentStep, 10) + 1);
        }
    }

    handlePrevious() {
        console.log('uploadedFileIds:', this.uploadedFileIds);
        if (parseInt(this.currentStep, 10) > 1) {
            this.currentStep = String(parseInt(this.currentStep, 10) - 1);
        }
    }

    handleFileUpload(event) {
        var uploadedFiles = event.detail.files;
        console.log('uploadedFiles:', uploadedFiles);

        uploadedFiles.forEach(file => {
            this.uploadedFileIds.push(file.documentId);
            this.uploadedFileNames.push(file.name);
        });

        console.log('uploadedFileIds:', this.uploadedFileIds);
        console.log('uploadedFileNames:', this.uploadedFileNames);

    }

    /*async handleSubmit() {
        handleCreateAccountAndSubMembers()

       
    }
    handleCreateAccountAndSubMembers() {
        accountAndSubMemberCreation({ 
            accountDetails: this.accountDetails,
            addInfo: this.addInfo,
            subMembers: this.subMembers
        })
        .then(result => {
            this.accountId = result;
            console.log('Account and Sub Members created successfully with Parent Account Id: ', this.accountId);
        })
        .catch(error => {
            console.error('Error in creating Account and Sub Members: ', error);
        });
    }*/


        async handleSubmit() {
            debugger;
            try {
                // 1. Create Account and Sub Members
                const accountId = await accountAndSubMemberCreation({
                    accountDetails: this.accountDetails,
                    addInfo: this.addInfo,
                    subMembers: this.subMembers
                });
    
                this.accountRecordId = accountId;
                console.log('this.accountRecordId----',this.accountRecordId);
                // 2. Upload Documents
                await uploadDocument({ accountId: this.accountRecordId, contentDocumentIds: this.uploadedFileIds });
    
                // 3. Create Payment Instrument
                await createPaymentInstrument({
                    accountId: this.accountRecordId,
                    paymentInfo: this.paymentInfo,
                    bankInfo: this.bankInfo,
                    ccInfo: this.ccInfo,
                    paymentProcessInfo: this.paymentProcessInfo
                });
    
                this.showToast('Success', 'All records created successfully', 'success');
            } catch (error) {
                this.showToast('Error', error.body.message, 'error');
            }
        }

    /*async linkUploadedFiles(accountId) {
        if (this.uploadedFiles.length > 0) {
            const fileContents = await Promise.all(this.uploadedFiles.map(file => this.readFile(file)));
            const contentDocumentIds = []; // List of uploaded file Document IDs

            // You should write file upload logic here and populate `contentDocumentIds` accordingly,
            // using either REST API or custom Apex classes.

            try {
                await linkFilesToAccount({ accountId, contentDocumentIds });
            } catch (error) {
                this.showToast('Error', `Failed to link files: ${error.body.message}`, 'error');
            }
        }
    }*/

 

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get uploadedFileNames() {
        return this.uploadedFiles.map(file => file.name).join(', ');
    }

    getReviewDetails() {
        return {
            accountDetails: this.accountDetails,
            additionalInfo: this.addInfo,
            subMembers: this.subMembers,
            uploadedFiles: this.uploadedFiles.map(file => file.name).join(', '),
            paymentInfo: this.paymentInfo,
            bankInfo: this.bankInfo,
            ccInfo: this.ccInfo,
            paymentProcessInfo: this.paymentProcessInfo
        };
    }
}