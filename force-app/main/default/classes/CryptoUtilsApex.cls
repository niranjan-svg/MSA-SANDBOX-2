public with sharing class CryptoUtilsApex {

    // A reusable method to encrypt a string value using AES256
    public static String encryptValue(String plainText) {
        // Retrieve the encryption key from Custom Metadata
        Membership_Shared_Secret__mdt [] keyRecords = [SELECT Base_64_Key__c  FROM Membership_Shared_Secret__mdt  LIMIT 1];

        if (keyRecords.isEmpty() || String.isBlank(keyRecords[0].Base_64_Key__c )) {
            throw new AuraHandledException('Encryption key is not configured. Please contact your administrator.');
        }

        Blob cryptoKey = EncodingUtil.base64Decode(keyRecords[0].Base_64_Key__c);

        if (cryptoKey.size() != 32) {
            throw new AuraHandledException('Invalid encryption key configuration. Key must be 256 bits (32 bytes).');
        }

        // Encrypt the plain text value
        Blob dataToEncrypt = Blob.valueOf(plainText);
        Blob encryptedData = Crypto.encryptWithManagedIV('AES256', cryptoKey, dataToEncrypt);
        
        return EncodingUtil.base64Encode(encryptedData);
    }
}