# MySQL Log Filter Setup Guide

This guide walks you through creating and setting up a MySQL log filtering script that extracts INSERT, UPDATE, and DELETE queries from your MySQL log file and safely manages log rotation.

## Overview

The script will:
- Filter only **Execute** statements for INSERT, UPDATE, DELETE queries (excludes Prepare statements and SELECT queries)
- **Auto-detect timezone**: Converts UTC timestamps to +7 timezone if system is UTC, keeps local time if already +7
- **Generate executable SQL files**: Outputs clean SQL statements with semicolons in `.sql` format
- Save filtered queries to date-based files (`misacvien_log_YYYY_MM_DD.sql`) ready for execution
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

# Timezone detection and handling
CURRENT_TZ=$(date +%z)
if [[ "$CURRENT_TZ" == "+0000" || "$CURRENT_TZ" == "+00" ]]; then
    # System is in UTC, use +7 timezone for log naming
    DATE_SUFFIX=$(TZ='Asia/Ho_Chi_Minh' date +"%Y_%m_%d")
    TIMEZONE_STATUS="UTC detected, using +7 timezone for log naming"
else
    # System already has timezone offset, use it as-is
    DATE_SUFFIX=$(date +"%Y_%m_%d")
    TIMEZONE_STATUS="Local timezone $CURRENT_TZ detected, using local time"
fi

FILTERED_LOG="$LOG_DIR/misacvien_log_$DATE_SUFFIX.sql"
TEMP_LOG="$LOG_DIR/temp_filtered_log_$$"
TEMP_CONVERTED_LOG="$LOG_DIR/temp_converted_log_$$"
TEMP_SQL_LOG="$LOG_DIR/temp_sql_log_$$"
LOCK_FILE="$LOG_DIR/.mysql_log_filter.lock"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_DIR/filter_script.log"
}

# Function to convert UTC timestamps to +7 timezone
convert_timestamps() {
    local input_file="$1"
    local output_file="$2"

    # Check if we need to convert timestamps (only if system is UTC)
    if [[ "$CURRENT_TZ" == "+0000" || "$CURRENT_TZ" == "+00" ]]; then
        # Convert timestamps from UTC to +7
        while IFS= read -r line; do
            # Look for timestamp patterns like '2025-09-28 16:24:08'
            if [[ $line =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}) ]]; then
                timestamp="${BASH_REMATCH[1]}"
                # Convert UTC timestamp to +7
                converted_timestamp=$(TZ='Asia/Ho_Chi_Minh' date -d "$timestamp UTC" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
                if [[ $? -eq 0 ]]; then
                    # Replace the timestamp in the line
                    converted_line="${line/$timestamp/$converted_timestamp}"
                    echo "$converted_line" >> "$output_file"
                else
                    # If conversion fails, keep original line
                    echo "$line" >> "$output_file"
                fi
            else
                # No timestamp found, keep line as-is
                echo "$line" >> "$output_file"
            fi
        done < "$input_file"
    else
        # No conversion needed, just copy the file
        cp "$input_file" "$output_file"
    fi
}

# Function to format Execute statements as valid SQL
format_as_sql() {
    local input_file="$1"
    local output_file="$2"

    while IFS= read -r line; do
        # Extract SQL from Execute statement: remove connection ID and "Execute" keyword
        # Pattern: "		   448 Execute	insert into ..." -> "insert into ..."
        if [[ $line =~ ^[[:space:]]*[0-9]+[[:space:]]+Execute[[:space:]]+(.+)$ ]]; then
            sql_statement="${BASH_REMATCH[1]}"
            # Add semicolon if not present and write as valid SQL
            if [[ ! $sql_statement =~ \;[[:space:]]*$ ]]; then
                sql_statement="${sql_statement};"
            fi
            echo "$sql_statement" >> "$output_file"
        fi
    done < "$input_file"
}

