public class SubmittableOrgAccountSyncHelper {
    
    @Future(callout=true)
    public static void syncOrganizations() {
        system.debug('code entered');
        List<Error__c> errorsToInsert = new List<Error__c>();
        List<Account> accountsToInsert = new List<Account>();
        String continuationToken = '';
        List<Map<String, Object>> allOrgDataItems = new List<Map<String, Object>>();
        try{
            // STEP 1: Loop through all pages and collect all organization data from the API first
            do {
                HttpRequest req = new HttpRequest();
                String endpoint = 'callout:Submittable_API/v4/public-organizations';
                system.debug('endpoint---'+endpoint);
                if (!String.isBlank(continuationToken)) {
                    endpoint += '?continuationToken=' + EncodingUtil.urlEncode(continuationToken, 'UTF-8');
                }
                req.setEndpoint(endpoint);
                req.setMethod('GET');
                
                
                Http http = new Http();
                HttpResponse res = http.send(req);
                
                if (res.getStatusCode() == 200) {
                    system.debug('getStatusCode-------------25'+res.getStatusCode());
                    system.debug('getbody-------------26'+res.getStatusCode());
                    Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    List<Object> items = (List<Object>) results.get('items');
                    if (items != null) {
                        for(Object item : items) {
                            allOrgDataItems.add((Map<String, Object>) item);
                        }
                    }
                    continuationToken = (String) results.get('continuationToken');
                } else {
                    system.debug('getStatusCode-------------36'+res.getStatusCode());
                    system.debug('getbody-------------37'+res.getStatusCode());
                    errorsToInsert.add(ErrorLoggingApex.createErrorLog(
                        'Endpoint Error',
                        'External Reviewer Sync Job Failed',
                        req.getBody(),
                        res.getBody(),
                        String.valueOf(res.getStatusCode()),
                        null // No Apex exception object in this case
                    ));
                }
                
            } while (!String.isBlank(continuationToken));
            system.debug('while');
            system.debug('while');
            if (allOrgDataItems.isEmpty()) {
                System.debug('No organization data retrieved from Submittable.');
                return; // Exit if no data
            }
            
            // STEP 2: Collect all Submittable Org IDs from the retrieved data
            Set<String> submittableOrgIds = new Set<String>();
            for (Map<String, Object> orgData : allOrgDataItems) {
                submittableOrgIds.add((String)orgData.get('id'));
            }
            
            // STEP 3: Query for all existing Accounts that match the retrieved IDs
            Map<String, Account> existingAccountsMap = new Map<String, Account>();
            if (!submittableOrgIds.isEmpty()) {
                for (Account acc : [SELECT Id, Submittable_Org_ID__c FROM Account WHERE Submittable_Org_ID__c IN :submittableOrgIds]) {
                    existingAccountsMap.put(acc.Submittable_Org_ID__c, acc);
                }
            }
            
            // STEP 4: Iterate through the API data again and create Accounts ONLY if they don't already exist
            for (Map<String, Object> orgData : allOrgDataItems) {
                String orgId = (String) orgData.get('id');
                Id orgAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Organization_Account').getRecordTypeId();
                
                // If the map does NOT contain the ID, it's a new record
                if (orgId != null && !existingAccountsMap.containsKey(orgId)) {
                    Account acc = new Account();
                    String countryValue;
                    // === Map Top-Level Fields ===
                    acc.Submittable_Org_ID__c = orgId;
                    acc.Name = (String) orgData.get('name');
                    acc.BillingStreet = (String) orgData.get('address');
                    acc.BillingCity = (String) orgData.get('city');
                    //acc.BillingState = (String) orgData.get('region');
                    acc.BillingPostalCode = (String) orgData.get('postalCode');
                    countryValue = (String) orgData.get('country');
                    acc.Id_Type__c = (String) orgData.get('idType');
                    acc.UEI_Government_Id__c = (String) orgData.get('governmentId');
                    acc.Government_Id_Type__c = (String) orgData.get('governmentIdType');
                    acc.RecordTypeId = orgAccountRecordTypeId;
                    if(countryValue=='US' ||countryValue=='USA'){
                        acc.BillingCountry = 'United States';
                    }
                    
                    // === Parse Nested ueiData Object ===
                    if (orgData.get('ueiData') instanceof Map<String, Object>) {
                        parseUeiData(acc, (Map<String, Object>) orgData.get('ueiData'));
                    }
                    
                    // === Parse Nested 'data' JSON String ===
                    if (orgData.get('data') instanceof String) {
                        parseDataField(acc, (String) orgData.get('data'));
                    }
                    
                    accountsToInsert.add(acc);
                }
            }
            
            // STEP 5: Insert the list of new accounts
            if (!accountsToInsert.isEmpty()) {
                try {
                    insert accountsToInsert;
                } catch (Exception e) {
                    System.debug('DML Exception on Account Insert: ' + e.getMessage());
                }
            }
        }
        catch(exception ex){
            Error__c errorLog = new Error__c();
            errorLog.Name = ex.getTypeName();
            errorLog.Error_Message__c = ex.getMessage();
            errorLog.Error_Trace__c = ex.getStackTraceString();
            insert errorLog;
        }
        
    }
    
