@isTest
private class ContactUploaderControllerTest {
  @isTest
  static void testGetAccountOptions() {
    // Set up test data
    Account testAccount = new Account(Name = 'Test Account');
    insert testAccount;

    Test.startTest();
    List<ContactUploaderController.AccountOption> options = ContactUploaderController.getAccountOptions();
    Test.stopTest();

    // Assert the results
    System.assert(options.size() > 0, 'Account options should be returned');
  }

  @isTest
  static void testUploadContactsSuccess() {
    // Create test account and contact data
    Account testAccount = new Account(Name = 'Test Account');
    insert testAccount;

    String fileContent = 'John,Doe\nJane,Doe'; // Adjusted to match expected CSV format
    Id accountId = testAccount.Id;

    Test.startTest();
    String result = ContactUploaderController.uploadContacts(
      fileContent,
      accountId
    );
    Test.stopTest();

    // Assert the results
    System.assertEquals('Success', result, 'The method should return success.');
    List<Contact> contacts = [
      SELECT FirstName, LastName
      FROM Contact
      WHERE AccountId = :accountId
    ];
    System.assertEquals(
      2,
      contacts.size(),
      'Two contacts should be created/updated.'
    );
  }

  @isTest
  static void testUploadContactsWithInvalidData() {
    Account testAccount = new Account(Name = 'Test Account');
    insert testAccount;

    String invalidFileContent = 'Invalid,Data\n,MissingFirstName'; // Example of invalid data
    Id accountId = testAccount.Id;

    Boolean exceptionThrown = false;

    Test.startTest();
    try {
      ContactUploaderController.uploadContacts(invalidFileContent, accountId);
    } catch (AuraHandledException e) {
      exceptionThrown = true;
    }
    Test.stopTest();

    System.assert(
      exceptionThrown,
      'An exception should have been thrown for invalid data'
    );
  }
}
