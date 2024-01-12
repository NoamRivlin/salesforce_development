public with sharing class ContactUploaderController {
  public class AccountOption {
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String value;

    public AccountOption(String label, String value) {
      this.label = label;
      this.value = value;
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<AccountOption> getAccountOptions() {
    if (!Schema.sObjectType.Account.isAccessible()) {
      throw new AuraHandledException(
        'You do not have permission to read accounts.'
      );
    }

    List<AccountOption> options = new List<AccountOption>();
    List<Account> accounts = [SELECT Id, Name FROM Account];
    for (Account acc : accounts) {
      options.add(new AccountOption(acc.Name, String.valueOf(acc.Id)));
    }
    System.debug('Account options: ' + options);
    return options;
  }

  @AuraEnabled
  public static String uploadContacts(String fileContent, Id accountId) {
    try {
      System.debug('File content: ' + fileContent);
      List<Contact> contactsToCreate = parseCsv(fileContent, accountId);
      System.debug('Parsed contacts: ' + contactsToCreate);
      upsertContacts(contactsToCreate);
      return 'Success';
    } catch (Exception e) {
      System.debug('Error in uploadContacts: ' + e.getMessage());
      throw new AuraHandledException(e.getMessage());
    }
  }

  private static List<Contact> parseCsv(String fileContent, Id accountId) {
    List<Contact> contacts = new List<Contact>();
    String[] lines = fileContent.replace('\r\n', '\n').split('\n');
    Pattern validPattern = Pattern.compile('^[a-zA-Z,]+$'); // Regex for validation

    for (String line : lines) {
      Matcher matcher = validPattern.matcher(line);
      if (!matcher.matches() || String.isBlank(line.trim())) {
        // Corrected isEmpty() to isBlank()
        throw new AuraHandledException('Invalid CSV line: ' + line);
      }

      String[] fields = line.split(',');
      if (fields.size() >= 2) {
        Contact contact = new Contact(
          FirstName = fields[0].trim(),
          LastName = fields[1].trim(),
          AccountId = accountId
        );
        contacts.add(contact);
      }
    }
    return contacts;
  }

  private static void upsertContacts(List<Contact> contacts) {
    if (
      !Schema.sObjectType.Contact.isCreateable() ||
      !Schema.sObjectType.Contact.isUpdateable()
    ) {
      throw new AuraHandledException(
        'You do not have permission to create or update contacts.'
      );
    }

    // Create a map to hold unique contact keys and their corresponding contacts
    Map<String, Contact> contactMap = new Map<String, Contact>();
    for (Contact contact : contacts) {
      String contactKey =
        contact.FirstName +
        ':' +
        contact.LastName +
        ':' +
        contact.AccountId;
      contactMap.put(contactKey, contact);
    }
    System.debug('Contact map: ' + contactMap);

    // Query existing contacts
    List<Contact> existingContacts = [
      SELECT Id, FirstName, LastName, AccountId
      FROM Contact
    ];
    System.debug('Existing contacts: ' + existingContacts);

    // Create a map to hold existing contact keys and their corresponding IDs
    Map<String, Id> existingContactIdMap = new Map<String, Id>();
    for (Contact existingContact : existingContacts) {
      String contactKey =
        existingContact.FirstName +
        ':' +
        existingContact.LastName +
        ':' +
        existingContact.AccountId;
      existingContactIdMap.put(contactKey, existingContact.Id);
    }
    System.debug('Existing contact ID map: ' + existingContactIdMap);

    // Prepare the contacts for upsert operation
    List<Contact> contactsToUpsert = new List<Contact>();
    for (Contact contact : contacts) {
      String contactKey =
        contact.FirstName +
        ':' +
        contact.LastName +
        ':' +
        contact.AccountId;
      if (existingContactIdMap.containsKey(contactKey)) {
        contact.Id = existingContactIdMap.get(contactKey); // Set ID for update
      }
      contactsToUpsert.add(contact);
    }
    System.debug('Contacts to upsert: ' + contactsToUpsert);

    // Perform the upsert operation
    upsert contactsToUpsert;
  }
}

// public with sharing class ContactUploaderController {
//   // Define a result class to hold parseCsv results
//   public class ParseCsvResult {
//     @AuraEnabled
//     public List<Contact> validContacts;
//     @AuraEnabled
//     public List<String> errors;
//   }

//   @AuraEnabled(cacheable=true)
//   public static List<AccountOption> getAccountOptions() {
//     // Check accessibility of the Account object
//     if (!Schema.sObjectType.Account.isAccessible()) {
//       throw new AuraHandledException(
//         'You do not have permission to read accounts.'
//       );
//     }

//     // Retrieve and map Account records to options
//     List<AccountOption> options = new List<AccountOption>();
//     for (Account acc : [SELECT Id, Name FROM Account]) {
//       options.add(new AccountOption(acc.Name, String.valueOf(acc.Id)));
//     }
//     System.debug('Account options: ' + options);
//     return options;
//   }

//   @AuraEnabled
//   public static String uploadContacts(String fileContent, Id accountId) {
//     try {
//       // Parse the CSV file content
//       ParseCsvResult parseResult = parseCsv(fileContent, accountId);

//       // Check for parsing errors
//       if (!parseResult.errors.isEmpty()) {
//         String errorMessage = String.join('\n', parseResult.errors);
//         return errorMessage;
//       }

//       // Upsert valid contacts
//       upsertContacts(parseResult.validContacts);
//       return 'Success';
//     } catch (Exception e) {
//       System.debug('Error in uploadContacts: ' + e.getMessage());
//       throw new AuraHandledException(e.getMessage());
//     }
//   }

//   private static ParseCsvResult parseCsv(String fileContent, Id accountId) {
//     ParseCsvResult result = new ParseCsvResult();
//     result.validContacts = new List<Contact>();
//     result.errors = new List<String>();

//     String[] lines = fileContent.replace('\r\n', '\n').split('\n');
//     Pattern validPattern = Pattern.compile('^[a-zA-Z,]+$'); // Regex for validation

//     for (String line : lines) {
//       Matcher matcher = validPattern.matcher(line);
//       if (!matcher.matches() || String.isBlank(line.trim())) {
//         // Add the error message to the result object
//         result.errors.add('Invalid CSV line: ' + line);
//       } else {
//         String[] fields = line.split(',');
//         if (fields.size() >= 2) {
//           Contact contact = new Contact(
//             FirstName = fields[0].trim(),
//             LastName = fields[1].trim(),
//             AccountId = accountId
//           );
//           result.validContacts.add(contact);
//         }
//       }
//     }

//     return result;
//   }

//   private static void upsertContacts(List<Contact> contacts) {
//     if (
//       !Schema.sObjectType.Contact.isCreateable() ||
//       !Schema.sObjectType.Contact.isUpdateable()
//     ) {
//       throw new AuraHandledException(
//         'You do not have permission to create or update contacts.'
//       );
//     }

//     // Create a map to hold unique contact keys and their corresponding contacts
//     Map<String, Contact> contactMap = new Map<String, Contact>();
//     for (Contact contact : contacts) {
//       String contactKey =
//         contact.FirstName +
//         ':' +
//         contact.LastName +
//         ':' +
//         contact.AccountId;
//       contactMap.put(contactKey, contact);
//     }
//     System.debug('Contact map: ' + contactMap);

//     // Query existing contacts
//     List<Contact> existingContacts = [
//       SELECT Id, FirstName, LastName, AccountId
//       FROM Contact
//     ];
//     System.debug('Existing contacts: ' + existingContacts);

//     // Create a map to hold existing contact keys and their corresponding IDs
//     Map<String, Id> existingContactIdMap = new Map<String, Id>();
//     for (Contact existingContact : existingContacts) {
//       String contactKey =
//         existingContact.FirstName +
//         ':' +
//         existingContact.LastName +
//         ':' +
//         existingContact.AccountId;
//       existingContactIdMap.put(contactKey, existingContact.Id);
//     }
//     System.debug('Existing contact ID map: ' + existingContactIdMap);

//     // Prepare the contacts for upsert operation
//     List<Contact> contactsToUpsert = new List<Contact>();
//     for (Contact contact : contacts) {
//       String contactKey =
//         contact.FirstName +
//         ':' +
//         contact.LastName +
//         ':' +
//         contact.AccountId;
//       if (existingContactIdMap.containsKey(contactKey)) {
//         contact.Id = existingContactIdMap.get(contactKey); // Set ID for update
//       }
//       contactsToUpsert.add(contact);
//     }
//     System.debug('Contacts to upsert: ' + contactsToUpsert);

//     // Perform the upsert operation
//     upsert contactsToUpsert;
//   }
// }

