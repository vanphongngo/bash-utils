#!/bin/bash

# Redis Cluster Key Listing Script
# Lists all keys from Redis cluster nodes
# Usage:
#   ./redis-list-keys.sh <config_file>
#   ./redis-list-keys.sh <ip:port> [<ip:port> ...]

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REDIS_CLI="${REDIS_CLI:-redis-cli}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"
OUTPUT_DIR="${OUTPUT_DIR:-./redis-keys-output}"
SCAN_COUNT="${SCAN_COUNT:-1000}"

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS] <input>

List all keys from Redis cluster nodes.

INPUT:
    <config_file>              File containing Redis nodes (IP:PORT format, one per line)
    <ip:port> [<ip:port> ...]  Direct Redis node addresses

OPTIONS:
    -h, --help                 Show this help message
    -o, --output-dir DIR       Output directory (default: ./redis-keys-output)
    -p, --password PASS        Redis password
    -c, --count NUM            SCAN count parameter (default: 1000)
    --redis-cli PATH           Path to redis-cli binary (default: redis-cli)

EXAMPLES:
    $0 be-ai-redis.txt
    $0 10.50.1.21:9911 10.50.1.21:9912
    $0 -p mypassword -o /tmp/output be-ai-redis.txt

OUTPUT:
    Keys are written to: \$OUTPUT_DIR/redis-keys-<timestamp>.txt

EOF
    exit 1
}

# Parse command line arguments
parse_args() {
    local nodes=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -o|--output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -p|--password)
                REDIS_PASSWORD="$2"
                shift 2
                ;;
            -c|--count)
                SCAN_COUNT="$2"
                shift 2
                ;;
            --redis-cli)
                REDIS_CLI="$2"
                shift 2
                ;;
            -*)
                echo -e "${RED}Error: Unknown option $1${NC}" >&2
                usage
                ;;
            *)
                nodes+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#nodes[@]} -eq 0 ]]; then
        echo -e "${RED}Error: No input provided${NC}" >&2
        usage
    fi

    echo "${nodes[@]}"
}

# Check if redis-cli is available
check_redis_cli() {
    if ! command -v "$REDIS_CLI" &> /dev/null; then
        echo -e "${RED}Error: redis-cli not found at '$REDIS_CLI'${NC}" >&2
        echo "Please install redis-cli or set REDIS_CLI environment variable" >&2
        exit 1
    fi
}

# Parse Redis nodes from file
parse_nodes_from_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo -e "${RED}Error: File not found: $file${NC}" >&2
        exit 1
    fi

    # Extract IP:PORT patterns from file
    grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+' "$file" || {
        echo -e "${RED}Error: No valid Redis nodes found in $file${NC}" >&2
        exit 1
    }
}

# Validate node format
validate_node() {
    local node="$1"

    if [[ ! "$node" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$ ]]; then
        echo -e "${YELLOW}Warning: Invalid node format: $node (expected IP:PORT)${NC}" >&2
        return 1
    fi

    return 0
}

# Test Redis connection
test_connection() {
    local host="$1"
    local port="$2"
    local auth_args=()

    if [[ -n "$REDIS_PASSWORD" ]]; then
        auth_args=(-a "$REDIS_PASSWORD")
    fi

    if ! "$REDIS_CLI" -h "$host" -p "$port" ${auth_args[@]+"${auth_args[@]}"} PING &>/dev/null; then
        return 1
    fi

    return 0
}

