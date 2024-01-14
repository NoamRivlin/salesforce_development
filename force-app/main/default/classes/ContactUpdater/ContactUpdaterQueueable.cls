public class ContactUpdaterQueueable implements Queueable, Database.AllowsCallouts {
  private List<Id> contactIds;
  private static final Integer API_CALLOUT_LIMIT =
    Limits.getLimitCallouts() - Limits.getCallouts();

  public ContactUpdaterQueueable(List<Id> contactIds) {
    this.contactIds = contactIds;
  }

  public void execute(QueueableContext context) {
    // Prevent the trigger from processing these updates
    TriggerContext.shouldProcess = false;

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
        System.debug('Callout limit reached: ' + calloutsMade);
        break; // Stop processing if we've reached the API callout limit
      }

      Map<String, Object> apiResponse = getContactDataFromAPI(contact);
      System.debug('API Response: ' + apiResponse);
      // if (isValidApiResponse(apiResponse)) {
      updateContactFields(contact, apiResponse);
      contactsToUpdate.add(contact);
      calloutsMade++;
      // }
      // else {
      //   logApiResponseErrors(contact, apiResponse);
      // }
    }
    return contactsToUpdate;
  }

  private Boolean isValidApiResponse(Map<String, Object> apiResponse) {
    return apiResponse != null && apiResponse.containsKey('candidate');
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
        update contactsToUpdate; // Perform the update
      } catch (DmlException e) {
        System.debug('Error updating contacts: ' + e.getMessage());
      }
    }
  }

  private void updateContactFields(
    Contact contact,
    Map<String, Object> apiResponse
  ) {
    // Check if the 'candidate' key exists and is a map
    if (apiResponse != null) {
      Map<String, Object> candidateData = (Map<String, Object>) apiResponse;
      contact.Email = (String) candidateData.get('Email');
      contact.MobilePhone = (String) candidateData.get('Mobile');
      contact.Birthdate = (candidateData.get('Birthdate') != null)
        ? Date.valueOf((String) candidateData.get('Birthdate'))
        : null;
      contact.Description = (String) candidateData.get('Description');
    } else {
      // Handle the case where 'candidate' is not in the expected format
      System.debug(
        'The candidate data is not in the expected format or is missing: ' +
        apiResponse
      );
    }
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
        // System.debug('responseMap line 131: ' + responseMap.get('candidate'));
        if (responseMap.containsKey('candidate')) {
          return (Map<String, Object>) responseMap.get('candidate');
        } else {
          System.debug(
            'No candidate data found in API response for contact ' +
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
