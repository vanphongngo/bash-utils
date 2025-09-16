#!/bin/bash

# Redis Cluster Key Deletion Script
# Usage: ./redis-delete-keys.sh [keys_file.txt] OR ./redis-delete-keys.sh key1 key2 key3

# Default Redis connection settings
REDIS_HOST="10.50.1.22"
REDIS_PORT="9319"
REDIS_PASSWORD=""  # Add password if needed

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
    
    # Process arguments
    if [[ $# -eq 0 ]]; then
        echo "Please provide keys to delete or a file containing keys (one per line)"
        echo "Usage: $0 [keys_file.txt] OR $0 key1 key2 key3"
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