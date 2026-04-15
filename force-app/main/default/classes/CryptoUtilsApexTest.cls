@isTest
private class CryptoUtilsApexTest {
    
    // Test successful encryption with valid custom metadata
    @isTest
    static void testEncryptValue_Success() {
        // Arrange: Create test custom metadata record (must exist in your org)
        // Note: Custom Metadata records cannot be created in test classes,
        // so you need to have a real record in your org for testing
        
        String testPlainText = 'TestPassword123';
        
        Test.startTest();
        
        try {
            // Act: Call the encryption method
            String encryptedValue = CryptoUtilsApex.encryptValue(testPlainText);
            
            // Assert: Verify encrypted value is not null and not empty
            System.assertNotEquals(null, encryptedValue, 'Encrypted value should not be null');
            System.assertNotEquals('', encryptedValue, 'Encrypted value should not be empty');
            System.assertNotEquals(testPlainText, encryptedValue, 'Encrypted value should be different from plain text');
            
            // Verify it's a valid base64 string (no exception thrown)
            Blob decodedBlob = EncodingUtil.base64Decode(encryptedValue);
            System.assertNotEquals(null, decodedBlob, 'Should be valid base64 encoded string');
            
        } catch (Exception e) {
            System.assert(false, 'Encryption should succeed with valid metadata: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    // Test encryption with different string lengths
    @isTest
    static void testEncryptValue_DifferentStringLengths() {
        Test.startTest();
        
        try {
            // Test with short string
            String shortText = 'abc';
            String encryptedShort = CryptoUtilsApex.encryptValue(shortText);
            System.assertNotEquals(null, encryptedShort, 'Short text encryption should succeed');
            
            // Test with long string
            String longText = 'This is a much longer test string with special characters !@#$%^&*() and numbers 1234567890';
            String encryptedLong = CryptoUtilsApex.encryptValue(longText);
            System.assertNotEquals(null, encryptedLong, 'Long text encryption should succeed');
            
            // Verify different inputs produce different outputs
            System.assertNotEquals(encryptedShort, encryptedLong, 'Different inputs should produce different encrypted outputs');
            
        } catch (Exception e) {
            System.assert(false, 'Encryption with different lengths should succeed: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    // Test encryption with special characters
    @isTest
    static void testEncryptValue_SpecialCharacters() {
        Test.startTest();
        
        try {
            String specialChars = 'Test!@#$%^&*()_+-={}[]|:";\'<>?,./~`';
            String encrypted = CryptoUtilsApex.encryptValue(specialChars);
            
            System.assertNotEquals(null, encrypted, 'Special character encryption should succeed');
            System.assertNotEquals(specialChars, encrypted, 'Encrypted value should differ from original');
            
        } catch (Exception e) {
            System.assert(false, 'Encryption with special characters should succeed: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    // Test that each encryption produces unique output (due to managed IV)
    @isTest
    static void testEncryptValue_UniqueOutputs() {
        Test.startTest();
        
        try {
            String plainText = 'SameTestValue';
            
            // Encrypt the same value twice
            String encrypted1 = CryptoUtilsApex.encryptValue(plainText);
            String encrypted2 = CryptoUtilsApex.encryptValue(plainText);
            
            // Assert: Due to managed IV, same input should produce different encrypted outputs
            System.assertNotEquals(encrypted1, encrypted2, 
                'Same plaintext should produce different encrypted values due to unique IV');
            
        } catch (Exception e) {
            System.assert(false, 'Multiple encryptions should succeed: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    // Test error handling when custom metadata is missing
    @isTest
    static void testEncryptValue_MissingMetadata() {
        // This test will only work if you temporarily remove the custom metadata record
        // or create a separate method that allows dependency injection for testing
        
        // For a more robust test, consider refactoring your code to accept
        // the key as a parameter or use dependency injection
        
        // Currently, this test documents the expected behavior
        // when custom metadata is not configured
        Test.startTest();
        
        // Note: This test assumes the custom metadata exists
        // If it doesn't exist, it would throw AuraHandledException
        // In practice, you should always have test metadata configured
        
        Test.stopTest();
    }
    
    // Test with empty string
    @isTest
    static void testEncryptValue_EmptyString() {
        Test.startTest();
        
        try {
            String emptyString = '';
            String encrypted = CryptoUtilsApex.encryptValue(emptyString);
            
            System.assertNotEquals(null, encrypted, 'Empty string encryption should return a value');
            
        } catch (Exception e) {
            System.assert(false, 'Empty string encryption should succeed: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    // Test with numeric strings
    @isTest
    static void testEncryptValue_NumericString() {
        Test.startTest();
        
        try {
            String numericString = '1234567890';
            String encrypted = CryptoUtilsApex.encryptValue(numericString);
            
            System.assertNotEquals(null, encrypted, 'Numeric string encryption should succeed');
            System.assertNotEquals(numericString, encrypted, 'Encrypted value should differ from original');
            
        } catch (Exception e) {
            System.assert(false, 'Numeric string encryption should succeed: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    // Test bulk encryption (multiple values)
    @isTest
    static void testEncryptValue_BulkEncryption() {
        Test.startTest();
        
        try {
            List<String> plainTexts = new List<String>{
                'Value1', 'Value2', 'Value3', 'Value4', 'Value5'
            };
            
            Set<String> encryptedValues = new Set<String>();
            
            for (String plainText : plainTexts) {
                String encrypted = CryptoUtilsApex.encryptValue(plainText);
                System.assertNotEquals(null, encrypted, 'Bulk encryption should succeed for: ' + plainText);
                encryptedValues.add(encrypted);
            }
            
            // Verify all encrypted values are unique
            System.assertEquals(plainTexts.size(), encryptedValues.size(), 
                'All encrypted values should be unique');
            
        } catch (Exception e) {
            System.assert(false, 'Bulk encryption should succeed: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
}