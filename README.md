# Salesforce Contact Management System

This repository contains the Salesforce development project for managing contact information. It includes a Lightning Web Component (LWC) for bulk uploading contacts via CSV and an Apex class for integrating with an external API to update contact information.

## Features

### ContactUploader LWC
- Allows users to upload a CSV file with contact details.
- User-friendly interface to select the target Account ("Onboarding Manager").
- Button to trigger the CSV upload and contact creation process.
- Error handling for invalid CSV files or upload failures.
- Apex backend processing to parse the CSV and create contacts efficiently.

### ContactUpdater Apex Class
- Integrates with the Cellebrite API to update contact information.
- Handles a list of contacts, making individual requests to the API.
- Efficiently updates multiple contacts.
- Manages scenarios where a candidate is not found in the API response.

## Installation

1. Clone this repository to your local machine or Salesforce environment.
2. Deploy the components to your Salesforce org (ensure you have the necessary permissions and access).
3. Configure the necessary settings (like the "Onboarding Manager" Account) in your Salesforce org.

## Usage

### ContactUploader Component
- Navigate to the component in your Salesforce org.
- Select the "Onboarding Manager" Account.
- Upload the CSV file with contact details.
- Click the upload button to create contacts.

### ContactUpdater Class
- Used by the system to update contact information after CSV upload.
- Can also be invoked manually via Apex for specific contact updates.

## Configuration

- Ensure the "Onboarding Manager" Account exists in your Salesforce org.
- The CSV file should have the appropriate format for contact details.

## API Integration

- The `ContactUpdater` class integrates with the Cellebrite API at `https://clb-candidates-data-5d5991b93b50.herokuapp.com/getContacts`.
- Ensure you have the necessary API permissions and network access.
