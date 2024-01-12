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

    String fileContent = 'John,Doe,john.doe@example.com\nJane,Doe,jane.doe@example.com';
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
      SELECT FirstName, LastName, Email
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

    String invalidFileContent = 'Invalid,Data,Without@Email.com';
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

  // @isTest
  // static void testUploadContactsInsufficientPrivileges() {
  //   // Simulate insufficient privileges
  //   // This can be done using a runAs block with a user that lacks create/update permissions on Contact
  //   // Ensure that you have such a user set up in your org for this test

  //   User limitedPermissionUser = [
  //     SELECT Id
  //     FROM User
  //     WHERE Username = 'limited@example.com'
  //     LIMIT 1
  //   ];
  //   System.runAs(limitedPermissionUser) {
  //     String fileContent = 'John,Doe,john.doe@example.com';
  //     Id accountId = 'dummyAccountId'; // Use a dummy ID for simplicity

  //     Test.startTest();
  //     try {
  //       ContactUploaderController.uploadContacts(fileContent, accountId);
  //       System.assert(false, 'Exception should have been thrown');
  //     } catch (AuraHandledException e) {
  //       // Assert the expected exception message
  //       System.assertEquals(
  //         'You do not have permission to create or update contacts.',
  //         e.getMessage(),
  //         'Incorrect exception message'
  //       );
  //     }
  //     Test.stopTest();
  //   }
  // }
}
