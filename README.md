# Jenkins Logs Upload to Azure Blob Storage
## Overview

This script automates the process of fetching Jenkins build logs and uploading them to an Azure Blob Storage container. It ensures that only new logs are uploaded, avoiding duplicate uploads.

## Prerequisites

Ensure the following dependencies are installed on your system:

- **Jenkins** (Running on a VM)
- **Jenkins API Token** (Generated from Jenkins User Profile)
- **Azure CLI** (For interacting with Azure Blob Storage)
- **cURL** (For API requests)
- **jq** (Optional, for JSON parsing)
- Network access to Jenkins and Azure Storage

## Installation

### 1. Install Jenkins

Run the following commands to install Jenkins on an Ubuntu system:

```bash
sudo apt update
sudo apt install -y openjdk-11-jdk
java -version
wget -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update
sudo apt install -y jenkins
sudo systemctl enable --now jenkins
sudo systemctl start jenkins
```

Retrieve the initial Jenkins admin password:

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### 2. Configure Jenkins API Token

1. Login to Jenkins (`http://<jenkins-ip>:8080`)
2. Click on **your username** (top-right corner) > **Configure**
3. Scroll down to **API Token**
4. Click **Add new Token**, provide a name, and click **Generate**
5. Copy and securely store the token

### 3. Install Azure CLI

```bash
sudo apt update && sudo apt install -y jq
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```
```bash
az login
```
```bash
az storage account keys list --account-name <your-storage-account>
```
## State and Log Files

- **STATE_FILE:** Keeps track of uploaded builds (/tmp/uploaded_builds.txt by default)

- **LOG_FILE:** Logs script execution (./jenkins_blob_upload.log by default)


## Script Details

The script performs the following:

- Retrieves a list of all Jenkins jobs
- Iterates through each job to find its build numbers
- Fetches logs for each build
- Checks if the log has already been uploaded
- Uploads the log file to Azure Blob Storage
- Marks the build as uploaded in STATE_FILE
- Cleans up temporary log files

## Execution

Run the script using:

```bash
bash ./fetch_jenkins_logs.sh
```
Check logs:

```bash
cat jenkins_blob_upload.log
```
## Troubleshooting

### Error: "Unauthorized"

- Ensure API token and credentials are correct
- Verify Jenkins URL is accessible

### Error: "Blob upload failed"

- Ensure Azure CLI is authenticated (`az login`)
- Check Azure connection string and storage account details

## Conclusion

This setup automates Jenkins log retrieval and storage in Azure. You can further integrate it with monitoring tools for centralized log analysis.




