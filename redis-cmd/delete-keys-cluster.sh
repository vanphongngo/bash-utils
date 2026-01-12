#!/bin/bash

# Redis Cluster Key Deletion Script (Production-Safe with SCAN)
# Deletes all keys matching a pattern across multiple Redis instances
# Usage: ./delete-keys-cluster.sh <redis-info-file> <pattern>

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
    echo "  pattern          - Key pattern to delete (e.g., 'user:*', 'session:*')"
    echo ""
    echo "Examples:"
    echo "  $0 user-redis-info.txt 'temp:*'"
    echo "  $0 user-redis-info.txt 'session:expired:*'"
    echo "  $0 user-redis-info.txt 'cache:old:*'"
    echo ""
    echo "⚠️  WARNING: This will DELETE all matching keys!"
    echo "    This script uses SCAN (production-safe, non-blocking)"
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
TOTAL_KEYS_TO_DELETE=0

echo "======================================="
echo -e "${BOLD}Redis Cluster Key Deletion${NC}"
echo "======================================="
echo -e "Pattern:       ${RED}${PATTERN}${NC}"
echo -e "Instances:     ${BLUE}${TOTAL_INSTANCES}${NC}"
echo "======================================="
echo ""

# First, count keys on all instances
echo -e "${YELLOW}Step 1: Counting keys to delete...${NC}"
echo ""

# Use regular arrays (Bash 3.2 compatible)
INSTANCE_KEY_COUNTS=()

for i in "${!REDIS_INSTANCES[@]}"; do
    instance="${REDIS_INSTANCES[$i]}"
    index=$((i + 1))

    IFS=':' read -r host port <<< "$instance"

    echo -ne "[${index}/${TOTAL_INSTANCES}] Counting keys on ${instance} ... "

    KEY_COUNT=$(count_keys "$host" "$port" "$PATTERN" || echo "0")
    INSTANCE_KEY_COUNTS[$i]=$KEY_COUNT
    TOTAL_KEYS_TO_DELETE=$((TOTAL_KEYS_TO_DELETE + KEY_COUNT))

    if [ "$KEY_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}${KEY_COUNT} keys${NC}"
    else
        echo -e "${GREEN}0 keys${NC}"
    fi
done

echo ""
echo "======================================="
echo -e "${BOLD}Summary:${NC}"
echo -e "  Total keys to delete: ${RED}${TOTAL_KEYS_TO_DELETE}${NC}"
echo "======================================="
echo ""

# If no keys found, exit
if [ $TOTAL_KEYS_TO_DELETE -eq 0 ]; then
    echo -e "${GREEN}No keys found matching pattern '${PATTERN}'${NC}"
    exit 0
fi

# Confirmation prompt
echo -e "${RED}${BOLD}⚠️  WARNING ⚠️${NC}"
echo -e "${RED}This will PERMANENTLY DELETE ${TOTAL_KEYS_TO_DELETE} keys across ${TOTAL_INSTANCES} Redis instances!${NC}"
echo ""
echo -e "Pattern: ${BOLD}${PATTERN}${NC}"
echo ""
echo "Keys per instance:"
for i in "${!REDIS_INSTANCES[@]}"; do
    instance="${REDIS_INSTANCES[$i]}"
    count=${INSTANCE_KEY_COUNTS[$i]}
    if [ "$count" -gt 0 ]; then
        echo -e "  ${instance}: ${RED}${count} keys${NC}"
    fi
done
echo ""
echo -ne "${YELLOW}Type 'DELETE' (in uppercase) to confirm deletion: ${NC}"
read -r CONFIRMATION

if [ "$CONFIRMATION" != "DELETE" ]; then
    echo -e "${GREEN}Deletion cancelled.${NC}"
    exit 0
fi

echo ""
echo "======================================="
echo -e "${YELLOW}Step 2: Deleting keys...${NC}"
echo "======================================="
echo ""

# Delete keys on each instance
SUCCESS_COUNT=0
FAILED_COUNT=0
TOTAL_DELETED=0

for i in "${!REDIS_INSTANCES[@]}"; do
    instance="${REDIS_INSTANCES[$i]}"
    index=$((i + 1))

    IFS=':' read -r host port <<< "$instance"

    expected_count=${INSTANCE_KEY_COUNTS[$i]}

    if [ "$expected_count" -eq 0 ]; then
        continue
    fi

    echo -ne "[${index}/${TOTAL_INSTANCES}] Deleting from ${instance} (${expected_count} keys) ... "

    # Use SCAN to get keys and pipe to DEL
    # Process in batches to avoid command line length limits
    DELETED_COUNT=0
    BATCH_SIZE=1000

    while IFS= read -r key; do
        if [ -n "$key" ]; then
            redis-cli -h "$host" -p "$port" DEL "$key" >/dev/null 2>&1
            DELETED_COUNT=$((DELETED_COUNT + 1))

            # Show progress for large deletions
            if [ $((DELETED_COUNT % BATCH_SIZE)) -eq 0 ]; then
                echo -ne "\r[${index}/${TOTAL_INSTANCES}] Deleting from ${instance} ... ${DELETED_COUNT}/${expected_count}"
            fi
        fi
    done < <(redis-cli -h "$host" -p "$port" --scan --pattern "$PATTERN" 2>&1)

    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "\r[${index}/${TOTAL_INSTANCES}] Deleting from ${instance} ... ${GREEN}✓ SUCCESS${NC} (${DELETED_COUNT} keys deleted)"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        TOTAL_DELETED=$((TOTAL_DELETED + DELETED_COUNT))
    else
        echo -e "\r[${index}/${TOTAL_INSTANCES}] Deleting from ${instance} ... ${RED}✗ FAILED${NC}"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
done

echo ""
echo "======================================="
echo -e "${BOLD}Deletion Complete${NC}"
echo "======================================="
echo "  Total instances: ${TOTAL_INSTANCES}"
echo -e "  Success:         ${GREEN}${SUCCESS_COUNT}${NC}"
echo -e "  Failed:          ${RED}${FAILED_COUNT}${NC}"
echo -e "  Keys deleted:    ${RED}${TOTAL_DELETED}${NC}"
echo "======================================="

exit 0
