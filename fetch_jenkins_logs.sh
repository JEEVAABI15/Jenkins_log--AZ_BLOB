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
