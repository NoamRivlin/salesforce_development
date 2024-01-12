public with sharing class ContactUpdater {
  private static final String ENDPOINT_URL = 'https://clb-candidates-data-5d5991b93b50.herokuapp.com/getContacts';

  @AuraEnabled
  public static void updateContacts(List<Contact> contacts) {
    for (Contact contact : contacts) {
      // Prepare the JSON payload
      String jsonBody = JSON.serialize(
        new Map<String, String>{
          'FirstName' => contact.FirstName,
          'LastName' => contact.LastName
        }
      );

      // Make the API request
      Http http = new Http();
      HttpRequest request = new HttpRequest();
      request.setEndpoint(ENDPOINT_URL);
      request.setMethod('POST');
      request.setHeader('Content-Type', 'application/json');
      request.setBody(jsonBody);

      try {
        HttpResponse response = http.send(request);
        if (response.getStatusCode() == 200) {
          // Process the response
          Map<String, Object> responseData = (Map<String, Object>) JSON.deserializeUntyped(
            response.getBody()
          );
          Map<String, Object> candidateData = (Map<String, Object>) responseData.get(
            'candidate'
          );
          if (candidateData != null) {
            updateContactRecord(contact, candidateData);
          } else {
            // Candidate not found in the response
            System.debug(
              'Candidate not found for ' +
                contact.FirstName +
                ' ' +
                contact.LastName
            );
          }
        } else {
          // Non-200 responses
          System.debug(
            'Non-200 response from API: ' +
              response.getStatusCode() +
              ' ' +
              response.getBody()
          );
        }
      } catch (Exception e) {
        System.debug('Error during API call: ' + e.getMessage());
      }
    }
  }

  private static void updateContactRecord(
    Contact contact,
    Map<String, Object> candidateData
  ) {
    // Before updating, ensure the fields are updateable as per FLS
    if (
      Schema.sObjectType.Contact.fields.Email.isUpdateable() &&
      Schema.sObjectType.Contact.fields.MobilePhone.isUpdateable() &&
      Schema.sObjectType.Contact.fields.Birthdate.isUpdateable() &&
      Schema.sObjectType.Contact.fields.Description.isUpdateable()
    ) {
      contact.Email = (String) candidateData.get('Email');
      contact.MobilePhone = (String) candidateData.get('Mobile');
      contact.Birthdate = Date.valueOf((String) candidateData.get('Birthdate'));
      contact.Description = (String) candidateData.get('Description');

      update contact;
    } else {
      // Handle the scenario where the user doesn't have field-level update permissions
      System.debug('Insufficient field-level permissions to update contact');
    }
  }
}
