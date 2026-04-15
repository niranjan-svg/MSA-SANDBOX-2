@isTest
private class PaymentGatewayControllerTest {

    @isTest
    static void testEncryptRecordId_Success() {
        // ARRANGE: Create a sample record to get a valid ID.
        Contact testContact = new Contact(LastName = 'Test');
        insert testContact;
        String originalRecordId = testContact.Id;

        // ACT: Call the method being tested.
        Test.startTest();
        String encryptedResult = PaymentGatewayController.encryptRecordId(originalRecordId);
        Test.stopTest();

        // ASSERT: Verify the encrypted output.
        
        // 1. Basic assertions: Ensure the result is not null or empty.
        System.assertNotEquals(null, encryptedResult, 'The encrypted result should not be null.');
        System.assertNotEquals('', encryptedResult, 'The encrypted result should not be empty.');

        // 2. Advanced assertion: Decrypt the result to confirm it's correct.
        // This is the most important part of the test.
        
        // Retrieve the same key the original method used.
        Membership_Shared_Secret__mdt keyRecord = [
            SELECT Base_64_Key__c  
            FROM Membership_Shared_Secret__mdt 
            LIMIT 1
        ];
        Blob cryptoKey = EncodingUtil.base64Decode(keyRecord.Base_64_Key__c);

        // Perform the reverse operation: decode and decrypt.
        Blob encryptedDataBlob = EncodingUtil.base64Decode(encryptedResult);
        Blob decryptedDataBlob = Crypto.decryptWithManagedIV('AES256', cryptoKey, encryptedDataBlob);
        String decryptedRecordId = decryptedDataBlob.toString();

        // Assert that the decrypted ID matches the original ID.
        System.assertEquals(originalRecordId, decryptedRecordId, 'The decrypted record ID must match the original record ID.');
    }

    @isTest
    static void testEncryptRecordId_HandlesNullInput() {
        // ARRANGE: Prepare a null recordId.
        String nullRecordId = null;
        String result;
        Exception caughtException = null;

        // ACT: Call the method with null input inside a try-catch block.
        Test.startTest();
        try {
            result = PaymentGatewayController.encryptRecordId(nullRecordId);
        } catch (Exception e) {
            caughtException = e;
        }
        Test.stopTest();

        // ASSERT: Verify that the method threw an exception.
        // This is expected because Blob.valueOf(null) throws an error.
        System.assertNotEquals(null, caughtException, 'A NullPointerException should have been thrown.');
        // Optionally, check for the specific type of exception.
        System.assert(caughtException instanceof System.NullPointerException, 'The exception should be a NullPointerException.');
    }
}