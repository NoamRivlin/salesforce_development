import { LightningElement, wire, track } from "lwc";
import uploadContacts from "@salesforce/apex/ContactUploaderController.uploadContacts";
import getAccountOptions from "@salesforce/apex/ContactUploaderController.getAccountOptions";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class ContactUploader extends LightningElement {
  @track file;
  @track accountId;
  @track accountOptions = [];
  @track errorMessage;
  @track isUploadButtonDisabled = true;

  permissionedAccountsList = ["Onboarding Manager"];

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
    try {
      let fileContent = await this.readFileAsText(file);
      let cleanedContent = this.removeDuplicateContacts(fileContent);
      if (cleanedContent) {
        this.file = cleanedContent;
      } else {
        this.showToast(
          "Invalid File",
          "The file contains invalid data or format.",
          "error"
        );
      }
    } catch (error) {
      this.errorMessage = `Error reading file: ${error.message}`;
      this.showToast("Error reading file", this.errorMessage, "error");
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

  removeDuplicateContacts(content) {
    const lines = content.split(/\r\n|\n/);
    const regex = /^[a-zA-Z -]+$/; // Regex to allow letters, spaces, and dashes
    const uniqueContacts = new Set();
    let cleanedLines = [];

    for (let i = 0; i < lines.length; i++) {
      if (i === 0 || lines[i].trim() === "") {
        // Preserve header and skip empty lines
        cleanedLines.push(lines[i]);
        continue;
      }

      const fields = lines[i].split(",");
      if (
        fields.length !== 2 ||
        !fields[0].match(regex) ||
        !fields[1].match(regex)
      ) {
        // Skip invalid lines
        continue;
      }

      const contactKey = `${fields[0].trim().toLowerCase()} ${fields[1]
        .trim()
        .toLowerCase()}`;
      if (!uniqueContacts.has(contactKey)) {
        uniqueContacts.add(contactKey);
        cleanedLines.push(lines[i]);
      }
    }

    return cleanedLines.length > 1 ? cleanedLines.join("\n") : null;
  }

  handleAccountChange(event) {
    const selectedAccountId = event.detail.value;
    const selectedAccount = this.accountOptions.find(
      (account) => account.value === selectedAccountId
    );

    if (
      !selectedAccount ||
      !this.permissionedAccountsList.includes(selectedAccount.label)
    ) {
      // Account does not have permission, show toast and keep upload button disabled
      this.showToast(
        "Permission Denied",
        "You do not have permission to upload to this account.",
        "error"
      );
      this.isUploadButtonDisabled = true;
      this.accountId = null; // Ensure accountId is not set to an unauthorized account
      return;
    }
    // Account has permission, set accountId and enable upload button
    this.accountId = selectedAccountId;
    this.isUploadButtonDisabled = false;
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
      this.showToast(
        "Success",
        `Contacts uploaded successfully, 
        proceeding to get further information via cellebrite API.
        This may take a while.`,
        "success"
      );
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
