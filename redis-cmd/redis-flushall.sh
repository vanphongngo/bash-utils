#!/bin/bash

# Redis Cluster FLUSHALL Script
# Deletes ALL data from Redis cluster nodes
# Usage:
#   ./redis-flushall.sh <config_file>
#   ./redis-flushall.sh <ip:port> [<ip:port> ...]

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
REDIS_CLI="${REDIS_CLI:-redis-cli}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"
TIMEOUT_CMD="${TIMEOUT_CMD:-}"

# Auto-detect timeout command
detect_timeout_cmd() {
    if command -v timeout &> /dev/null; then
        TIMEOUT_CMD="timeout"
    elif command -v gtimeout &> /dev/null; then
        TIMEOUT_CMD="gtimeout"
    else
        TIMEOUT_CMD=""
    fi
}

# Usage information
usage() {
    cat << EOF
${BOLD}Usage: $0 [OPTIONS] <input>${NC}

${BOLD}⚠️  WARNING: This script PERMANENTLY DELETES ALL DATA from Redis instances!${NC}

${BOLD}INPUT:${NC}
    <config_file>              File containing Redis nodes (IP:PORT format, one per line)
    <ip:port> [<ip:port> ...]  Direct Redis node addresses

${BOLD}OPTIONS:${NC}
    -h, --help                 Show this help message
    -p, --password PASS        Redis password
    -y, --yes                  Skip confirmation (DANGEROUS!)
    --redis-cli PATH           Path to redis-cli binary (default: redis-cli)
    --timeout SECONDS          Connection timeout in seconds (default: 5)

${BOLD}EXAMPLES:${NC}
    $0 be-ai-redis.txt
    $0 10.50.1.21:9911 10.50.1.21:9912
    $0 -p mypassword be-ai-redis.txt
    $0 -y be-ai-redis.txt  ${YELLOW}# Skip confirmation (DANGEROUS!)${NC}

${BOLD}SAFETY FEATURES:${NC}
    - Requires explicit confirmation before flushing
    - Tests connection to each node first
    - Shows all nodes before flushing
    - Continues on error (won't stop if one instance fails)
    - Color-coded output for easy monitoring

${BOLD}⚠️  DANGER ZONE ⚠️${NC}
    ${RED}FLUSHALL deletes ALL data from Redis - use with extreme caution!${NC}
    ${RED}This operation is IRREVERSIBLE - data cannot be recovered!${NC}

EOF
    exit 1
}

# Parse command line arguments
parse_args() {
    local nodes=()
    local skip_confirm=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -p|--password)
                REDIS_PASSWORD="$2"
                shift 2
                ;;
            -y|--yes)
                skip_confirm=true
                shift
                ;;
            --redis-cli)
                REDIS_CLI="$2"
                shift 2
                ;;
            --timeout)
                TIMEOUT_SECONDS="$2"
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

    # Return nodes and skip_confirm flag
    echo "${skip_confirm}|${nodes[@]}"
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

    # Use timeout if available
    local timeout_prefix=()
    if [[ -n "$TIMEOUT_CMD" ]]; then
        timeout_prefix=("$TIMEOUT_CMD" "5")
    fi

    if ! ${timeout_prefix[@]+"${timeout_prefix[@]}"} "$REDIS_CLI" -h "$host" -p "$port" ${auth_args[@]+"${auth_args[@]}"} PING &>/dev/null; then
        return 1
    fi

    return 0
}

# Get key count from Redis node
get_key_count() {
    local host="$1"
    local port="$2"
    local auth_args=()

    if [[ -n "$REDIS_PASSWORD" ]]; then
        auth_args=(-a "$REDIS_PASSWORD")
    fi

    # Use timeout if available
    local timeout_prefix=()
    if [[ -n "$TIMEOUT_CMD" ]]; then
        timeout_prefix=("$TIMEOUT_CMD" "5")
    fi

    local count
    count=$(${timeout_prefix[@]+"${timeout_prefix[@]}"} "$REDIS_CLI" -h "$host" -p "$port" ${auth_args[@]+"${auth_args[@]}"} DBSIZE 2>/dev/null)

    if [[ "$count" =~ ^[0-9]+$ ]]; then
        echo "$count"
        return 0
    else
        echo "0"
        return 1
    fi
}

# Execute FLUSHALL on a single Redis node
flushall_node() {
    local host="$1"
    local port="$2"
    local auth_args=()

    if [[ -n "$REDIS_PASSWORD" ]]; then
        auth_args=(-a "$REDIS_PASSWORD")
    fi

    # Use timeout if available
    local timeout_prefix=()
    if [[ -n "$TIMEOUT_CMD" ]]; then
        timeout_prefix=("$TIMEOUT_CMD" "10")
    fi

    local result
    result=$(${timeout_prefix[@]+"${timeout_prefix[@]}"} "$REDIS_CLI" -h "$host" -p "$port" ${auth_args[@]+"${auth_args[@]}"} FLUSHALL 2>&1)

    if [[ "$result" == "OK" ]]; then
        return 0
    else
        echo "$result" >&2
        return 1
    fi
}

