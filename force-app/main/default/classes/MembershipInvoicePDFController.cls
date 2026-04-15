public class MembershipInvoicePDFController {

    // --- Properties for the Visualforce Page ---
    public Invoice__c invoice { get; private set; }
    public List<Invoice_Line__c> lineItems { get; private set; }
    public String organizationName { get; private set; }
    public String invoiceDateFormatted { get; private set; }
    public String dueDateFormatted { get; private set; }
    public string term { get; private set; }
    
    // Simple, pre-prepared properties to hold the final "Issued To" address
    public String issuedToName { get; private set; }
    public String issuedToContactName { get; private set; }
    public String issuedToStreet { get; private set; }
    public String issuedToCityStateZip { get; private set; }
    public String issuedToCountry { get; private set; }
    public Boolean isIssuedToPersonAccount { get; private set; }
    public String transactionDate { get; private set; }
    public String paymentType { get; private set; }

    // Constructor - does all the data fetching and preparation
    public MembershipInvoicePDFController(ApexPages.StandardController stdController) {
        Id invoiceId = stdController.getId();
        
        // --- STEP 1: Query all possible data fields in one go ---
        List<Invoice__c> invoices = [
            SELECT Id, Name, Invoice_Date__c, Due_Date__c, Invoice_Amount__c,
                   // Data for Self-Pay Org
                   Bill_To_Account__r.Name, Bill_To_Account__r.IsPersonAccount,
                   Bill_To_Account__r.Primary_Contact__r.Name, 
                   // **CORRECTED**: Get Mailing Address from the Primary Contact
                   Bill_To_Account__r.Primary_Contact__r.MailingStreet,
                   Bill_To_Account__r.Primary_Contact__r.MailingCity,
                   Bill_To_Account__r.Primary_Contact__r.MailingState,
                   Bill_To_Account__r.Primary_Contact__r.MailingPostalCode,
                   Bill_To_Account__r.Primary_Contact__r.MailingCountry,
                   // Data for Self-Pay Person Account
                   Bill_To_Account__r.BillingStreet, Bill_To_Account__r.BillingCity,
                   Bill_To_Account__r.BillingState, Bill_To_Account__r.BillingPostalCode, Bill_To_Account__r.BillingCountry,
                   // Data for "Paid by CP" logic
                   Related_Order__r.Billing_Type__c,
                   Related_Order__r.Account.Coordinating_Program__r.Name,
                   Related_Order__r.Account.Coordinating_Program__r.Primary_Contact__r.Name,
                   Related_Order__r.Account.Coordinating_Program__r.Primary_Contact__r.MailingStreet,
                   Related_Order__r.Account.Coordinating_Program__r.Primary_Contact__r.MailingCity,
                   Related_Order__r.Account.Coordinating_Program__r.Primary_Contact__r.MailingState,
                   Related_Order__r.Account.Coordinating_Program__r.Primary_Contact__r.MailingPostalCode,
                   Related_Order__r.Account.Coordinating_Program__r.Primary_Contact__r.MailingCountry, Term__c
            FROM Invoice__c 
            WHERE Id = :invoiceId 
            LIMIT 1
        ];
        List<Membership_Transaction__c> relatedTransaction = [SELECT Id, TransactionCompletionDate__c,PaymentMethod__c From Membership_Transaction__c Where Invoice__c=: invoiceId Limit 1];
        if(relatedTransaction!=null){
            this.transactionDate = relatedTransaction[0].TransactionCompletionDate__c != null ? relatedTransaction[0].TransactionCompletionDate__c.format() : '';
            this.paymentType = relatedTransaction[0].PaymentMethod__c;
            
        }
        
        

        // --- STEP 2: Guard Clause ---
        if (invoices.isEmpty()) { 
            this.invoice = new Invoice__c();
            this.lineItems = new List<Invoice_Line__c>();
            return; 
        }
        this.invoice = invoices[0];
        this.term =  invoices[0].Term__c;
        
        // --- STEP 3: Core Logic - Prepare the "Issued To" address properties ---
        if (invoice.Related_Order__r.Billing_Type__c == 'Paid by Coordinating Program' && invoice.Related_Order__r.Account.Coordinating_Program__r != null) {
            // SCENARIO 1: The CP is paying. Use the CP's Primary Contact address.
            Account cpAccount = invoice.Related_Order__r.Account.Coordinating_Program__r;
            this.isIssuedToPersonAccount = false;
            this.issuedToName = cpAccount.Name;
            this.issuedToContactName = cpAccount.Primary_Contact__r.Name;
            this.issuedToStreet = cpAccount.Primary_Contact__r.MailingStreet;
            this.issuedToCityStateZip = formatAddressLine(cpAccount.Primary_Contact__r.MailingCity, cpAccount.Primary_Contact__r.MailingState, cpAccount.Primary_Contact__r.MailingPostalCode);
            this.issuedToCountry = cpAccount.Primary_Contact__r.MailingCountry;
        } else {
            // SCENARIO 2: Self-Pay. Use the Bill To Account's own address.
            Account billTo = invoice.Bill_To_Account__r;
            this.isIssuedToPersonAccount = billTo.IsPersonAccount;
            if (this.isIssuedToPersonAccount) {
                // It's a Person Account (uses Billing Address from the Account)
                this.issuedToName = billTo.Name;
                this.issuedToContactName = null;
                this.issuedToStreet = billTo.BillingStreet;
                this.issuedToCityStateZip = formatAddressLine(billTo.BillingCity, billTo.BillingState, billTo.BillingPostalCode);
                this.issuedToCountry = billTo.BillingCountry;
            } else {
                // **CORRECTED**: It's an Organization Account (uses Mailing Address from the Primary Contact)
                this.issuedToName = billTo.Name;
                this.issuedToContactName = billTo.Primary_Contact__r.Name;
                this.issuedToStreet = billTo.Primary_Contact__r.MailingStreet;
                this.issuedToCityStateZip = formatAddressLine(billTo.Primary_Contact__r.MailingCity, billTo.Primary_Contact__r.MailingState, billTo.Primary_Contact__r.MailingPostalCode);
                this.issuedToCountry = billTo.Primary_Contact__r.MailingCountry;
            }
        }

        // --- STEP 4: Fetch Child and Org Data ---
        this.lineItems = [SELECT Id, Product__r.Name, Billed_For_Account__r.Name, Quantity__c, Unit_Price__c, Line_Total__c FROM Invoice_Line__c WHERE Invoice__c = :this.invoice.Id ORDER BY CreatedDate ASC];
        Organization org = [SELECT Name FROM Organization LIMIT 1];
        this.organizationName = org.Name;

        // --- STEP 5: Format Dates ---
        this.invoiceDateFormatted = this.invoice.Invoice_Date__c != null ? this.invoice.Invoice_Date__c.format() : '';
        this.dueDateFormatted = this.invoice.Due_Date__c != null ? this.invoice.Due_Date__c.format() : '';
        
    }

    // Helper method to gracefully format the City, State, Zip line
    private String formatAddressLine(String city, String state, String postalCode) {
        String addressLine = '';
        if (String.isNotBlank(city)) { addressLine += city; }
        if (String.isNotBlank(state)) { addressLine += (String.isNotBlank(addressLine) ? ', ' : '') + state; }
        if (String.isNotBlank(postalCode)) { addressLine += (String.isNotBlank(addressLine) ? ' ' : '') + postalCode; }
        return addressLine;
    }
}