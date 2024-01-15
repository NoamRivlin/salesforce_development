public class ContactUpdaterQueueable implements Queueable, Database.AllowsCallouts {
  private List<Id> contactIds;
  private static final Integer API_CALLOUT_LIMIT =
    Limits.getLimitCallouts() - Limits.getCallouts();

  public ContactUpdaterQueueable(List<Id> contactIds) {
    this.contactIds = contactIds;
  }

  public void execute(QueueableContext context) {
    TriggerContext.shouldProcess = false; // Prevent the trigger from reprocessing

    List<Contact> contactsToProcess = [
      SELECT Id, FirstName, LastName, Email, MobilePhone, Birthdate, Description
      FROM Contact
      WHERE Id IN :contactIds
    ];

    if (!contactsToProcess.isEmpty()) {
      processAndUpdateContacts(contactsToProcess);
    }
  }

  private void processAndUpdateContacts(List<Contact> contacts) {
    List<Contact> contactsToUpdate = new List<Contact>();
    Integer calloutsMade = 0;

    for (Contact contact : contacts) {
      if (calloutsMade >= API_CALLOUT_LIMIT) {
        System.debug('Callout limit reached: ' + calloutsMade);
        break;
      }

      Map<String, Object> apiResponse = getContactDataFromAPI(contact);
      if (apiResponse != null) {
        updateContactFields(contact, apiResponse);
        contactsToUpdate.add(contact);
        calloutsMade++;
      } else {
        System.debug(
          'No valid API response for contact ' + formatContactDetails(contact)
        );
      }
    }

    if (!contactsToUpdate.isEmpty()) {
      updateContacts(contactsToUpdate);
    }
  }

  private void updateContacts(List<Contact> contactsToUpdate) {
    try {
      update contactsToUpdate;
    } catch (DmlException e) {
      System.debug('Error updating contacts: ' + e.getMessage());
    }
  }

  private void updateContactFields(
    Contact contact,
    Map<String, Object> apiResponse
  ) {
    contact.Email = (String) apiResponse.get('Email');
    contact.MobilePhone = (String) apiResponse.get('Mobile');
    contact.Birthdate = (apiResponse.get('Birthdate') != null)
      ? Date.valueOf((String) apiResponse.get('Birthdate'))
      : null;
    contact.Description = (String) apiResponse.get('Description');
  }

  private String formatContactDetails(Contact contact) {
    return contact.Id + ' ' + contact.FirstName + ' ' + contact.LastName;
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
          return (Map<String, Object>) responseMap.get('candidate');
        } else {
          System.debug(
            'Candidate data not found in API response for contact ' +
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
