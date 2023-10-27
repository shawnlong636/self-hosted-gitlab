#!/bin/bash

# Function to load environment variables from .env file
load_env() {
    if [ -z "$1" ]; then
        echo "Error: The function load_env() requires a path to a .env file as an argument."
        return 1
    fi

    if [ ! -f "$1" ]; then
        echo "Error: The file '$1' does not exist."
        return 1
    fi

    env_path="$1"

    set -o allexport
    source "$env_path"
    set +o allexport

    return 0
}

# Function to check if SLACK_WEBHOOK_URL is set
check_env_vars() {
    required_vars=("SLACK_WEBHOOK_URL" "GITLAB_HOME" "B2_APPLICATION_KEY_ID" "B2_APPLICATION_KEY")

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            echo "Error: $var has not been set."
            exit 1
        fi
    done

    return 0
}

check_sudo_privileges() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: This script must be run as root."
        exit 1
    fi

    return 0
}

# Fucntion to send a message to Slack
send_slack_message() {
    if [ -z "$1" ]; then
        echo "The function send_slack_message() requires a message as an argument."
        echo "Unable to send slack message."
        return 1
    else
        message="$1"
    fi

    curl_output=$(curl -X POST -H 'Content-type: application/json' --data '{"text":"'"$message"'"}' "$SLACK_WEBHOOK_URL" 2>&1)
    curl_exit_code=$?

    if [ $curl_exit_code -ne 0 ]; then
        echo "Error: Unable to send slack message. curl output:"
        echo "$curl_output"
        return 1
    fi

    return 0
}

upload_backup() {

    if [ -z "$1" ]; then
        echo "The function upload_backup() requires a directory containing .tar files to upload."
        echo "Unable to upload backup."
        return 1
    else
        backup_dir="$1"
    fi

    if [ -z "$2" ]; then
        echo "The function upload_backup() requires a directory containing .tar files to upload."
        echo "Unable to upload backup."
        return 1
    else
        target_name="$2"
    fi

    # Get Backup Files
    tar_files=$(find "$backup_dir" -maxdepth 1 -type f \( -name "*.tar" -o -name "*.tar.xz" \) -printf "%T@ %p\n" | sort -n | awk '{print $2}')
    IFS=' ' read -ra tar_files <<< "$tar_files" # Convert the string to an array

    if [ ${#tar_files[@]} -eq 0 ]; then
        echo "Unable to find GitLab backup files in $backup_dir"
        send_slack_message "$(date '+%Y-%m-%d %H:%M:%S') | Unable to find GitLab backup file for upload. Error: $backup_message"
        return 1
    fi

    # Compress and Upload Newest File
    newest_tar="${tar_files[-1]}"

    if [[ "$newest_tar" == *.tar ]]; then
        echo "compressing backup file: $newest_tar to $newest_tar.xz"
        xz -z "$newest_tar"
        compressed_file="$newest_tar.xz"
    else
        compressed_file="$newest_tar"
    fi

    { upload_message=$(b2-linux upload-file gitlab-backup-data "$compressed_file" "$target_name" 2>&1 >&3 3>&-); } 3>&1
    upload_exit_code=$?
    if [ $upload_exit_code -ne 0 ]; then
        echo "Unable to upload GitLab backup file. Error: $upload_message"
        send_slack_message "$(date '+%Y-%m-%d %H:%M:%S') | Unable to upload GitLab backup file. Error: $upload_message"
        return 1
    fi
}

# Function to run Gitlab backup and capture any error messages
run_gitlab_backup() {
    backup_dir="$GITLAB_HOME/data/backups"

    echo "Initiating GitLab Application Backup."

    # Create the Backup File
    { backup_message=$(docker exec -t gitlab-server gitlab-backup 2>&1 >&3 3>&-); } 3>&1
    backup_file_exit_code=$?


    if [ $backup_file_exit_code -ne 0 ]; then
        echo "Unable to create GitLab Application backup file. Error: $backup_message"

        send_slack_message "$(date '+%Y-%m-%d %H:%M:%S') | Failed to create GitLab backup file. Error: $backup_message"
        return 1
    fi

    upload_backup "$backup_dir" "gitlab_app_data.tar.xz"


    # Success Message
    echo "GitLab backup created successfully"
    send_slack_message "$(date '+%Y-%m-%d %H:%M:%S') | Successfully created GitLab Application Backup file."


    return 0
}

run_gitlab_config_backup() {
    backup_dir="$GITLAB_HOME/secret-backups"

    echo "Initiating GitLab Config Backup."

    { backup_message=$(docker exec -t gitlab-server /bin/sh -c 'gitlab-ctl backup-etc' 2>&1 >&3 3>&-); } 3>&1
    backup_file_exit_code=$?

    if [ $backup_file_exit_code -ne 0 ]; then
        echo "Unable to create GitLab Config backup file. Error: $backup_message"

        send_slack_message "$(date '+%Y-%m-%d %H:%M:%S') | Failed to create GitLab Config backup file. Error: $backup_message"
        return 1
    fi

    upload_backup "$backup_dir" "gitlab_config_data.tar.xz"

    echo "GitLab backup created successfully"
    echo "Sending successfull notification via Slack."

    send_slack_message "$(date '+%Y-%m-%d %H:%M:%S') | Successfully created GitLab Config Backup file."

    return 0
}

clear_directory() {
    if [ -z "$1" ]; then
        echo "The function clear_directory() requires a directory to clear."
        echo "Unable to clear directory."
        return 1
    else
        directory="$1"
    fi

    if [[ "${directory: -1}" != "/" ]]; then
        directory="$directory/"
    fi

    if [[ -d "$directory" ]]; then
        echo "Clearing directory: $directory"
        sudo rm -rf "$directory"*
    else
        echo "Unable to clear directory: $directory"
        echo "Directory does not exist."
        return 1
    fi

    return 0
}

# Main function
main() {
    load_env "$1"
    check_env_vars
    check_sudo_privileges
    clear_directory "$GITLAB_HOME/data/backups"
    clear_directory "$GITLAB_HOME/secret-backups"

    run_gitlab_config_backup
    config_backup_exit_code=$?

    run_gitlab_backup
    app_backup_exit_code=$?

    clear_directory "$GITLAB_HOME/data/backups"
    clear_directory "$GITLAB_HOME/secret-backups"


    if [ "$app_backup_exit_code" -ne 0 ] || [ "$config_backup_exit_code" -ne 0 ]; then
        exit 1
    fi
}


# Call the main function
main "$1"