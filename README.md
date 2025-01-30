# Jenkins Logs Fetch and Upload to Azure Blob Storage

## Overview

This script retrieves logs from the latest builds of all Jenkins jobs and uploads them to Azure Blob Storage. It requires Jenkins credentials and an Azure Storage account for storing logs.

## Prerequisites

Ensure the following dependencies are installed on your system:

- **Jenkins** (Running on a VM)
- **Jenkins API Token** (Generated from Jenkins User Profile)
- **Azure CLI** (For interacting with Azure Blob Storage)
- **cURL** (For API requests)
- **jq** (Optional, for JSON parsing)

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
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

## Script Details

The script performs the following:

- Fetches all Jenkins jobs
- Retrieves the latest build number for each job
- Downloads the build logs
- Uploads the logs to Azure Blob Storage
- Deletes local log files after upload

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

# Get the list of Jenkins jobs
jobs=$(curl -s -u "$JENKINS_USER:$JENKINS_API_TOKEN" "$JENKINS_URL/api/json" | grep -oP '"name":"\K[^"]+')
echo "Jobs found:"
echo "$jobs"

fetch_latest_build_number() {
  local job_name="$1"
  if command -v jq &> /dev/null; then
    curl -s --fail -u "$JENKINS_USER:$JENKINS_API_TOKEN" "$JENKINS_URL/job/$job_name/lastBuild/api/json" | \
      jq -r '.number'
  else
    curl -s --fail -u "$JENKINS_USER:$JENKINS_API_TOKEN" "$JENKINS_URL/job/$job_name/lastBuild/api/json" | \
      grep -oP '"number":\K[0-9]+' | head -n 1
  fi
}

for job in $jobs; do
  echo "Processing job: $job"
  build_number=$(fetch_latest_build_number "$job")
  if [ -n "$build_number" ]; then
    console_url="$JENKINS_URL/job/$job/$build_number/consoleText"
    log_content=$(curl -s --fail -u "$JENKINS_USER:$JENKINS_API_TOKEN" "$console_url")
    if [ -n "$log_content" ]; then
      log_file="${job}-build-${build_number}.log"
      echo "$log_content" > "$log_file"
      az storage blob upload \
        --account-name $AZURE_ACCOUNT_NAME \
        --container-name $AZURE_CONTAINER_NAME \
        --file "$log_file" \
        --name "$log_file" \
        --connection-string "$AZURE_CONNECTION_STRING"
      rm "$log_file"
    fi
  fi
done
```

## Execution

Run the script using:

```bash
bash fetch_jenkins_logs.sh
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

