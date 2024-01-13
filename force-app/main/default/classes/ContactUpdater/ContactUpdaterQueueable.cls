public class ContactUpdaterQueueable implements Queueable, Database.AllowsCallouts {
  private List<Id> contactIds;
  private static final Integer API_CALLOUT_LIMIT =
    Limits.getLimitCallouts() - Limits.getCallouts();

  public ContactUpdaterQueueable(List<Id> contactIds) {
    this.contactIds = contactIds;
  }

  public void execute(QueueableContext context) {
    List<Contact> contactsToProcess = [
      SELECT Id, FirstName, LastName, Email, MobilePhone, Birthdate, Description
      FROM Contact
      WHERE Id IN :contactIds
    ];
    if (contactsToProcess.isEmpty()) {
      return; // Exit if there are no contacts to process
    }

    List<Contact> contactsToUpdate = processContacts(contactsToProcess);
    updateContactsIfAny(contactsToUpdate);
  }

  private List<Contact> processContacts(List<Contact> contacts) {
    List<Contact> contactsToUpdate = new List<Contact>();
    Integer calloutsMade = 0;

    for (Contact contact : contacts) {
      if (calloutsMade >= API_CALLOUT_LIMIT) {
        System.debug(
          'callout reached, ' +
            calloutsMade +
            ' calls out of ' +
            API_CALLOUT_LIMIT
        );
        break; // Stop processing if we've reached the API callout limit
      }
      Map<String, Object> apiResponse = getContactDataFromAPI(contact);
      System.debug('apiResponse: ' + apiResponse);
      if (isValidApiResponse(apiResponse)) {
        updateContactFields(contact, apiResponse);
        contactsToUpdate.add(contact);
        calloutsMade++;
      } else {
        logApiResponseErrors(contact, apiResponse);
      }
    }
    System.debug('contactsToProcess: ' + contacts);
    return contactsToUpdate;
  }

  private Boolean isValidApiResponse(Map<String, Object> apiResponse) {
    return apiResponse != null;
  }

  private void logApiResponseErrors(
    Contact contact,
    Map<String, Object> apiResponse
  ) {
    String contactDetails = formatContactDetails(contact);
    if (apiResponse == null) {
      System.debug('No API response received for contact ' + contactDetails);
    } else if (!apiResponse.containsKey('candidate')) {
      System.debug(
        'No candidate data found in API response for contact ' + contactDetails
      );
    }
  }

  private String formatContactDetails(Contact contact) {
    return contact.Id + ' ' + contact.FirstName + ' ' + contact.LastName;
  }

  private void updateContactsIfAny(List<Contact> contactsToUpdate) {
    if (!contactsToUpdate.isEmpty()) {
      try {
        System.debug('contactsToUpdate: ' + contactsToUpdate);
        update contactsToUpdate;
      } catch (DmlException e) {
        System.debug('Error updating contacts: ' + e.getMessage());
      }
    }
  }

  private void updateContactFields(
    Contact contact,
    Map<String, Object> apiResponse
  ) {
    System.debug('apiResponse: ' + apiResponse);
    System.debug('email: ' + apiResponse.get('Email'));

    contact.Email = (String) apiResponse.get('Email');
    contact.MobilePhone = (String) apiResponse.get('Mobile');
    contact.Birthdate = (apiResponse.get('Birthdate') != null)
      ? Date.valueOf((String) apiResponse.get('Birthdate'))
      : null;
    contact.Description = (String) apiResponse.get('Description');
    System.debug('contact: ' + contact);
  }

  private Map<String, Object> getContactDataFromAPI(Contact contact) {
    Http http = new Http();
    HttpRequest request = new HttpRequest();
    request.setEndpoint(
      'https://clb-candidates-data-5d5991b93b50.herokuapp.com/getContacts'
    );
    request.setMethod('POST');
    request.setHeader('Content-Type', 'application/json');

    JSONGenerator gen = JSON.createGenerator(true);
    gen.writeStartObject();
    gen.writeStringField('FirstName', contact.FirstName);
    gen.writeStringField('LastName', contact.LastName);
    gen.writeEndObject();
    request.setBody(gen.getAsString());

    try {
      HttpResponse response = http.send(request);
      if (response.getStatusCode() == 200) {
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(
          response.getBody()
        );
        if (responseMap.containsKey('candidate')) {
          System.debug('responseMap: ' + responseMap.get('candidate'));
          return (Map<String, Object>) responseMap.get('candidate');
        } else {
          System.debug(
            'Candidate data not found in response for contact ' +
            formatContactDetails(contact)
          );
        }
      } else {
        System.debug(
          'Non-200 response for contact ' +
            formatContactDetails(contact) +
            ': ' +
            response.getBody()
        );
      }
    } catch (Exception e) {
      System.debug(
        'Exception during API callout for contact ' +
          formatContactDetails(contact) +
          ': ' +
          e.getMessage()
      );
    }
    return null;
  }
}
