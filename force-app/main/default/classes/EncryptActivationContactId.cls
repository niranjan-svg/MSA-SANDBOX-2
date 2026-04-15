public with sharing class EncryptActivationContactId {

    public class Request {
        @InvocableVariable(required=true)
        public String contactId;
    }

    public class Response {
        @InvocableVariable
        public String encryptedContactId;
    }

    @InvocableMethod(label='Encrypt Contact Id' description='Encrypts a Contact Id and returns a Base64 string')
    public static List<Response> encryptContactId(List<Request> requests) {
        List<Response> responses = new List<Response>();

        // Retrieve the Base64-encoded encryption key from Custom Metadata
        Membership_Shared_Secret__mdt keyRecord = [
            SELECT Base_64_Key__c
            FROM Membership_Shared_Secret__mdt
            LIMIT 1
        ];

        // Decode the Base64 string to Blob (must be 32 bytes for AES256)
        Blob cryptoKey = EncodingUtil.base64Decode(keyRecord.Base_64_Key__c);

        for (Request req : requests) {
            Response res = new Response();

            // Convert contact Id string to Blob
            Blob data = Blob.valueOf(String.valueOf(req.contactId));

            // Encrypt using AES256 with managed IV
            Blob encryptedData = Crypto.encryptWithManagedIV('AES256', cryptoKey, data);

            // Encode to Base64 for safe text output
            String base64Encoded = EncodingUtil.base64Encode(encryptedData);

            // **NEW:** URL-encode the Base64 string to handle special characters
            res.encryptedContactId = EncodingUtil.urlEncode(base64Encoded, 'UTF-8');
            system.debug('encryptedContactId-----'+res.encryptedContactId);
            system.debug('res---'+res);
            responses.add(res);
        }
        system.debug('responses---'+responses);
        // Return list of responses back to Flow
        return responses;
    }
}