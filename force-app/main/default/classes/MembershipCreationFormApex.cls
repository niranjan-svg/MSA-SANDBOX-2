public with sharing class MembershipCreationFormApex {
    @AuraEnabled
    public static Id accountAndSubMemberCreation(Account accountDetails, Account addInfo, List<Account> subMembers) {
        try {
            // Create Account with additional info
            Account accountRecord = new Account();
            accountRecord.Name = accountDetails.Name;
            accountRecord.Phone = accountDetails.Phone;
            accountRecord.Fax = accountDetails.Fax;
            accountRecord.Fax = accountDetails.Website;
            accountRecord.Type = addInfo.Type;
            accountRecord.Description = addInfo.Description;
            accountRecord.BillingStreet = addInfo.BillingStreet;
            accountRecord.BillingCity = addInfo.BillingCity;
            accountRecord.BillingState = addInfo.BillingState;
            accountRecord.BillingPostalCode = addInfo.BillingPostalCode;
            accountRecord.BillingCountry = addInfo.BillingCountry;
            accountRecord.ShippingStreet = addInfo.ShippingStreet;
            accountRecord.ShippingCity = addInfo.ShippingCity;
            accountRecord.ShippingState = addInfo.ShippingState;
            accountRecord.ShippingPostalCode = addInfo.ShippingPostalCode;
            accountRecord.ShippingCountry = addInfo.ShippingCountry;
            
            insert accountRecord;
            
            // Get the newly created Account Id
            Id parentId = accountRecord.Id;

            List<Account> listOfSubMembers = New List<Account>();
            for (Account subMember : subMembers) {
                Account subMemberRecord = new Account();
                subMemberRecord.ParentId = parentId;
                subMemberRecord.Name = subMember.Name;
                subMemberRecord.Website = subMember.Website;
                subMemberRecord.Type = subMember.Type;
                listOfSubMembers.add(subMemberRecord);
            }
            insert listOfSubMembers;

            // Return the Account Id
            return parentId;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void uploadDocument(String accountId, List<String> contentDocumentIds) {
        try {
            List<ContentDocumentLink> contentDocumentLinks = new List<ContentDocumentLink>();
            for (String documentId : contentDocumentIds) {
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = documentId;
                cdl.LinkedEntityId = accountId;
                cdl.ShareType = 'V';
                cdl.Visibility = 'AllUsers';
                contentDocumentLinks.add(cdl);
            }
            insert contentDocumentLinks;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void createPaymentInstrument(Id accountId, Map<String, Object> paymentInfo, Map<String, Object> bankInfo, Map<String, Object> ccInfo, Map<String, Object> paymentProcessInfo) {
        try {
            PaymentInstrument pi = new PaymentInstrument();
            pi.AccountId = accountId;

            // Fill Payment Instrument fields with respective values passed from JS
            if(paymentInfo != null) {
                pi.Type = (String) paymentInfo.get('type');
                pi.Last4 = (String) paymentInfo.get('last4Digits');
                pi.DigitalWalletProvider = (String) paymentInfo.get('walletProvider');
            }

            if(bankInfo != null) {
                pi.BankName = (String) bankInfo.get('bankName');
                pi.BankCode = (String) bankInfo.get('bankCode');
                pi.BankAccountHolderType = (String) bankInfo.get('accHolderType');
                pi.BankAccountType = (String) bankInfo.get('accType');
                pi.BankAccountNumber = (String) bankInfo.get('accNumber');
            }

            if(ccInfo != null) {
                pi.ExpiryMonth = (String) ccInfo.get('expiryMonth');
                pi.ExpiryYear = (String) ccInfo.get('expiryYear');
                pi.CardBrand = (String) ccInfo.get('cardBrand');
            }

            if(paymentProcessInfo != null) {
                pi.PaymentProcessorName = (String) paymentProcessInfo.get('processorName');
                pi.ProcessorReference = (String) paymentProcessInfo.get('processorRef');
                pi.GatewayName = (String) paymentProcessInfo.get('gatewayName');
                pi.GatewayReference = (String) paymentProcessInfo.get('gatewayRef');
            }

            // Insert Payment Instrument
            insert pi;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}