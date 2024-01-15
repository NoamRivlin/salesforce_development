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
    } catch (DmlException e) {
      System.debug('DML error: ' + e.getMessage());
      throw new AuraHandledException('DML error: ' + e.getMessage());
    } catch (Exception e) {
      System.debug('General error: ' + e.getMessage());
      throw new AuraHandledException('General error: ' + e.getMessage());
    }
  }

  private static List<Contact> parseCsv(String fileContent, Id accountId) {
    List<Contact> contacts = new List<Contact>();
    String[] lines = fileContent.replace('\r\n', '\n').split('\n');
    Pattern validPattern = Pattern.compile('^[a-zA-Z -]+$'); // Regex to allow letters and spaces

    for (Integer i = 1; i < lines.size(); i++) {
      String line = lines[i];
      if (String.isBlank(line)) {
        throw new AuraHandledException('Empty line at: ' + (i + 1));
      }

      String[] fields = line.split(',');
      if (fields.size() != 2) {
        throw new AuraHandledException(
          'Incorrect number of fields in line: ' + (i + 1)
        );
      }

      String firstName = fields[0].trim();
      String lastName = fields[1].trim();

      if (
        !validPattern.matcher(firstName).matches() ||
        !validPattern.matcher(lastName).matches()
      ) {
        throw new AuraHandledException('Invalid data in line: ' + (i + 1));
      }

      contacts.add(
        new Contact(
          FirstName = firstName,
          LastName = lastName,
          AccountId = accountId
        )
      );
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
