global with sharing class EncryptActivationContactIdBatch implements Database.Batchable<SObject>, Database.Stateful {

    private Blob cryptoKey;

    global EncryptActivationContactIdBatch() {
        Membership_Shared_Secret__mdt keyRecord = [SELECT Base_64_Key__c FROM Membership_Shared_Secret__mdt LIMIT 1];
        cryptoKey = EncodingUtil.base64Decode(keyRecord.Base_64_Key__c);
    }

    // Step 1: Query Accounts with Membership lookup
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id, IsPersonAccount, Primary_Contact__c, Membership__c, PersonContactId FROM Account WHERE Membership__c != NULL]);
    }

    // Step 2: For each Account, update its Membership record
    global void execute(Database.BatchableContext bc, List<Account> scope) {

		System.debug('scope..>'+scope);
        List<Memberships__c> membershipsToUpdate = new List<Memberships__c>();

        // Collect all Membership Ids from Accounts
        Set<Id> membershipIds = new Set<Id>();
        Map<Id, Account> accountMap = new Map<Id, Account>();
        for (Account acc : scope) {
            if (acc.Membership__c != null) {
                membershipIds.add(acc.Membership__c);
                accountMap.put(acc.Membership__c, acc);
            }
        }

        if (membershipIds.isEmpty()) return;

        // Fetch Memberships by Id (Account__c blank, so ignore that)
        List<Memberships__c> membershipLists = [SELECT Id, Membership_Activation_Link__c, Membership_Status__c FROM Memberships__c
												WHERE Id IN :membershipIds AND Membership_Status__c != NULL AND Membership_Status__c != 'Expired'];
		
		List<Memberships__c> membershipList = new List<Memberships__c>();
		for(Memberships__c m : membershipLists){
			if(String.isBlank(m.Membership_Activation_Link__c))
				membershipList.add(m);
		}
		
		System.debug('membershipList..>'+membershipList);
        // Loop through Memberships and encrypt the Account's ContactId
        for (Memberships__c mem : membershipList) {
            Account acc = accountMap.get(mem.Id); // map Membership Id → Account
            if (acc == null) continue;

            Id contactIdToEncrypt;
            if (acc.IsPersonAccount){
                contactIdToEncrypt = acc.PersonContactId;
            } else {
                contactIdToEncrypt = acc.Primary_Contact__c;
            }

            if (contactIdToEncrypt == null) continue;

            // Encrypt
            Blob data = Blob.valueOf(String.valueOf(contactIdToEncrypt));
            Blob encryptedData = Crypto.encryptWithManagedIV('AES256', cryptoKey, data);
            String base64Encoded = EncodingUtil.base64Encode(encryptedData);
            String encryptedContactId = EncodingUtil.urlEncode(base64Encoded, 'UTF-8');

			 // Build final Activation URL
            String activationUrl = 'https://members.mainstreet.org/membership/activate?memberId='+ encryptedContactId;
			
            // Update Membership
            mem.Membership_Activation_Link__c = activationUrl;
            membershipsToUpdate.add(mem);
        }

        if (!membershipsToUpdate.isEmpty()) {
			System.debug('membershipsToUpdate..>'+membershipsToUpdate);
            update membershipsToUpdate;
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('Membership Activation Link Batch Completed via Account → Membership Lookup!');
    }
}