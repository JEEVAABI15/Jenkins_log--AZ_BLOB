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

## Script: `fetch_jenkins_logs.sh`

```bash
#!/bin/bash
# Set variables
JENKINS_URL="http://<your-jenkins-ip>:8080"
JENKINS_USER="admin"
JENKINS_API_TOKEN="<your-jenkins-api-token>"
AZURE_ACCOUNT_NAME="<your-azure-account-name>"
AZURE_CONTAINER_NAME="jenkinslogs"
AZURE_CONNECTION_STRING="<your-azure-connection-string>"

# File to keep track of uploaded builds
STATE_FILE="/tmp/uploaded_builds.txt"
LOG_FILE="./jenkins_blob_upload.log"

# Ensure state & log files exist
touch "$STATE_FILE"
touch "$LOG_FILE"

# Function to log messages with timestamps
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "Starting Jenkins log upload script..."

# Get list of all jobs
jobs=$(curl -s -u "$JENKINS_USER:$JENKINS_API_TOKEN" "$JENKINS_URL/api/json" | jq -r '.jobs[].name')

if [ -z "$jobs" ]; then
    log "Error: No jobs found or Jenkins API is down!"
    exit 1
fi

# Loop through each job
for job in $jobs; do
    log "Fetching logs for job: $job"

    # Get all build numbers for the job
    build_numbers=$(curl -s -u "$JENKINS_USER:$JENKINS_API_TOKEN" "$JENKINS_URL/job/$job/api/json" | jq -r '.builds[].number')

    if [ -z "$build_numbers" ]; then
        log "No builds found for job: $job"
        continue
    fi

    # Loop through each build and fetch logs
    for build_number in $build_numbers; do
        BUILD_IDENTIFIER="${job}-${build_number}"
        TEMP_LOG_FILE="/tmp/${BUILD_IDENTIFIER}.log"

        # Check if this build has already been uploaded
        if grep -q "$BUILD_IDENTIFIER" "$STATE_FILE"; then
            log "Skipping already uploaded log: $BUILD_IDENTIFIER"
            continue
        fi

        log "Fetching logs for Build #$build_number of $job..."

        # Fetch log
        curl -s -u "$JENKINS_USER:$JENKINS_API_TOKEN" "$JENKINS_URL/job/$job/$build_number/consoleText" > "$TEMP_LOG_FILE"

        if [ ! -s "$TEMP_LOG_FILE" ]; then
            log "Warning: Log for $BUILD_IDENTIFIER is empty or missing!"
            rm -f "$TEMP_LOG_FILE"
            continue
        fi

        # Upload to Azure Blob Storage
        az storage blob upload \
            --connection-string "$AZURE_CONNECTION_STRING" \
            --container-name "$AZURE_CONTAINER_NAME" \
            --name "$(basename $TEMP_LOG_FILE)" \
            --file "$TEMP_LOG_FILE" \
            --overwrite

        log "Uploaded log: $BUILD_IDENTIFIER"

        # Mark as uploaded
        echo "$BUILD_IDENTIFIER" >> "$STATE_FILE"

        # Remove the temp file
        rm -f "$TEMP_LOG_FILE"
    done
done

log "Script execution completed!"
```

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