# Get confirmation from user
get_confirmation() {
    local node_count="$1"
    shift
    local nodes=("$@")

    echo ""
    echo -e "${RED}${BOLD}⚠️  DANGER - DESTRUCTIVE OPERATION ⚠️${NC}"
    echo ""
    echo -e "${RED}This will PERMANENTLY DELETE ALL DATA from ${BOLD}${node_count} Redis instances!${NC}"
    echo -e "${RED}This operation is IRREVERSIBLE and data CANNOT be recovered!${NC}"
    echo ""
    echo -e "${BOLD}Redis instances to be flushed:${NC}"
    for node in "${nodes[@]}"; do
        echo -e "  ${YELLOW}→${NC} $node"
    done
    echo ""
    echo -e "${BOLD}What will happen:${NC}"
    echo -e "  ${RED}✗${NC} ALL keys will be deleted"
    echo -e "  ${RED}✗${NC} ALL data will be permanently lost"
    echo -e "  ${RED}✗${NC} This cannot be undone"
    echo ""
    echo -e "${YELLOW}Type '${BOLD}FLUSH ALL DATA${YELLOW}' (exact match, case-sensitive) to confirm:${NC} "
    read -r confirmation

    if [[ "$confirmation" == "FLUSH ALL DATA" ]]; then
        return 0
    else
        echo -e "${GREEN}Confirmation text did not match. Operation cancelled.${NC}"
        return 1
    fi
}

# Main function
main() {
    local parsed_args
    parsed_args=$(parse_args "$@")

    local skip_confirm
    skip_confirm=$(echo "$parsed_args" | cut -d'|' -f1)

    local input_args
    input_args=$(echo "$parsed_args" | cut -d'|' -f2-)

    check_redis_cli
    detect_timeout_cmd

    echo -e "${CYAN}${BOLD}=======================================${NC}"
    echo -e "${CYAN}${BOLD}Redis Cluster FLUSHALL Script${NC}"
    echo -e "${CYAN}${BOLD}=======================================${NC}"
    echo ""

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

    echo -e "${BOLD}Found ${#nodes[@]} Redis node(s)${NC}"
    echo ""

    # Test connections first
    echo -e "${BOLD}Testing connections...${NC}"
    local reachable_nodes=()
    local failed_nodes=()

    for node in "${nodes[@]}"; do
        local host port
        host=$(echo "$node" | cut -d: -f1)
        port=$(echo "$node" | cut -d: -f2)

        if test_connection "$host" "$port"; then
            echo -e "  ${GREEN}✓${NC} $node - ${GREEN}Connected${NC}"
            reachable_nodes+=("$node")
        else
            echo -e "  ${RED}✗${NC} $node - ${RED}Connection failed${NC}"
            failed_nodes+=("$node")
        fi
    done

    echo ""

    if [[ ${#reachable_nodes[@]} -eq 0 ]]; then
        echo -e "${RED}Error: No Redis nodes are reachable${NC}" >&2
        exit 1
    fi

    if [[ ${#failed_nodes[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Warning: ${#failed_nodes[@]} node(s) could not be reached and will be skipped${NC}"
        echo ""
    fi

    # Get confirmation unless -y flag is set
    if [[ "$skip_confirm" != "true" ]]; then
        if ! get_confirmation "${#reachable_nodes[@]}" "${reachable_nodes[@]}"; then
            exit 0
        fi
    else
        echo -e "${YELLOW}⚠️  Skipping confirmation (-y flag set)${NC}"
    fi

    echo ""
    echo -e "${CYAN}${BOLD}=======================================${NC}"
    echo -e "${CYAN}${BOLD}Executing FLUSHALL...${NC}"
    echo -e "${CYAN}${BOLD}=======================================${NC}"
    echo ""

    # Execute FLUSHALL on each reachable node
    local success_count=0
    local error_count=0
    local total_keys_deleted=0
    local index=1

    for node in "${reachable_nodes[@]}"; do
        local host port
        host=$(echo "$node" | cut -d: -f1)
        port=$(echo "$node" | cut -d: -f2)

        # Get key count before flushing
        local key_count
        key_count=$(get_key_count "$host" "$port")

        echo -ne "[${index}/${#reachable_nodes[@]}] Flushing ${BOLD}$node${NC} ... "

        if flushall_node "$host" "$port"; then
            echo -e "${GREEN}✓ SUCCESS${NC} (${CYAN}${key_count} keys deleted${NC})"
            success_count=$((success_count + 1))
            total_keys_deleted=$((total_keys_deleted + key_count))
        else
            echo -e "${RED}✗ FAILED${NC}"
            error_count=$((error_count + 1))
        fi

        index=$((index + 1))
    done

    # Summary
    echo ""
    echo -e "${CYAN}${BOLD}=======================================${NC}"
    echo -e "${CYAN}${BOLD}FLUSHALL Complete${NC}"
    echo -e "${CYAN}${BOLD}=======================================${NC}"
    echo -e "  ${BOLD}Total nodes:${NC}     ${#nodes[@]}"
    echo -e "  ${BOLD}Reachable:${NC}       ${#reachable_nodes[@]}"
    echo -e "  ${BOLD}Unreachable:${NC}     ${#failed_nodes[@]}"
    echo -e "  ${GREEN}${BOLD}Success:${NC}         $success_count"
    if [[ $error_count -gt 0 ]]; then
        echo -e "  ${RED}${BOLD}Failed:${NC}          $error_count"
    fi
    echo -e "  ${YELLOW}${BOLD}Keys deleted:${NC}    $total_keys_deleted"
    echo -e "${CYAN}${BOLD}=======================================${NC}"

    if [[ $error_count -gt 0 ]]; then
        exit 1
    fi
}

# Run main function
main "$@"
