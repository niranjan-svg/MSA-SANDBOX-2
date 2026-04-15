@isTest
private class EncryptActivationContactIdTest {

    @isTest
    static void testEncryptContactId_Success() {
        // ARRANGE: Create the test Contact record.
        // We do not need to create the Custom Metadata record.
        // The test can see the real one that already exists in your org.
        Contact testContact = new Contact(LastName = 'TestContact');
        insert testContact;
        
        // Prepare the request for the method.
        List<EncryptActivationContactId.Request> requests = new List<EncryptActivationContactId.Request>();
        EncryptActivationContactId.Request req = new EncryptActivationContactId.Request();
        req.contactId = testContact.Id;
        requests.add(req);
        
        // ACT: Execute the method.
        // The SOQL query inside the method will find the real Custom Metadata record.
        Test.startTest();
        List<EncryptActivationContactId.Response> responses = EncryptActivationContactId.encryptContactId(requests);
        Test.stopTest();

        // ASSERT: Verify the result.
        System.assertEquals(1, responses.size(), 'Should have returned one response.');
        String encryptedId = responses[0].encryptedContactId;
        System.assertNotEquals(null, encryptedId, 'The encrypted ID should not be null.');
        System.assertNotEquals('', encryptedId, 'The encrypted ID should not be an empty string.');

        // To properly verify, we must retrieve the key the same way the class did.
        Membership_Shared_Secret__mdt keyRecord = [SELECT Base_64_Key__c FROM Membership_Shared_Secret__mdt LIMIT 1];
        Blob cryptoKey = EncodingUtil.base64Decode(keyRecord.Base_64_Key__c);

        // Decrypt the result to ensure it's correct.
        String urlDecoded = EncodingUtil.urlDecode(encryptedId, 'UTF-8');
        Blob base64Decoded = EncodingUtil.base64Decode(urlDecoded);
        Blob decryptedData = Crypto.decryptWithManagedIV('AES256', cryptoKey, base64Decoded);
        
        System.assertEquals(testContact.Id, decryptedData.toString(), 'Decrypted ID must match the original Contact ID.');
    }

    @isTest
    static void testEncryptContactId_HandlesEmptyRequest() {
        // ARRANGE: Create an empty request list.
        List<EncryptActivationContactId.Request> requests = new List<EncryptActivationContactId.Request>();

        // ACT: Call the method with no requests.
        Test.startTest();
        List<EncryptActivationContactId.Response> responses = EncryptActivationContactId.encryptContactId(requests);
        Test.stopTest();

        // ASSERT: Verify it returned an empty list and did not crash.
        System.assertNotEquals(null, responses, 'Response list should not be null.');
        System.assertEquals(0, responses.size(), 'Should return an empty list for an empty request.');
    }
}