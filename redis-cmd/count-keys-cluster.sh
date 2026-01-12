#!/bin/bash

# Redis Cluster Key Counter Script
# Counts all keys matching a pattern across multiple Redis instances
# Usage: ./count-keys-cluster.sh <redis-info-file> <pattern>

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Check if redis-cli is installed
if ! command -v redis-cli &> /dev/null; then
    echo -e "${RED}Error: redis-cli is not installed${NC}"
    exit 1
fi

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <redis-info-file> <pattern>"
    echo ""
    echo "Arguments:"
    echo "  redis-info-file  - File containing Redis instances (IP:PORT format)"
    echo "  pattern          - Key pattern to count (e.g., 'user:*', 'session:*')"
    echo ""
    echo "Examples:"
    echo "  $0 user-redis-info.txt 'user:*'"
    echo "  $0 user-redis-info.txt 'session:*'"
    echo "  $0 user-redis-info.txt 'QC|ZPP|TASK*'"
    echo ""
    echo "Note: This is a read-only operation (safe to run anytime)"
    exit 1
fi

REDIS_INFO_FILE="$1"
PATTERN="$2"

# Check if input file exists
if [ ! -f "$REDIS_INFO_FILE" ]; then
    echo -e "${RED}Error: File '$REDIS_INFO_FILE' not found${NC}"
    exit 1
fi

# Read Redis instances (Bash 3.2+ compatible)
REDIS_INSTANCES=()
while IFS= read -r line; do
    REDIS_INSTANCES+=("$line")
done < <(grep -v '^#' "$REDIS_INFO_FILE" | grep -v '^[[:space:]]*$' | sed 's/^[[:space:]]*[0-9]*[[:space:]]*→[[:space:]]*//')

if [ ${#REDIS_INSTANCES[@]} -eq 0 ]; then
    echo -e "${RED}Error: No Redis instances found in file${NC}"
    exit 1
fi

# Function to count keys matching pattern
count_keys() {
    local host=$1
    local port=$2
    local pattern=$3

    redis-cli -h "$host" -p "$port" --scan --pattern "$pattern" 2>/dev/null | wc -l | tr -d ' '
}

# Initialize counters
TOTAL_INSTANCES=${#REDIS_INSTANCES[@]}
TOTAL_KEYS=0
SUCCESS_COUNT=0
FAILED_COUNT=0

echo "======================================="
echo -e "${BOLD}Redis Cluster Key Counter${NC}"
echo "======================================="
echo -e "Pattern:       ${BLUE}${PATTERN}${NC}"
echo -e "Instances:     ${BLUE}${TOTAL_INSTANCES}${NC}"
echo "======================================="
echo ""

# Count keys on all instances
for i in "${!REDIS_INSTANCES[@]}"; do
    instance="${REDIS_INSTANCES[$i]}"
    index=$((i + 1))

    IFS=':' read -r host port <<< "$instance"

    echo -ne "[${index}/${TOTAL_INSTANCES}] Counting keys on ${instance} ... "

    KEY_COUNT=$(count_keys "$host" "$port" "$PATTERN" 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ] && [ "$KEY_COUNT" != "" ]; then
        if [ "$KEY_COUNT" -gt 0 ]; then
            echo -e "${GREEN}✓${NC} ${YELLOW}${KEY_COUNT}${NC} keys"
        else
            echo -e "${GREEN}✓${NC} 0 keys"
        fi
        TOTAL_KEYS=$((TOTAL_KEYS + KEY_COUNT))
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo -e "${RED}✗ FAILED${NC}"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
done

echo ""
echo "======================================="
echo -e "${BOLD}Summary:${NC}"
echo "  Total instances: ${TOTAL_INSTANCES}"
echo -e "  Success:         ${GREEN}${SUCCESS_COUNT}${NC}"
echo -e "  Failed:          ${RED}${FAILED_COUNT}${NC}"
echo -e "  Total keys:      ${YELLOW}${TOTAL_KEYS}${NC}"
echo "======================================="

# Estimate size if many keys
if [ $TOTAL_KEYS -gt 1000000 ]; then
    echo ""
    echo -e "${YELLOW}Note: Large dataset detected (${TOTAL_KEYS} keys)${NC}"
    echo "  - Finding all keys may take 15-30 minutes"
    echo "  - Deleting all keys may take 20-40 minutes"
    echo "  - Consider using more specific patterns to reduce scope"
fi

exit 0
