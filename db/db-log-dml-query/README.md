# MySQL Log Filter Setup Guide

This guide walks you through creating and setting up a MySQL log filtering script that extracts INSERT, UPDATE, and DELETE queries from your MySQL log file and safely manages log rotation.

## Overview

The script will:
- Filter INSERT, UPDATE, DELETE queries from `misacvien.log` (excludes SELECT queries)
- Save filtered queries to date-based files (`misacvien_log_YYYY_MM_DD`)
- Safely truncate the original log file to prevent unlimited growth
- Run automatically every 5 minutes via cron job

## Step 1: Create the Script

Create the main filtering script:

```bash
nano /var/lib/mysql/misacvien-mysql-log/mysql_log_filter.sh
```

Copy and paste the following script content:

```bash
#!/bin/bash

# MySQL Log Filter Script
# Filters INSERT, UPDATE, DELETE queries from MySQL log and rotates logs safely

# Configuration
LOG_DIR="/var/lib/mysql/misacvien-mysql-log"
SOURCE_LOG="$LOG_DIR/misacvien.log"
DATE_SUFFIX=$(date +"%Y_%m_%d")
FILTERED_LOG="$LOG_DIR/misacvien_log_$DATE_SUFFIX"
TEMP_LOG="$LOG_DIR/temp_filtered_log_$$"
LOCK_FILE="$LOG_DIR/.mysql_log_filter.lock"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_DIR/filter_script.log"
}

# Function to cleanup on exit
cleanup() {
    rm -f "$TEMP_LOG" "$LOCK_FILE"
    exit $1
}

# Set up signal handlers
trap 'cleanup 1' INT TERM
trap 'cleanup 0' EXIT

# Check if another instance is running
if [ -f "$LOCK_FILE" ]; then
    log_message "Another instance is already running. Exiting."
    exit 1
fi

# Create lock file
echo $$ > "$LOCK_FILE"

# Check if source log exists
if [ ! -f "$SOURCE_LOG" ]; then
    log_message "Source log file $SOURCE_LOG does not exist. Exiting."
    exit 1
fi

# Check if source log is empty
if [ ! -s "$SOURCE_LOG" ]; then
    log_message "Source log file $SOURCE_LOG is empty. Nothing to process."
    exit 0
fi

log_message "Starting log filtering process..."

# Filter INSERT, UPDATE, DELETE queries (both Prepare and Execute statements)
# Using case-insensitive grep to catch variations, but exclude SELECT queries
grep -iE "^\s*[0-9]*\s+(Prepare|Execute)\s+(insert|update|delete)" "$SOURCE_LOG" > "$TEMP_LOG" 2>/dev/null

# Check if any filtered content was found
if [ -s "$TEMP_LOG" ]; then
    # If filtered log already exists for today, append to it
    if [ -f "$FILTERED_LOG" ]; then
        cat "$TEMP_LOG" >> "$FILTERED_LOG"
        log_message "Appended $(wc -l < "$TEMP_LOG") lines to existing filtered log: $FILTERED_LOG"
    else
        mv "$TEMP_LOG" "$FILTERED_LOG"
        log_message "Created new filtered log with $(wc -l < "$FILTERED_LOG") lines: $FILTERED_LOG"
    fi

    # Set appropriate permissions
    chmod 640 "$FILTERED_LOG"

    # Get file size before truncation for logging
    ORIGINAL_SIZE=$(stat -c%s "$SOURCE_LOG")

    # Safely truncate the original log file
    # Using truncate command as requested - this is atomic and safe
    if truncate -s 0 "$SOURCE_LOG"; then
        log_message "Successfully truncated $SOURCE_LOG (was ${ORIGINAL_SIZE} bytes)"
    else
        log_message "ERROR: Failed to truncate $SOURCE_LOG"
        exit 1
    fi
else
    log_message "No INSERT/UPDATE/DELETE queries found in the log file."
    rm -f "$TEMP_LOG"
fi

log_message "Log filtering process completed successfully."
```

## Step 2: Set Script Permissions

Make the script executable:

```bash
chmod +x /var/lib/mysql/misacvien-mysql-log/mysql_log_filter.sh
```

## Step 3: Test the Script

Navigate to the script directory and run a test:

```bash
cd /var/lib/mysql/misacvien-mysql-log
./mysql_log_filter.sh
```

Check if it worked:

```bash
# Check execution log
cat filter_script.log

# Check if filtered log was created
ls -la misacvien_log_*

# View today's filtered content
cat misacvien_log_$(date +"%Y_%m_%d")
```

## Step 4: Set Up Cron Job (Every 5 Minutes)

