public with sharing class PaymentGatewayController {

    @AuraEnabled(cacheable=true)
    public static String encryptRecordId(String recordId) {
        // Retrieve the Base64-encoded encryption key from Custom Metadata
        Membership_Shared_Secret__mdt keyRecord = [
            SELECT Base_64_Key__c  
            FROM Membership_Shared_Secret__mdt 
            LIMIT 1
        ];
        
        // Decode the Base64 string to Blob (must be exactly 32 bytes)
        Blob cryptoKey = EncodingUtil.base64Decode(keyRecord.Base_64_Key__c);
        System.debug('cryptoKey size in bytes: ' + cryptoKey.size()); // Should output 32
        
        // Convert recordId string to Blob
        Blob data = Blob.valueOf(recordId);
        
        // Encrypt using AES256 with managed IV
        Blob encryptedData = Crypto.encryptWithManagedIV('AES256', cryptoKey, data);
        System.debug('encryptedData Blob: ' + encryptedData);
        
        // Return Base64-encoded encrypted string (NO URL encoding here)
        return EncodingUtil.base64Encode(encryptedData);
    }
}