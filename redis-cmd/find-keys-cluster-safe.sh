#!/bin/bash

# Redis Cluster Key Finder Script (Production-Safe with SCAN)
# Finds all keys matching a pattern across multiple Redis instances using SCAN
# Usage: ./find-keys-cluster-safe.sh <redis-info-file> <pattern> [output-file]

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
PATTERN="${2:-*}"
OUTPUT_FILE="${3:-redis-keys-$(date +%Y%m%d-%H%M%S).txt}"
SCAN_COUNT=1000  # Number of keys to scan per iteration

# Check if redis-cli is installed
if ! command -v redis-cli &> /dev/null; then
    echo -e "${RED}Error: redis-cli is not installed${NC}"
    exit 1
fi

# Detect timeout command
TIMEOUT_CMD=""
if command -v timeout &> /dev/null; then
    TIMEOUT_CMD="timeout 10"
elif command -v gtimeout &> /dev/null; then
    TIMEOUT_CMD="gtimeout 10"
fi

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <redis-info-file> [pattern] [output-file]"
    echo ""
    echo "Arguments:"
    echo "  redis-info-file  - File containing Redis instances (IP:PORT format)"
    echo "  pattern          - Key pattern to search (default: *)"
    echo "  output-file      - Output file for results (default: redis-keys-TIMESTAMP.txt)"
    echo ""
    echo "Examples:"
    echo "  $0 user-redis-info.txt"
    echo "  $0 user-redis-info.txt 'user:*'"
    echo "  $0 user-redis-info.txt 'session:*' output.txt"
    echo ""
    echo "Note: This script uses SCAN (production-safe, non-blocking)"
    exit 1
fi

REDIS_INFO_FILE="$1"

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
SUCCESS_COUNT=0
FAILED_COUNT=0
TOTAL_KEYS=0

# Clear output file
> "$OUTPUT_FILE"

echo "======================================="
echo "Redis Cluster Key Finder (SCAN)"
echo "======================================="
echo -e "Pattern:       ${BLUE}${PATTERN}${NC}"
echo -e "Output file:   ${BLUE}${OUTPUT_FILE}${NC}"
echo -e "Instances:     ${BLUE}${TOTAL_INSTANCES}${NC}"
echo -e "Method:        ${GREEN}SCAN${NC} ${CYAN}(production-safe, non-blocking)${NC}"
echo -e "Scan count:    ${BLUE}${SCAN_COUNT}${NC}"
echo "======================================="
echo ""

# Function to get keys using SCAN
get_keys_scan() {
    local host=$1
    local port=$2
    local pattern=$3

    if [ -n "$TIMEOUT_CMD" ]; then
        $TIMEOUT_CMD redis-cli -h "$host" -p "$port" --scan --pattern "$pattern" 2>&1
    else
        redis-cli -h "$host" -p "$port" --scan --pattern "$pattern" 2>&1
    fi
}

# Process each Redis instance
for i in "${!REDIS_INSTANCES[@]}"; do
    instance="${REDIS_INSTANCES[$i]}"
    index=$((i + 1))

    # Parse host and port
    IFS=':' read -r host port <<< "$instance"

    echo -ne "[${index}/${TOTAL_INSTANCES}] Scanning ${instance} ... "

    # Get keys using SCAN
    RESULT=$(get_keys_scan "$host" "$port" "$PATTERN")
    EXIT_CODE=$?

    # Check for errors
    if [ $EXIT_CODE -ne 0 ] || echo "$RESULT" | grep -qi "error\|could not connect\|connection refused\|timeout"; then
        echo -e "${RED}✗ FAILED${NC}"
        echo "    Error: $RESULT" | head -1
        FAILED_COUNT=$((FAILED_COUNT + 1))
        continue
    fi

    # Count keys
    if [ -n "$RESULT" ]; then
        KEY_COUNT=$(echo "$RESULT" | wc -l | tr -d ' ')
    else
        KEY_COUNT=0
    fi

    echo -e "${GREEN}✓ SUCCESS${NC} (${KEY_COUNT} keys)"

    # Write to output file
    if [ -n "$RESULT" ]; then
        echo "# Instance: ${instance}" >> "$OUTPUT_FILE"
        echo "$RESULT" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        TOTAL_KEYS=$((TOTAL_KEYS + KEY_COUNT))
    fi

    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
done

echo ""
echo "======================================="
echo "Summary:"
echo "  Total instances: ${TOTAL_INSTANCES}"
echo -e "  Success:         ${GREEN}${SUCCESS_COUNT}${NC}"
echo -e "  Failed:          ${RED}${FAILED_COUNT}${NC}"
echo -e "  Total keys:      ${BLUE}${TOTAL_KEYS}${NC}"
echo "  Output file:     ${OUTPUT_FILE}"
echo "======================================="

# Show preview
if [ $TOTAL_KEYS -gt 0 ]; then
    echo ""
    echo "Preview (first 10 keys):"
    echo "---------------------------------------"
    grep -v '^#' "$OUTPUT_FILE" | grep -v '^[[:space:]]*$' | head -10
    if [ $TOTAL_KEYS -gt 10 ]; then
        echo "..."
        echo "(${TOTAL_KEYS} total keys in ${OUTPUT_FILE})"
    fi
fi

exit 0
