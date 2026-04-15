public class customLookUpController {   
    @AuraEnabled
    public static List < sObject > fetchLookUpValues(String searchKeyWord, String ObjectName, String Method, String ParentID, String PartnerID,string parentAccId) {
        
        String searchKey = searchKeyWord + '%';
        List < sObject > returnList = new List < sObject > ();
        
        String sQuery ='';
        String sQuery2 ='';
        
       
        if (Method=='Insured Contact'){
            if(ObjectName=='Contact' && parentAccId!=null){
                sQuery =  'select id, Name from ' +ObjectName + ' where recordType.Name=:Method AND accountId=:parentAccId AND Name LIKE: searchKey order by createdDate DESC limit 5';
                system.debug('sQuery '+sQuery);
            }
            else
            {
                sQuery =  'select id, Name from ' +ObjectName + ' where recordType.Name=:Method AND Name LIKE: searchKey order by createdDate DESC limit 5';
                system.debug('sQuery '+sQuery);
            }
        }
        else if (Method=='Funder'){
            if(ObjectName=='Funder__c'){
                sQuery =  'select id, Name from ' +ObjectName + ' where recordType.Name=\'Funder\' AND Name LIKE: searchKey order by createdDate DESC limit 5';
                system.debug('sQuery '+sQuery);
            }
            
        }
        else
        {    
            if(ObjectName=='Account')
            {
                sQuery =  'select id, Name,Insured_ID__c from ' +ObjectName + ' where Name LIKE: searchKey order by createdDate DESC limit 5';
            }
            else if(ObjectName=='Carrier__c')
            {
                sQuery =  'select id, Name,Carrier_Name__c from ' +ObjectName + ' where Carrier_Name__c LIKE: searchKey OR Name LIKE: searchKey order by createdDate DESC limit 5';
            }
            else
            {
                sQuery =  'select id, Name from ' +ObjectName + ' where Name LIKE: searchKey order by createdDate DESC limit 5';
            }
        }
        
        List < sObject > lstOfRecords = Database.query(sQuery);
        system.debug('lstOfRecords1 '+lstOfRecords);
        for (sObject obj: lstOfRecords) {
            returnList.add(obj);
        } 
        system.debug('returnList1 '+returnList);
        return returnList;
    }
}