# Function to cleanup on exit
cleanup() {
    rm -f "$TEMP_LOG" "$TEMP_CONVERTED_LOG" "$TEMP_SQL_LOG" "$LOCK_FILE"
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

log_message "Starting log filtering process... ($TIMEZONE_STATUS)"

# Filter only Execute statements for INSERT, UPDATE, DELETE queries
# Exclude Prepare statements to get only executable SQL
grep -iE "^\s*[0-9]*\s+Execute\s+(insert|update|delete)" "$SOURCE_LOG" > "$TEMP_LOG" 2>/dev/null

# Check if any filtered content was found
if [ -s "$TEMP_LOG" ]; then
    # Convert timestamps if needed (UTC to +7)
    convert_timestamps "$TEMP_LOG" "$TEMP_CONVERTED_LOG"

    # Format as valid SQL statements
    format_as_sql "$TEMP_CONVERTED_LOG" "$TEMP_SQL_LOG"

    # If filtered log already exists for today, append to it
    if [ -f "$FILTERED_LOG" ]; then
        cat "$TEMP_SQL_LOG" >> "$FILTERED_LOG"
        log_message "Appended $(wc -l < "$TEMP_SQL_LOG") SQL statements to existing filtered log: $FILTERED_LOG"
    else
        mv "$TEMP_SQL_LOG" "$FILTERED_LOG"
        log_message "Created new filtered log with $(wc -l < "$FILTERED_LOG") SQL statements: $FILTERED_LOG"
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

## SQL Output Format

The script generates clean, executable SQL files with the following format:

### Input (MySQL Log)
```
		   448 Prepare	insert into `users` (`name`, `email`) values (?, ?)
		   448 Execute	insert into `users` (`name`, `email`) values ('john', 'john@example.com')
		   449 Prepare	update `users` set `last_login` = ? where `id` = ?
		   449 Execute	update `users` set `last_login` = '2025-09-28 17:25:00' where `id` = 123
```

### Output (SQL File)
```sql
insert into `users` (`name`, `email`) values ('john', 'john@example.com');
update `users` set `last_login` = '2025-09-28 17:25:00' where `id` = 123;
```

### Usage Examples

**Execute the SQL file directly:**
```bash
mysql -u username -p database_name < misacvien_log_2025_09_28.sql
```

**View SQL statements:**
```bash
cat misacvien_log_2025_09_28.sql
```

**Import into another database:**
```bash
mysql -u username -p target_database < misacvien_log_2025_09_28.sql
```

**Validate SQL syntax:**
```bash
mysql -u username -p --execute="source misacvien_log_2025_09_28.sql" database_name
```

### Key Benefits
- ✅ **Ready to execute**: No manual editing required
- ✅ **Clean format**: Removes log metadata and connection IDs
- ✅ **Proper syntax**: Adds semicolons automatically
- ✅ **No Prepare statements**: Only actual executed SQL
- ✅ **No SELECT queries**: Only data modification statements

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
| `misacvien_log_YYYY_MM_DD.sql` | Daily executable SQL files containing INSERT/UPDATE/DELETE statements |
| `filter_script.log` | Script execution log with timestamps and status |
| `.mysql_log_filter.lock` | Temporary lock file (auto-removed) |

## Monitoring Commands

### View Script Execution Log
```bash
tail -f /var/lib/mysql/misacvien-mysql-log/filter_script.log
```

### View Today's Filtered SQL
```bash
cat /var/lib/mysql/misacvien-mysql-log/misacvien_log_$(date +"%Y_%m_%d").sql
```

### Execute Today's SQL Statements
```bash
mysql -u username -p database_name < /var/lib/mysql/misacvien-mysql-log/misacvien_log_$(date +"%Y_%m_%d").sql
```

### Check Original Log Status
```bash
ls -la /var/lib/mysql/misacvien-mysql-log/misacvien.log
```

### View All SQL Files
```bash
ls -la /var/lib/mysql/misacvien-mysql-log/misacvien_log_*.sql
```

## Cleanup & Maintenance

### Archive Old SQL Files (30+ days)
```bash
find /var/lib/mysql/misacvien-mysql-log -name "misacvien_log_*.sql" -mtime +30 -delete
```

### Compress Old SQL Files Before Deletion
```bash
find /var/lib/mysql/misacvien-mysql-log -name "misacvien_log_*.sql" -mtime +7 -exec gzip {} \;
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

## Timezone Handling

The script automatically detects and handles timezone conversion:

### How it Works
- **UTC Detection**: If system timezone is UTC (+0000), timestamps in log entries are converted to +7 timezone (Asia/Ho_Chi_Minh)
- **Local Timezone**: If system already uses +7 or other timezone, timestamps are kept as-is
- **Smart Conversion**: Only actual timestamp values in SQL queries are converted, not log metadata

### Examples
**UTC System (converts timestamps):**
```
Original: insert into users (created_at) values ('2025-09-28 10:24:08')
Filtered: insert into users (created_at) values ('2025-09-28 17:24:08')
```

**+7 System (keeps timestamps):**
```
Original: insert into users (created_at) values ('2025-09-28 17:24:08')
Filtered: insert into users (created_at) values ('2025-09-28 17:24:08')
```

### Verification
Check timezone status in the execution log:
```bash
tail /var/lib/mysql/misacvien-mysql-log/filter_script.log
# Look for: "Local timezone +0700 detected" or "UTC detected"
```

## Performance Impact

The script is designed to minimize database performance impact:

- Uses atomic `truncate` operation (no file locking)
- Processes logs quickly with efficient grep filtering
- Minimal CPU and I/O usage
- Runs independently of database operations
- Timezone conversion adds minimal overhead (only when needed)

## Security Considerations

- Filtered logs contain actual query data - ensure proper access controls
- Script runs with appropriate permissions (640 for filtered logs)
- Lock mechanism prevents resource conflicts
- Temporary files are properly cleaned up