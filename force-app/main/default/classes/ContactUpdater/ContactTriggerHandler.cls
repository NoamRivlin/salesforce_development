public class ContactTriggerHandler {
  public static void handleAfterInsertAndUpdate(List<Id> contactIds) {
    // Check if the trigger should process
    if (!TriggerContext.shouldProcess) {
      return;
    }
    System.enqueueJob(new ContactUpdaterQueueable(contactIds));
  }
}