Edit the crontab:

```bash
sudo crontab -e
```

Add the following line to run the script every 5 minutes:

```bash
# Run MySQL log filter every 5 minutes
*/5 * * * * cd /var/lib/mysql/misacvien-mysql-log && ./mysql_log_filter.sh
```

### Alternative Cron Schedules

- **Every 10 minutes**: `*/10 * * * * cd /var/lib/mysql/misacvien-mysql-log && ./mysql_log_filter.sh`
- **Every 30 minutes**: `*/30 * * * * cd /var/lib/mysql/misacvien-mysql-log && ./mysql_log_filter.sh`
- **Every hour**: `0 * * * * cd /var/lib/mysql/misacvien-mysql-log && ./mysql_log_filter.sh`
- **Daily at 2 AM**: `0 2 * * * cd /var/lib/mysql/misacvien-mysql-log && ./mysql_log_filter.sh`

## Step 5: Verify Cron Job

Check if the cron job is active:

```bash
sudo crontab -l
```

Monitor the script execution in real-time:

```bash
tail -f /var/lib/mysql/misacvien-mysql-log/filter_script.log
```

## Manual Background Execution

To run the script manually in the background:

```bash
cd /var/lib/mysql/misacvien-mysql-log
nohup ./mysql_log_filter.sh > /dev/null 2>&1 &
```

## Script Features

### 🔒 Safety Features
- **Lock mechanism**: Prevents multiple instances running simultaneously
- **Atomic truncation**: Uses `truncate` command that doesn't affect database performance
- **Error handling**: Proper cleanup and exit codes
- **Signal handling**: Graceful shutdown on interruption

### 📊 Logging & Monitoring
- **Detailed logging**: All operations logged with timestamps in `filter_script.log`
- **Execution tracking**: Monitor script runs and results
- **File size tracking**: Logs original file size before truncation

### 📁 File Management
- **Date-based organization**: Creates `misacvien_log_YYYY_MM_DD` files
- **Append support**: Multiple runs per day append to the same daily file
- **Proper permissions**: Sets 640 permissions on filtered logs

## Files Created

| File | Description |
|------|-------------|
| `misacvien_log_YYYY_MM_DD` | Daily filtered logs containing INSERT/UPDATE/DELETE queries |
| `filter_script.log` | Script execution log with timestamps and status |
| `.mysql_log_filter.lock` | Temporary lock file (auto-removed) |

## Monitoring Commands

### View Script Execution Log
```bash
tail -f /var/lib/mysql/misacvien-mysql-log/filter_script.log
```

### View Today's Filtered Queries
```bash
cat /var/lib/mysql/misacvien-mysql-log/misacvien_log_$(date +"%Y_%m_%d")
```

### Check Original Log Status
```bash
ls -la /var/lib/mysql/misacvien-mysql-log/misacvien.log
```

### View All Filtered Logs
```bash
ls -la /var/lib/mysql/misacvien-mysql-log/misacvien_log_*
```

## Cleanup & Maintenance

### Archive Old Logs (30+ days)
```bash
find /var/lib/mysql/misacvien-mysql-log -name "misacvien_log_*" -mtime +30 -delete
```

### Compress Old Logs Before Deletion
```bash
find /var/lib/mysql/misacvien-mysql-log -name "misacvien_log_*" -mtime +7 -exec gzip {} \;
```

### Remove Lock File (if script hangs)
```bash
rm -f /var/lib/mysql/misacvien-mysql-log/.mysql_log_filter.lock
```

## Troubleshooting

### Script Not Running
1. Check permissions: `ls -la mysql_log_filter.sh`
2. Check cron service: `sudo systemctl status cron`
3. Check cron logs: `sudo tail -f /var/log/syslog | grep CRON`

### No Filtered Output
1. Check if source log has INSERT/UPDATE/DELETE queries
2. Verify script has read access to source log
3. Check execution log for errors

### Permission Issues
```bash
# Fix script permissions
chmod +x mysql_log_filter.sh

# Fix log directory permissions
chown mysql:mysql /var/lib/mysql/misacvien-mysql-log/
chmod 755 /var/lib/mysql/misacvien-mysql-log/
```

## Performance Impact

The script is designed to minimize database performance impact:

- Uses atomic `truncate` operation (no file locking)
- Processes logs quickly with efficient grep filtering
- Minimal CPU and I/O usage
- Runs independently of database operations

## Security Considerations

- Filtered logs contain actual query data - ensure proper access controls
- Script runs with appropriate permissions (640 for filtered logs)
- Lock mechanism prevents resource conflicts
- Temporary files are properly cleaned up