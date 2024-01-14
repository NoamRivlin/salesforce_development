trigger ContactTrigger on Contact(after insert, after update) {
  // Only process if the flag allows it
  if (TriggerContext.shouldProcess) {
    List<Id> contactIds = new List<Id>(
      (new Map<Id, Contact>(Trigger.new)).keySet()
    );
    ContactTriggerHandler.handleAfterInsertAndUpdate(contactIds);
  }
}
