#!/bin/bash

# Redis Cluster Key Deletion Script
# Usage: ./redis-delete-keys.sh [-h host] [-p port] [-a password] [keys_file.txt] OR ./redis-delete-keys.sh [-h host] [-p port] [-a password] key1 key2 key3

# Default Redis connection settings
REDIS_HOST="10.50.1.22"
REDIS_PORT="9319"
REDIS_PASSWORD=""  # Add password if needed

# Function to show usage
show_usage() {
    echo "Usage: $0 [-h host] [-p port] [-a password] [keys_file.txt] OR $0 [-h host] [-p port] [-a password] key1 key2 key3"
    echo ""
    echo "Options:"
    echo "  -h host      Redis host (default: $REDIS_HOST)"
    echo "  -p port      Redis port (default: $REDIS_PORT)"
    echo "  -a password  Redis password (optional)"
    echo ""
    echo "Examples:"
    echo "  $0 key1 key2 key3"
    echo "  $0 -h localhost -p 6379 key1 key2"
    echo "  $0 -h localhost -p 6379 -a mypassword keys.txt"
}

# Function to delete a single key
delete_key() {
    local key=$1
    echo "Attempting to delete key: $key"
    
    # Try to delete the key
    result=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ${REDIS_PASSWORD:+-a "$REDIS_PASSWORD"} DEL "$key" 2>&1)
    
    # Check if we got a MOVED error
    if [[ "$result" == *"MOVED"* ]]; then
        # Extract new host and port from the MOVED response
        new_host=$(echo "$result" | grep -o "MOVED [0-9]* [0-9.]*:[0-9]*" | awk '{print $3}' | cut -d':' -f1)
        new_port=$(echo "$result" | grep -o "MOVED [0-9]* [0-9.]*:[0-9]*" | awk '{print $3}' | cut -d':' -f2)
        
        echo "Key moved to $new_host:$new_port. Retrying..."
        
        # Retry deletion on the new node
        result=$(redis-cli -h "$new_host" -p "$new_port" ${REDIS_PASSWORD:+-a "$REDIS_PASSWORD"} DEL "$key" 2>&1)
        
        if [[ "$result" == "1" ]]; then
            echo "✅ Successfully deleted key: $key"
        elif [[ "$result" == "0" ]]; then
            echo "❌ Key not found: $key"
        else
            echo "❌ Failed to delete key: $key. Error: $result"
        fi
    elif [[ "$result" == "1" ]]; then
        echo "✅ Successfully deleted key: $key"
    elif [[ "$result" == "0" ]]; then
        echo "❌ Key not found: $key"
    else
        echo "❌ Failed to delete key: $key. Error: $result"
    fi
}

# Main script logic
main() {
    # Check if redis-cli is installed
    if ! command -v redis-cli &> /dev/null; then
        echo "Error: redis-cli is not installed. Please install Redis tools first."
        echo "You can install it using: brew install redis"
        exit 1
    fi
    
    # Parse command line options
    while getopts "h:p:a:" opt; do
        case $opt in
            h)
                REDIS_HOST="$OPTARG"
                ;;
            p)
                REDIS_PORT="$OPTARG"
                ;;
            a)
                REDIS_PASSWORD="$OPTARG"
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                show_usage
                exit 1
                ;;
        esac
    done

    # Shift past the processed options
    shift $((OPTIND-1))

    echo "Using Redis connection: $REDIS_HOST:$REDIS_PORT"

    # Process arguments
    if [[ $# -eq 0 ]]; then
        echo "Please provide keys to delete or a file containing keys (one per line)"
        show_usage
        exit 1
    elif [[ $# -eq 1 && -f "$1" ]]; then
        # Reading keys from file
        echo "Reading keys from file: $1"
        while IFS= read -r key || [[ -n "$key" ]]; do
            [[ -z "$key" || "$key" == \#* ]] && continue  # Skip empty lines and comments
            delete_key "$key"
        done < "$1"
    else
        # Process keys provided as arguments
        for key in "$@"; do
            delete_key "$key"
        done
    fi
    
    echo "Deletion process completed."
}

# Run the main function
main "$@"