# Scan keys from a single Redis node
scan_keys_from_node() {
    local host="$1"
    local port="$2"
    local output_file="$3"
    local auth_args=()

    if [[ -n "$REDIS_PASSWORD" ]]; then
        auth_args=(-a "$REDIS_PASSWORD")
    fi

    echo -e "${GREEN}Scanning keys from $host:$port...${NC}"

    local cursor=0
    local keys_count=0
    local temp_file
    temp_file=$(mktemp)

    # Use SCAN to iterate through keys (safer than KEYS *)
    while true; do
        # Execute SCAN command
        local result
        result=$("$REDIS_CLI" -h "$host" -p "$port" ${auth_args[@]+"${auth_args[@]}"} \
            SCAN "$cursor" COUNT "$SCAN_COUNT" 2>/dev/null || echo "ERROR")

        if [[ "$result" == "ERROR" ]]; then
            echo -e "${RED}Error scanning $host:$port${NC}" >&2
            rm -f "$temp_file"
            return 1
        fi

        # Parse cursor and keys from result
        cursor=$(echo "$result" | head -n 1)
        local keys
        keys=$(echo "$result" | tail -n +2)

        if [[ -n "$keys" ]]; then
            echo "$keys" >> "$temp_file"
            keys_count=$((keys_count + $(echo "$keys" | wc -l)))
        fi

        # Break if cursor is 0 (scan complete)
        if [[ "$cursor" == "0" ]]; then
            break
        fi
    done

    # Append to output file with node header
    {
        echo "=== Keys from $host:$port ==="
        if [[ -f "$temp_file" && -s "$temp_file" ]]; then
            cat "$temp_file"
        else
            echo "(no keys found)"
        fi
        echo ""
    } >> "$output_file"

    rm -f "$temp_file"

    echo -e "${GREEN}Found $keys_count keys from $host:$port${NC}"
    return 0
}

# Main function
main() {
    local input_args
    input_args=$(parse_args "$@")

    check_redis_cli

    # Create output directory
    mkdir -p "$OUTPUT_DIR"

    # Generate output filename with timestamp
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local output_file="$OUTPUT_DIR/redis-keys-$timestamp.txt"

    echo -e "${GREEN}Redis Cluster Key Listing${NC}"
    echo "Output file: $output_file"
    echo ""

    # Initialize output file
    {
        echo "Redis Cluster Keys Listing"
        echo "Generated: $(date)"
        echo "Scan Count: $SCAN_COUNT"
        echo ""
    } > "$output_file"

    # Collect Redis nodes
    local nodes=()
    for arg in $input_args; do
        if [[ -f "$arg" ]]; then
            # Input is a file
            echo -e "${GREEN}Reading nodes from file: $arg${NC}"
            while IFS= read -r node; do
                if [[ -n "$node" ]] && validate_node "$node"; then
                    nodes+=("$node")
                fi
            done < <(parse_nodes_from_file "$arg")
        elif validate_node "$arg"; then
            # Input is a direct node address
            nodes+=("$arg")
        fi
    done

    if [[ ${#nodes[@]} -eq 0 ]]; then
        echo -e "${RED}Error: No valid Redis nodes found${NC}" >&2
        exit 1
    fi

    echo -e "${GREEN}Found ${#nodes[@]} Redis node(s)${NC}"
    echo ""

    # Process each node
    local success_count=0
    local failed_count=0

    for node in "${nodes[@]}"; do
        local host port
        host=$(echo "$node" | cut -d: -f1)
        port=$(echo "$node" | cut -d: -f2)

        # Test connection first
        if ! test_connection "$host" "$port"; then
            echo -e "${RED}Failed to connect to $host:$port${NC}" >&2
            {
                echo "=== Keys from $host:$port ==="
                echo "(connection failed)"
                echo ""
            } >> "$output_file"
            failed_count=$((failed_count + 1))
            continue
        fi

        # Scan keys
        if scan_keys_from_node "$host" "$port" "$output_file"; then
            success_count=$((success_count + 1))
        else
            failed_count=$((failed_count + 1))
        fi
    done

    # Summary
    echo ""
    echo -e "${GREEN}=== Summary ===${NC}"
    echo "Total nodes: ${#nodes[@]}"
    echo -e "${GREEN}Successful: $success_count${NC}"
    if [[ $failed_count -gt 0 ]]; then
        echo -e "${RED}Failed: $failed_count${NC}"
    fi
    echo "Output file: $output_file"

    # Append summary to output file
    {
        echo "=== Summary ==="
        echo "Total nodes processed: ${#nodes[@]}"
        echo "Successful: $success_count"
        echo "Failed: $failed_count"
        echo "Completed: $(date)"
    } >> "$output_file"

    if [[ $failed_count -gt 0 ]]; then
        exit 1
    fi
}

# Run main function
main "$@"
