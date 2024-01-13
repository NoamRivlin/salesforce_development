trigger ContactTrigger on Contact(after insert, after update) {
  ContactTriggerHandler.handleAfterInsertAndUpdate(
    new List<Id>((new Map<Id, Contact>(Trigger.new)).keySet())
  );
}
