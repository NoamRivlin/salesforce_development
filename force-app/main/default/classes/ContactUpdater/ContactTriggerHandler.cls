public class ContactTriggerHandler {
  public static void handleAfterInsertAndUpdate(List<Id> contactIds) {
    System.enqueueJob(new ContactUpdaterQueueable(contactIds));
  }
}