    /**
* @description Parses the 'ueiData' object from the response and maps to the Account.
* @param acc The Account record to populate.
* @param ueiDataMap The map representing the ueiData JSON object.
*/
    private static void parseUeiData(Account acc, Map<String, Object> ueiDataMap) {
        if (ueiDataMap == null || ueiDataMap.isEmpty()) {
            return;
        }
        acc.Cage_Code__c = (String) ueiDataMap.get('cageCode');
        acc.Registration_Purpose__c = (String) ueiDataMap.get('registrationPurpose');
        
        Object expDateObj = ueiDataMap.get('registrationExpirationDate');
        if (expDateObj instanceof String) {
            try {
                acc.Registration_Expiration_Date__c = Date.valueOf((String)expDateObj);
            } catch (Exception e) {
                System.debug('Could not parse Registration Expiration Date: ' + expDateObj);
            }
        }
    }
    
    /**
* @description Parses the JSON string from the 'data' field and maps its contents to the Account.
* @param acc The Account record to populate.
* @param dataJsonString The string containing JSON from the 'data' field.
*/
    private static void parseDataField(Account acc, String dataJsonString) {
        if (String.isBlank(dataJsonString)) {
            return;
        }
        
        try {
            Map<String, Object> dataMap = (Map<String, Object>) JSON.deserializeUntyped(dataJsonString);
            
            acc.Subsection_Description__c = (String) dataMap.get('subsection_description');
            acc.Tax_or_Governing_Entity_ID__c = (String) dataMap.get('ein');
            acc.Reason_for_NonPrivate_Foundation_Status__c = (String) dataMap.get('foundation_509a_status');
            acc.OFAC_Status__c = (String) dataMap.get('ofac_status');
            acc.Pub_78_Verified__c = (Boolean) dataMap.get('pub78_verified');
            
            if (dataMap.get('most_recent_pub78') instanceof String) {
                acc.Most_Recent_IRS_Pub78__c = Date.valueOf(((String) dataMap.get('most_recent_pub78')).substring(0, 10));
            }
            if (dataMap.get('most_recent_irb') instanceof String) {
                acc.Most_Recent_IRB__c = Date.valueOf(((String) dataMap.get('most_recent_irb')).substring(0, 10));
            }
            
            Object orgTypesObj = dataMap.get('organization_types');
            if (orgTypesObj instanceof List<Object> && !((List<Object>) orgTypesObj).isEmpty()) {
                List<Object> orgTypesList = (List<Object>) orgTypesObj;
                if (!orgTypesList.isEmpty() && orgTypesList[0] instanceof Map<String, Object>) {
                    Map<String, Object> firstOrgType = (Map<String, Object>) orgTypesList[0];
                    acc.Deductibility_Status__c = (String) firstOrgType.get('deductibility_status_description');
                    acc.Organization_Type__c = (String) firstOrgType.get('organization_type');
                }
            }
            
            acc.Ruling_Date__c = formatRulingDate(
                (String) dataMap.get('ruling_year'),
                (String) dataMap.get('ruling_month')
            );
            
        } catch (Exception e) {
            System.debug('Could not parse the "data" field JSON: ' + dataJsonString + '. Error: ' + e.getMessage());
        }
    }
    
    /**
* @description Formats year and month strings into 'Mmm yyyy' format.
* @param yearStr The string for the year (e.g., "2004").
* @param monthStr The string for the month number (e.g., "01" or "1").
* @return A formatted string like "Jan 2004", or null if inputs are invalid.
*/
    private static String formatRulingDate(String yearStr, String monthStr) {
        if (String.isBlank(yearStr) || String.isBlank(monthStr)) {
            return null;
        }
        
        try {
            Integer year = Integer.valueOf(yearStr);
            Integer month = Integer.valueOf(monthStr);
            return Datetime.newInstance(year, month, 1).format('MMM yyyy');
        } catch (Exception e) {
            System.debug('Could not format ruling date from year: ' + yearStr + ' and month: ' + monthStr);
            return null;
        }
    }
}