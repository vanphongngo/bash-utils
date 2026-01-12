#!/bin/bash

# Redis Cluster Key Deletion Script (Ultra Fast - Uses KEYS command)
# WARNING: Uses KEYS command which BLOCKS Redis during execution
# Only use this on dev/test environments or during maintenance windows!
# Usage: ./delete-keys-cluster-ultrafast.sh <redis-info-file> <pattern>

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
    echo "  $0 user-redis-info.txt 'QC|MG|USER|USER_SEGMENT|*'"
    echo ""
    echo "⚠️  WARNING: This uses KEYS command (BLOCKS Redis during execution)!"
    echo "    - ULTRA FAST but temporarily blocks Redis"
    echo "    - Only use on dev/test or during maintenance windows"
    echo "    - For production, use delete-keys-cluster-fast.sh instead"
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
echo -e "${BOLD}${YELLOW}Redis Cluster Key Deletion (ULTRA FAST)${NC}"
echo "======================================="
echo -e "Pattern:       ${RED}${PATTERN}${NC}"
echo -e "Instances:     ${BLUE}${TOTAL_INSTANCES}${NC}"
echo -e "Mode:          ${YELLOW}KEYS command (BLOCKS Redis!)${NC}"
echo "======================================="
echo ""

# Confirmation prompt
echo -e "${RED}${BOLD}⚠️  DANGER - ULTRA FAST MODE ⚠️${NC}"
echo -e "${RED}This uses KEYS command which BLOCKS Redis during execution!${NC}"
echo ""
echo -e "${YELLOW}What this means:${NC}"
echo -e "  - ${GREEN}✅ EXTREMELY FAST${NC} (10-100x faster than SCAN)"
echo -e "  - ${RED}❌ BLOCKS Redis${NC} during key retrieval (1-5 seconds per million keys)"
echo -e "  - ${YELLOW}⚠️  Redis cannot serve other requests${NC} while KEYS is running"
echo ""
echo -e "${YELLOW}Only use this if:${NC}"
echo -e "  - This is a dev/test environment, OR"
echo -e "  - You are in a maintenance window, OR"
echo -e "  - Redis is not serving critical traffic"
echo ""
echo -e "${RED}This will PERMANENTLY DELETE all keys matching '${PATTERN}'${NC}"
echo -e "${RED}across ${TOTAL_INSTANCES} Redis instances!${NC}"
echo ""
echo -e "Pattern: ${BOLD}${PATTERN}${NC}"
echo -e "Instances:"
for instance in "${REDIS_INSTANCES[@]}"; do
    echo -e "  - ${instance}"
done
echo ""
echo -ne "${YELLOW}Type 'DELETE FAST' (exact match) to confirm: ${NC}"
read -r CONFIRMATION

if [ "$CONFIRMATION" != "DELETE FAST" ]; then
    echo -e "${GREEN}Deletion cancelled.${NC}"
    exit 0
fi

echo ""
echo "======================================="
echo -e "${YELLOW}Deleting keys (ULTRA FAST mode)...${NC}"
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

    echo -ne "[${index}/${TOTAL_INSTANCES}] Processing ${instance} ... "

    # Use KEYS to get all matching keys at once, then delete in batches
    # This is MUCH faster than SCAN but blocks Redis temporarily
    START_TIME=$(date +%s)

    # Get all keys matching pattern using KEYS command
    KEYS_OUTPUT=$(redis-cli -h "$host" -p "$port" KEYS "$PATTERN" 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -ne 0 ] || echo "$KEYS_OUTPUT" | grep -qi "error\|could not connect\|connection refused"; then
        echo -e "${RED}✗ FAILED${NC}"
        echo "    Error: $KEYS_OUTPUT" | head -1
        FAILED_COUNT=$((FAILED_COUNT + 1))
        continue
    fi

    # Count keys
    if [ -n "$KEYS_OUTPUT" ]; then
        KEY_COUNT=$(echo "$KEYS_OUTPUT" | wc -l | tr -d ' ')
    else
        KEY_COUNT=0
    fi

    if [ "$KEY_COUNT" -eq 0 ]; then
        echo -e "${GREEN}✓ SUCCESS${NC} (0 keys)"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        continue
    fi

    # Delete keys in batches using xargs for speed
    # Delete in batches of 1000 keys to avoid command line length limits
    DELETED_COUNT=0
    echo "$KEYS_OUTPUT" | while IFS= read -r key; do
        if [ -n "$key" ]; then
            echo "$key"
        fi
    done | xargs -n 1000 -P 1 redis-cli -h "$host" -p "$port" DEL >/dev/null 2>&1

    DELETED_COUNT=$KEY_COUNT

    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))

    echo -e "${GREEN}✓ SUCCESS${NC} (${DELETED_COUNT} keys in ${ELAPSED}s)"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    TOTAL_DELETED=$((TOTAL_DELETED + DELETED_COUNT))
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
