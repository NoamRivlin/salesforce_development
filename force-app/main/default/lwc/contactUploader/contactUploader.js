// import { LightningElement, wire, track } from "lwc";
// import uploadContacts from "@salesforce/apex/ContactUploaderController.uploadContacts";
// import getAccountOptions from "@salesforce/apex/ContactUploaderController.getAccountOptions";
// import { ShowToastEvent } from "lightning/platformShowToastEvent";

// export default class ContactUploader extends LightningElement {
//   @track file;
//   @track accountId;
//   @track accountOptions = [];
//   @track errorMessage; // To track error messages

//   @wire(getAccountOptions)
//   wiredAccounts({ error, data }) {
//     if (data) {
//       this.accountOptions = data;
//     } else if (error) {
//       console.log("error: " + JSON.stringify(error));
//       this.errorMessage =
//         "Error retrieving account options: " + error.body.message;
//     }
//   }

//   handleFileChange(event) {
//     const file = event.target.files[0];
//     if (file) {
//       let reader = new FileReader();
//       reader.onload = () => {
//         const fileContent = reader.result;
//         if (this.isValidCsv(fileContent)) {
//           this.file = fileContent;
//         } else {
//           this.dispatchEvent(
//             new ShowToastEvent({
//               title: "Invalid File",
//               message: "The CSV file contains invalid data.",
//               variant: "error"
//             })
//           );
//         }
//       };
//       reader.onerror = (error) => {
//         console.error("File reading error: ", error);
//       };
//       reader.readAsText(file); // Read the file as text
//     }
//   }

//   isValidCsv(content) {
//     const lines = content.split(/\r\n|\n/);
//     const regex = /^[a-zA-Z,]+$/; // Regex to allow only letters and commas
//     return lines.every((line) => regex.test(line) && line.trim() !== "");
//   }

//   handleAccountChange(event) {
//     console.log("accountId: " + event.detail.value);
//     this.accountId = event.detail.value;
//   }

//   async handleUploadContacts() {
//     console.log("file: " + JSON.stringify(this.file));
//     if (this.file && this.accountId) {
//       uploadContacts({ fileContent: this.file, accountId: this.accountId })
//         .then((result) => {
//           console.log("result: " + result);
//           this.dispatchEvent(
//             new ShowToastEvent({
//               title: "Success",
//               message: "Contacts uploaded successfully",
//               variant: "success"
//             })
//           );
//         })
//         .catch((error) => {
//           console.log("error: " + error);
//           let message = "Error uploading contacts";
//           if (error && error.body && error.body.message) {
//             message = error.body.message;
//           }
//           this.dispatchEvent(
//             new ShowToastEvent({
//               title: "Error uploading contacts",
//               message: message,
//               variant: "error"
//             })
//           );
//         });
//     } else {
//       this.errorMessage =
//         "Please select a file and an account before uploading.";
//       this.dispatchEvent(
//         new ShowToastEvent({
//           title: "Missing Information",
//           message: "Please select a file and an account before uploading.",
//           variant: "warning"
//         })
//       );
//     }
//   }
// }

import { LightningElement, wire, track } from "lwc";
import uploadContacts from "@salesforce/apex/ContactUploaderController.uploadContacts";
import getAccountOptions from "@salesforce/apex/ContactUploaderController.getAccountOptions";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

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
      this.showToast(
        "Invalid File",
        "The CSV file contains invalid data.",
        "error"
      );
    }
  }

  async readFileAsText(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result);
      reader.onerror = (error) => reject(error);
      reader.readAsText(file);
    });
  }

  isValidCsv(content) {
    const lines = content.split(/\r\n|\n/);
    const regex = /^[a-zA-Z,]+$/;
    return lines.every((line) => regex.test(line) && line.trim() !== "");
  }

  handleAccountChange(event) {
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
