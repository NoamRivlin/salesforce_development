public class ContactUpdaterQueueable implements Queueable, Database.AllowsCallouts {
  private List<Id> contactIds;
  private static final Integer API_CALLOUT_LIMIT =
    Limits.getLimitCallouts() - Limits.getCallouts();
  private static final String API_ENDPOINT = 'https://clb-candidates-data-5d5991b93b50.herokuapp.com/getContacts';

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
        continue;
      }
      updateMissingCandidateInAPI(contact);
      calloutsMade++;
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
    Map<String, Object> candidate
  ) {
    String email = (String) candidate.get('Email');
    String mobile = (String) candidate.get('Mobile');
    String birthdate = (String) candidate.get('Birthdate');
    String description = (String) candidate.get('Description');

    if (shouldUpdateField(contact.Email, email)) {
      contact.Email = email;
    }
    if (shouldUpdateField(contact.MobilePhone, mobile)) {
      contact.MobilePhone = mobile;
    }
    if (shouldUpdateField(contact.Birthdate, birthdate)) {
      contact.Birthdate = (birthdate != null) ? Date.valueOf(birthdate) : null;
    }
    if (shouldUpdateField(contact.Description, description)) {
      contact.Description = description;
    }
  }

  private void updateMissingCandidateInAPI(Contact contact) {
    String description = (String) contact.get('Description');
    if (
      description == null || !description.contains('Candidate not found in API')
    ) {
      description = (description == null) ? '' : description;
      contact.Description = description + ' (Candidate not found in API)';
      update contact;
    }
  }

  private Map<String, Object> getContactDataFromAPI(Contact contact) {
    Http http = new Http();
    HttpRequest request = new HttpRequest();
    request.setEndpoint(API_ENDPOINT);
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
          Map<String, Object> candidate = (Map<String, Object>) responseMap.get(
            'candidate'
          );
          if (candidate != null && !candidate.isEmpty()) {
            return candidate;
          }
          updateMissingCandidateInAPI(contact);
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

  private boolean shouldUpdateField(Object currentValue, Object newValue) {
    if (newValue == null || String.isBlank(newValue.toString())) {
      return false;
    }
    if (currentValue == null || String.isBlank(currentValue.toString())) {
      return true;
    }
    return !currentValue.equals(newValue);
  }

  private String formatContactDetails(Contact contact) {
    return contact.Id + ' ' + contact.FirstName + ' ' + contact.LastName;
  }
}

/*
for the updating of fields, its not 
clear cut which is more important - the data from the API or the data in Salesforce.
my code checks if in salesforce the field is null or blank, if it is, then it will update it with the data from the API.
and if the field is null or blank in the API, then it will not update the field in salesforce. 

*/

