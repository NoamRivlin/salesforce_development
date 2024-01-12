import { LightningElement, wire, track } from "lwc";
import uploadContacts from "@salesforce/apex/ContactUploaderController.uploadContacts";
import getAccountOptions from "@salesforce/apex/ContactUploaderController.getAccountOptions";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import Longitude from "@salesforce/schema/Asset.Longitude";

export default class ContactUploader extends LightningElement {
  @track file;
  @track accountId;
  @track accountOptions = [];
  @track errorMessage;

  @wire(getAccountOptions)
  handleAccountData({ error, data }) {
    if (data) {
      this.accountOptions = data;
    } else if (error) {
      this.handleErrorResponse(error);
    }
  }

  handleFileChange(event) {
    const file = event.target.files[0];
    if (file) {
      this.readFileContent(file);
    }
  }

  async readFileContent(file) {
    const fileContent = await this.readFileAsText(file);
    if (this.isValidCsv(fileContent)) {
      this.file = fileContent;
    } else {
      this.showToast("Invalid File", this.errorMessage, "error");
    }
  }

  async readFileAsText(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result);
      reader.onerror = (error) => reject(error);
      reader.readAsText(file);
    }).catch((error) => {
      console.log(`error: ${JSON.stringify(error)}`);
      this.errorMessage = `Error reading file: ${error.body.message}`;
      this.showToast("Error reading file", this.errorMessage, "error");
    });
  }

  isValidCsv(content) {
    const lines = content.split(/\r\n|\n/);
    const regex = /^[a-zA-Z -]+$/; // Adjusted regex to disallow numbers and special characters
    for (let i = 1; i < lines.length; i++) {
      // Start from 1 to skip header
      const fields = lines[i].split(",");
      if (
        fields.length !== 2 ||
        !fields[0].match(regex) ||
        !fields[1].match(regex)
      ) {
        this.errorMessage = `Invalid or missing data in line ${i + 1}`;
        return false;
      }
    }
    return true;
  }

  handleAccountChange(event) {
    console.log("accountId: " + event.detail.value);
    this.accountId = event.detail.value;
  }

  handleUploadContacts() {
    if (this.file && this.accountId) {
      this.uploadContactsToServer();
    } else {
      this.errorMessage =
        "Please select a file and an account before uploading.";
      this.showToast(
        "Missing Information",
        "Please select a file and an account before uploading.",
        "warning"
      );
    }
  }

  async uploadContactsToServer() {
    try {
      const result = await uploadContacts({
        fileContent: this.file,
        accountId: this.accountId
      });
      this.showToast("Success", "Contacts uploaded successfully", "success");
    } catch (error) {
      console.log(`error: ${error}`);
      let message = "Error uploading contacts";
      if (error && error.body && error.body.message) {
        message = error.body.message;
      }
      this.showToast("Error uploading contacts", message, "error");
    }
  }

  handleErrorResponse(error) {
    console.log(`error: ${JSON.stringify(error)}`);
    this.errorMessage = `Error retrieving account options: ${error.body.message}`;
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title: title,
        message: message,
        variant: variant
      })
    );
  }
}
