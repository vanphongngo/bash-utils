#!/bin/bash

# Redis Cluster Key Deletion Script (Fast - No Counting)
# Deletes all keys matching a pattern without counting first
# Usage: ./delete-keys-cluster-fast.sh <redis-info-file> <pattern>

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
    echo "  pattern          - Key pattern to delete (e.g., 'temp:*', 'session:*')"
    echo ""
    echo "Examples:"
    echo "  $0 user-redis-info.txt 'temp:*'"
    echo "  $0 user-redis-info.txt 'session:expired:*'"
    echo "  $0 user-redis-info.txt 'cache:old:*'"
    echo ""
    echo "⚠️  WARNING: This will DELETE keys immediately (no counting phase)!"
    echo "    This is FASTER but you won't know the count beforehand."
    echo "    Use delete-keys-cluster.sh if you want to count first."
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

# Initialize counters
TOTAL_INSTANCES=${#REDIS_INSTANCES[@]}

echo "======================================="
echo -e "${BOLD}Redis Cluster Key Deletion (Fast)${NC}"
echo "======================================="
echo -e "Pattern:       ${RED}${PATTERN}${NC}"
echo -e "Instances:     ${BLUE}${TOTAL_INSTANCES}${NC}"
echo -e "Mode:          ${YELLOW}Fast (no counting)${NC}"
echo "======================================="
echo ""

# Confirmation prompt
echo -e "${RED}${BOLD}⚠️  WARNING ⚠️${NC}"
echo -e "${RED}This will PERMANENTLY DELETE all keys matching '${PATTERN}'${NC}"
echo -e "${RED}across ${TOTAL_INSTANCES} Redis instances!${NC}"
echo ""
echo -e "${YELLOW}Note: This is the FAST mode - keys will be deleted immediately.${NC}"
echo -e "${YELLOW}You will NOT see the count before deletion.${NC}"
echo ""
echo -e "Pattern: ${BOLD}${PATTERN}${NC}"
echo -e "Instances:"
for instance in "${REDIS_INSTANCES[@]}"; do
    echo -e "  - ${instance}"
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
echo -e "${YELLOW}Deleting keys...${NC}"
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

    echo -ne "[${index}/${TOTAL_INSTANCES}] Deleting from ${instance} ... "

    # Use SCAN to get keys and delete them
    DELETED_COUNT=0
    BATCH_SIZE=1000

    while IFS= read -r key; do
        if [ -n "$key" ]; then
            redis-cli -h "$host" -p "$port" DEL "$key" >/dev/null 2>&1
            DELETED_COUNT=$((DELETED_COUNT + 1))

            # Show progress for large deletions
            if [ $((DELETED_COUNT % BATCH_SIZE)) -eq 0 ]; then
                echo -ne "\r[${index}/${TOTAL_INSTANCES}] Deleting from ${instance} ... ${DELETED_COUNT} deleted"
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
