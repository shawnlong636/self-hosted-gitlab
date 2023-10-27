# Self-Hosted GitLab Setup with Backup Script

This repository contains configuration and scripts needed to deploy a self-hosted GitLab instance using Docker and also set up automated backups to Backblaze B2 storage.

## Table of Contents

- [Prerequisites](#prerequisites)
- [GitLab Setup](#gitlab-setup)
  - [Docker Compose File](#docker-compose-file)
- [Backup Script](#backup-script)
  - [Environment Variables](#environment-variables)
  - [Scheduled Backups](#scheduled-backups)
- [Usage](#usage)
- [Contributors](#contributors)

## Prerequisites

1. Docker and Docker-Compose installed.
2. A Backblaze B2 account for storing backups.
3. Slack Webhook URL for notifications.
4. sudo privileges to run the backup script.

## GitLab Setup

### Docker Compose File

The `docker-compose.yml` file describes the Docker setup for running GitLab. The configuration includes:

- **Web Service**: Runs GitLab using the official image.
- **Environment Variables**: These are required to set up GitLab, enable HTTPS with Let's Encrypt, and configure email notifications.
- **Ports**: Exposes various ports, including HTTP, HTTPS, and SSH.
- **Volumes**: These are to persist data and logs, and also for backup purposes.

To start GitLab, run `docker-compose up -d` from the directory containing `docker-compose.yml`.

## Backup Script

The `backup.sh` script performs a GitLab backup and uploads it to Backblaze B2 storage. The script also notifies a Slack channel if it succeeds or fails.

### Environment Variables

Before running the script, ensure the `.env` file is populated with the necessary environment variables like `SLACK_WEBHOOK_URL`, `GITLAB_HOME`, `B2_APPLICATION_KEY_ID`, and `B2_APPLICATION_KEY`.

### Scheduled Backups

To set up a cron job to automate the backup, add the following line to your crontab:

```bash
0 9 * * * (/home/<USER_NAME>/<PROJECT_DIR>/backup.sh /home/<USER_NAME>/<PROJECT_DIR>/.env 2>&1 | awk -v date="$(date +\%Y-\%m-\%d\ \%H:\%M:\%S)" '{print date " " $0}' >> /home/<USER_NAME>/<PROJECT_DIR>/gitlab-cron.log)
```

This will run the backup script every day at 9:00 AM (UTC) (2:00AM PST) and log the output.

## Usage

1. Clone this repository: `git clone git@github.com:shawnlong636/self-hosted-gitlab.git`
2. Navigate to the directory: `cd your-repo`
3. Start GitLab: `docker-compose up -d`
4. Test backup script: `sudo ./backup.sh ./env`

This will run the backup script every day at 9:00 AM and log the output.

## Usage

1. Clone this repository: `git clone https://your-repo.git`
2. Navigate to the directory: `cd your-repo`
3. Start GitLab: `docker-compose up -d`
4. Test backup script: `sudo ./backup.sh ./env`

## Contributors

- [Shawn Long](https://github.com/shawnlong636)
-  Documentation assistance provided by [ChatGPT](https://chat.openai.com/)

For any further questions, please reach out to the contributors.