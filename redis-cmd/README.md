# Redis Cluster Management Scripts

Scripts to manage multiple Redis instances across clusters.

## Files

### Key Management Scripts
- `redis-list-keys.sh` - **NEW!** List all keys from Redis cluster (SCAN - production-safe, flexible input)
- `count-keys-cluster.sh` - Count keys matching a pattern (read-only, safe)
- `find-keys-cluster.sh` - Find keys across all clusters (KEYS command - fast)
- `find-keys-cluster-safe.sh` - Find keys across all clusters (SCAN command - production-safe)
- `delete-keys-cluster.sh` - Delete keys with counting first (SCAN - safest, shows count)
- `delete-keys-cluster-fast.sh` - Delete keys without counting (SCAN - faster, no count step)
- `delete-keys-cluster-ultrafast.sh` - Delete keys ultra fast (KEYS - 10-40x faster, blocks Redis!)

### Flush Scripts
- `redis-flushall.sh` - **NEW!** FLUSHALL with flexible input (file or direct args, production-ready)
- `flush-redis-cluster.sh` - Basic version (reads from stdin)
- `flush-redis-cluster-safe.sh` - Safe version with confirmation prompt

### Configuration
- `user-redis-info.txt` - Example Redis instance list

## Usage

---

## 📋 Key Listing Script (NEW!)

### Quick Start

**List all keys from Redis cluster:**
```bash
# Using configuration file
./redis-list-keys.sh be-ai-redis.txt

# Using direct IP:PORT arguments
./redis-list-keys.sh 10.50.1.21:9911 10.50.1.21:9912 10.50.1.21:9913

# With password authentication
./redis-list-keys.sh -p mypassword be-ai-redis.txt

# Custom output directory
./redis-list-keys.sh -o /tmp/redis-keys be-ai-redis.txt
```

### Features

- ✅ **Flexible input** - File path OR direct IP:PORT arguments
- ✅ **Production-safe** - Uses SCAN command (non-blocking)
- ✅ **Password support** - Redis AUTH authentication
- ✅ **Timestamped output** - Auto-generated filenames
- ✅ **Connection testing** - Tests before scanning
- ✅ **Progress tracking** - Shows keys found per node
- ✅ **Error resilient** - Continues even if some nodes fail
- ✅ **Configurable** - Custom scan count, output directory

### Command Options

```bash
./redis-list-keys.sh [OPTIONS] <input>

OPTIONS:
  -h, --help                 Show help message
  -o, --output-dir DIR       Output directory (default: ./redis-keys-output)
  -p, --password PASS        Redis password
  -c, --count NUM            SCAN count parameter (default: 1000)
  --redis-cli PATH           Path to redis-cli binary
```

### Usage Examples

```bash
# Basic usage with config file
./redis-list-keys.sh be-ai-redis.txt

# Multiple Redis nodes directly
./redis-list-keys.sh 10.50.1.21:9911 10.50.1.21:9912 10.50.1.21:9913

# With authentication
./redis-list-keys.sh -p "myRedisPassword" be-ai-redis.txt

# Custom output location
./redis-list-keys.sh -o /var/log/redis-keys be-ai-redis.txt

# Large cluster with high scan count
./redis-list-keys.sh -c 5000 be-ai-redis.txt

# All options combined
./redis-list-keys.sh -p mypass -o ./output -c 2000 be-ai-redis.txt
```

### Environment Variables

```bash
# Set defaults via environment variables
export REDIS_PASSWORD="mypassword"
export OUTPUT_DIR="/var/log/redis-keys"
export SCAN_COUNT=5000
export REDIS_CLI="/opt/redis/bin/redis-cli"

# Then run without options
./redis-list-keys.sh be-ai-redis.txt
```

### Example Output

```
Redis Cluster Key Listing
Output file: ./redis-keys-output/redis-keys-20260106_161545.txt

Reading nodes from file: be-ai-redis.txt
Found 3 Redis node(s)

Scanning keys from 10.50.1.21:9911...
Found 1523 keys from 10.50.1.21:9911
Scanning keys from 10.50.1.21:9912...
Found 2047 keys from 10.50.1.21:9912
Scanning keys from 10.50.1.21:9913...
Found 891 keys from 10.50.1.21:9913

=== Summary ===
Total nodes: 3
Successful: 3
Failed: 0
Output file: ./redis-keys-output/redis-keys-20260106_161545.txt
```

### Output File Format

```
Redis Cluster Keys Listing
Generated: Mon Jan  6 16:15:45 PST 2026
Scan Count: 1000

=== Keys from 10.50.1.21:9911 ===
user:1001
user:1002
session:abc123
cache:data:xyz
...

=== Keys from 10.50.1.21:9912 ===
product:123
product:456
...

=== Summary ===
Total nodes processed: 3
Successful: 3
Failed: 0
Completed: Mon Jan  6 16:16:12 PST 2026
```

### When to Use

- ✅ Need complete key inventory across cluster
- ✅ Audit and documentation purposes
- ✅ Migration planning (know what keys exist)
- ✅ Pattern analysis (understand key structure)
- ✅ Troubleshooting (find unexpected keys)
- ✅ Backup key lists before major operations

### Performance

**SCAN-based (Production-Safe):**
- Non-blocking operation
- Safe for production use
- Configurable batch size (`-c` option)
- Time: ~1-5 minutes per million keys

**Speed Optimization:**
```bash
# Faster (larger batches)
./redis-list-keys.sh -c 10000 be-ai-redis.txt

# Safer (smaller batches, less memory)
./redis-list-keys.sh -c 100 be-ai-redis.txt
```

---

## 🗑️ Redis FLUSHALL Script (NEW!)

### Quick Start

**⚠️ EXTREME DANGER - This deletes ALL data from Redis!**

```bash
# Using configuration file
./redis-flushall.sh be-ai-redis.txt

# Using direct IP:PORT arguments
./redis-flushall.sh 10.50.1.21:9911 10.50.1.21:9912 10.50.1.21:9913

# With password authentication
./redis-flushall.sh -p mypassword be-ai-redis.txt

# Skip confirmation (DANGEROUS!)
./redis-flushall.sh -y be-ai-redis.txt
```

### Features

- ✅ **Flexible input** - File path OR direct IP:PORT arguments
- ✅ **Maximum safety** - Requires typing "FLUSH ALL DATA" to confirm
- ✅ **Connection testing** - Tests connections before flushing
- ✅ **Password support** - Redis AUTH authentication
- ✅ **Key count tracking** - Shows keys deleted per node and total
- ✅ **Error resilient** - Continues even if some nodes fail
- ✅ **Color-coded output** - Clear visual feedback
- ✅ **Timeout protection** - Auto-detects timeout command
- ✅ **Detailed warnings** - Multiple safety warnings before execution

### Safety Features

This is the **MOST DANGEROUS** script in this collection. It includes multiple safety layers:

1. **Explicit confirmation required** - Must type "FLUSH ALL DATA" exactly
2. **Connection testing first** - Verifies all nodes are reachable
3. **Shows all targets** - Lists every Redis instance before flushing
4. **Clear warnings** - Multiple warnings about data loss
5. **Skip confirmation flag** - Must use `-y` explicitly to bypass
6. **No silent failures** - All errors are reported

### Command Options

```bash
./redis-flushall.sh [OPTIONS] <input>

OPTIONS:
  -h, --help                 Show help message
  -p, --password PASS        Redis password
  -y, --yes                  Skip confirmation (DANGEROUS!)
  --redis-cli PATH           Path to redis-cli binary
  --timeout SECONDS          Connection timeout (default: 5)
```

### Usage Examples

```bash
# Safe usage with confirmation
./redis-flushall.sh be-ai-redis.txt

# Multiple Redis nodes directly
./redis-flushall.sh 10.50.1.21:9911 10.50.1.21:9912 10.50.1.21:9913

# With authentication
./redis-flushall.sh -p "myRedisPassword" be-ai-redis.txt

# Automated (skip confirmation) - USE WITH EXTREME CAUTION!
./redis-flushall.sh -y be-ai-redis.txt

# Mixed: file and direct nodes
./redis-flushall.sh be-ai-redis.txt 10.50.1.22:9911
```

### Environment Variables

```bash
# Set defaults via environment variables
export REDIS_PASSWORD="mypassword"
export REDIS_CLI="/opt/redis/bin/redis-cli"

# Then run
./redis-flushall.sh be-ai-redis.txt
```

### Example Output

```
=======================================
Redis Cluster FLUSHALL Script
=======================================

Reading nodes from file: be-ai-redis.txt
Found 3 Redis node(s)

Testing connections...
  ✓ 10.50.1.21:9911 - Connected
  ✓ 10.50.1.21:9912 - Connected
  ✓ 10.50.1.21:9913 - Connected


⚠️  DANGER - DESTRUCTIVE OPERATION ⚠️

This will PERMANENTLY DELETE ALL DATA from 3 Redis instances!
This operation is IRREVERSIBLE and data CANNOT be recovered!

Redis instances to be flushed:
  → 10.50.1.21:9911
  → 10.50.1.21:9912
  → 10.50.1.21:9913

What will happen:
  ✗ ALL keys will be deleted
  ✗ ALL data will be permanently lost
  ✗ This cannot be undone

Type 'FLUSH ALL DATA' (exact match, case-sensitive) to confirm: FLUSH ALL DATA

=======================================
Executing FLUSHALL...
=======================================

[1/3] Flushing 10.50.1.21:9911 ... ✓ SUCCESS (1523 keys deleted)
[2/3] Flushing 10.50.1.21:9912 ... ✓ SUCCESS (2047 keys deleted)
[3/3] Flushing 10.50.1.21:9913 ... ✓ SUCCESS (891 keys deleted)

=======================================
FLUSHALL Complete
=======================================
  Total nodes:     3
  Reachable:       3
  Unreachable:     0
  Success:         3
  Keys deleted:    4461
=======================================
```

### When to Use

- ✅ Development/test environment cleanup
- ✅ Before database migration
- ✅ Removing all data before rebuild
- ✅ Emergency data wipe scenarios
- ❌ **NEVER** use on production without backups!
- ❌ **NEVER** use without understanding consequences!

### Safety Checklist

Before running this script, verify:

- [ ] You have backups (if data is important)
- [ ] You are targeting the correct Redis instances
- [ ] You understand all data will be permanently deleted
- [ ] You have authorization to delete this data
- [ ] You are not in production (or have maintenance window)
- [ ] You have tested the command on a single node first

### Comparison with Other Flush Scripts

| Script | Input Method | Confirmation | Best For |
|--------|--------------|--------------|----------|
| `redis-flushall.sh` | File OR args | Required | **Production-ready, flexible** |
| `flush-redis-cluster-safe.sh` | File only | Required | Basic safety |
| `flush-redis-cluster.sh` | stdin | No | Pipe workflows |

### Recovery

**IMPORTANT:** FLUSHALL is irreversible! To recover data:
1. You **MUST** have backups (RDB/AOF snapshots)
2. Stop Redis
3. Copy backup files to Redis data directory
4. Restart Redis

**If you don't have backups, data is permanently lost!**

---

## ⚡ Ultra-Fast Key Deletion (KEYS Command)

### Quick Start

**⚠️ ULTRA-FAST MODE - Blocks Redis but 10-40x faster!**

```bash
./delete-keys-cluster-ultrafast.sh user-redis-info.txt 'QC|MG|USER|USER_SEGMENT|*'
```

### Why So Fast?

The ultra-fast script uses `KEYS` command instead of `SCAN`:

| Method | How It Works | Speed | Blocks Redis? |
|--------|--------------|-------|---------------|
| **SCAN** | Iterates through keyspace cursor-by-cursor | Slow (20-40 min) | ❌ No |
| **KEYS** | Returns all matching keys immediately | Fast (1-3 min) | ✅ YES! |

**Speed improvement: 10-40x faster!** 🚀

### When to Use Ultra-Fast Mode

✅ **USE when:**
- Dev/test environment
- Maintenance window
- Redis is not serving critical traffic
- You need maximum speed

❌ **DON'T USE when:**
- Production environment with active traffic
- Redis is serving critical requests
- Can't afford 1-5 second blocking per instance

### Speed Comparison Table

For ~7.8M keys across 6 instances:

| Script | Method | Time | Blocks? | Best For |
|--------|--------|------|---------|----------|
| `delete-keys-cluster.sh` | SCAN + count | 23-45 min | ❌ No | Maximum safety |
| `delete-keys-cluster-fast.sh` | SCAN only | 20-40 min | ❌ No | Production use |
| `delete-keys-cluster-ultrafast.sh` | KEYS | 1-3 min | ✅ Yes | Dev/maintenance |

### Safety Features

- ✅ Requires typing `DELETE FAST` (not just `DELETE`)
- ✅ Shows all instances before deletion
- ✅ Shows elapsed time per instance
- ✅ Batch deletion to avoid command line limits
- ⚠️ **Blocks Redis** during KEYS operation (1-5 seconds per million keys)

### Example Output

```
=======================================
Redis Cluster Key Deletion (ULTRA FAST)
=======================================
Pattern:       QC|MG|USER|USER_SEGMENT|*
Instances:     6
Mode:          KEYS command (BLOCKS Redis!)
=======================================

⚠️  DANGER - ULTRA FAST MODE ⚠️
This uses KEYS command which BLOCKS Redis during execution!

What this means:
  - ✅ EXTREMELY FAST (10-100x faster than SCAN)
  - ❌ BLOCKS Redis during key retrieval (1-5 seconds per million keys)
  - ⚠️  Redis cannot serve other requests while KEYS is running

Only use this if:
  - This is a dev/test environment, OR
  - You are in a maintenance window, OR
  - Redis is not serving critical traffic

This will PERMANENTLY DELETE all keys matching 'QC|MG|USER|USER_SEGMENT|*'
across 6 Redis instances!

Pattern: QC|MG|USER|USER_SEGMENT|*
Instances:
  - 10.50.1.22:9315
  - 10.50.1.20:9319
  - 10.50.1.20:9315
  - 10.50.1.21:9315
  - 10.50.1.21:9319
  - 10.50.1.22:9319

Type 'DELETE FAST' (exact match) to confirm: DELETE FAST

=======================================
Deleting keys (ULTRA FAST mode)...
=======================================

[1/6] Processing 10.50.1.22:9315 ... ✓ SUCCESS (1310019 keys in 8s)
[2/6] Processing 10.50.1.20:9319 ... ✓ SUCCESS (1298456 keys in 7s)
[3/6] Processing 10.50.1.20:9315 ... ✓ SUCCESS (1305123 keys in 8s)
[4/6] Processing 10.50.1.21:9315 ... ✓ SUCCESS (1289901 keys in 7s)
[5/6] Processing 10.50.1.21:9319 ... ✓ SUCCESS (1312045 keys in 8s)
[6/6] Processing 10.50.1.22:9319 ... ✓ SUCCESS (1301234 keys in 8s)

=======================================
Deletion Complete
=======================================
  Total instances: 6
  Success:         6
  Failed:          0
  Keys deleted:    7816778
=======================================

Total time: ~46 seconds vs 20-40 minutes with SCAN!
```

### Technical Details

**KEYS vs SCAN:**

```bash
# SCAN (safe but slow)
redis-cli --scan --pattern 'QC|MG|USER|*'
# Iterates through entire keyspace
# Time: O(N) where N = total keys in database

# KEYS (fast but blocks)
redis-cli KEYS 'QC|MG|USER|*'
# Returns all matches immediately
# Time: O(N) but much faster constant factor
# Blocks: Yes (1-5 seconds per million keys)
```

**Why KEYS is faster:**
- Returns all matches in one operation
- No cursor iteration overhead
- More efficient pattern matching
- But blocks Redis from serving other requests

---

## Key Counter Script

### Quick Start

**Count keys matching a pattern:**
```bash
./count-keys-cluster.sh user-redis-info.txt 'QC|ZPP|TASK*'
```

### Features

- ✅ **Read-only operation** - Safe to run anytime, no data modification
- ✅ **Fast counting** - Uses SCAN to count keys efficiently
- ✅ **Multi-cluster support** - Counts across all Redis instances
- ✅ **Pattern matching** - Supports Redis glob patterns
- ✅ **Helpful estimates** - Shows time estimates for large datasets

### Usage Examples

```bash
# Count all keys
./count-keys-cluster.sh user-redis-info.txt '*'

# Count user keys
./count-keys-cluster.sh user-redis-info.txt 'user:*'

# Count session keys
./count-keys-cluster.sh user-redis-info.txt 'session:*'

# Count with complex pattern
./count-keys-cluster.sh user-redis-info.txt 'QC|ZPP|TASK*'
```

### Example Output

```
=======================================
Redis Cluster Key Counter
=======================================
Pattern:       QC|ZPP|TASK*
Instances:     6
=======================================

[1/6] Counting keys on 10.50.1.22:9315 ... ✓ 1310019 keys
[2/6] Counting keys on 10.50.1.20:9319 ... ✓ 1298456 keys
[3/6] Counting keys on 10.50.1.20:9315 ... ✓ 1305123 keys
[4/6] Counting keys on 10.50.1.21:9315 ... ✓ 1289901 keys
[5/6] Counting keys on 10.50.1.21:9319 ... ✓ 1312045 keys
[6/6] Counting keys on 10.50.1.22:9319 ... ✓ 1301234 keys

=======================================
Summary:
  Total instances: 6
  Success:         6
  Failed:          0
  Total keys:      7816778
=======================================

Note: Large dataset detected (7816778 keys)
  - Finding all keys may take 15-30 minutes
  - Deleting all keys may take 20-40 minutes
  - Consider using more specific patterns to reduce scope
```

---

## Key Deletion Script

### Quick Start

**⚠️ DANGER ZONE - This deletes data!**

```bash
./delete-keys-cluster.sh user-redis-info.txt 'temp:*'
```

### Safety Features

- ✅ **Two-step process** - Counts first, then asks for confirmation
- ✅ **Explicit confirmation** - Must type 'DELETE' in uppercase to proceed
- ✅ **Shows what will be deleted** - Displays count per instance before deletion
- ✅ **Production-safe** - Uses SCAN (non-blocking)
- ✅ **Progress tracking** - Shows deletion progress for large datasets
- ✅ **Error resilient** - Continues even if some instances fail

### Usage Examples

```bash
# Delete temporary keys
./delete-keys-cluster.sh user-redis-info.txt 'temp:*'

# Delete expired sessions
./delete-keys-cluster.sh user-redis-info.txt 'session:expired:*'

# Delete old cache entries
./delete-keys-cluster.sh user-redis-info.txt 'cache:old:*'

# Delete specific pattern
./delete-keys-cluster.sh user-redis-info.txt 'QC|ZPP|TASK|PENDING*'
```

### Example Output

```
=======================================
Redis Cluster Key Deletion
=======================================
Pattern:       temp:*
Instances:     6
=======================================

Step 1: Counting keys to delete...

[1/6] Counting keys on 10.50.1.22:9315 ... 1523 keys
[2/6] Counting keys on 10.50.1.20:9319 ... 1487 keys
[3/6] Counting keys on 10.50.1.20:9315 ... 1501 keys
[4/6] Counting keys on 10.50.1.21:9315 ... 0 keys
[5/6] Counting keys on 10.50.1.21:9319 ... 1498 keys
[6/6] Counting keys on 10.50.1.22:9319 ... 1512 keys

=======================================
Summary:
  Total keys to delete: 7521
=======================================

⚠️  WARNING ⚠️
This will PERMANENTLY DELETE 7521 keys across 6 Redis instances!

Pattern: temp:*

Keys per instance:
  10.50.1.22:9315: 1523 keys
  10.50.1.20:9319: 1487 keys
  10.50.1.20:9315: 1501 keys
  10.50.1.21:9319: 1498 keys
  10.50.1.22:9319: 1512 keys

Type 'DELETE' (in uppercase) to confirm deletion: DELETE

=======================================
Step 2: Deleting keys...
=======================================

[1/6] Deleting from 10.50.1.22:9315 ... ✓ SUCCESS (1523 keys deleted)
[2/6] Deleting from 10.50.1.20:9319 ... ✓ SUCCESS (1487 keys deleted)
[3/6] Deleting from 10.50.1.20:9315 ... ✓ SUCCESS (1501 keys deleted)
[4/6] Deleting from 10.50.1.21:9319 ... ✓ SUCCESS (1498 keys deleted)
[5/6] Deleting from 10.50.1.22:9319 ... ✓ SUCCESS (1512 keys deleted)

=======================================
Deletion Complete
=======================================
  Total instances: 6
  Success:         5
  Failed:          0
  Keys deleted:    7521
=======================================
```

### Best Practices

1. **Always count first:**
   ```bash
   # Step 1: Count to see how many keys match
   ./count-keys-cluster.sh user-redis-info.txt 'pattern:*'

   # Step 2: If count looks correct, delete
   ./delete-keys-cluster.sh user-redis-info.txt 'pattern:*'
   ```

2. **Test pattern on one instance first:**
   ```bash
   # Test pattern directly on one Redis instance
   redis-cli -h 10.50.1.22 -p 9315 --scan --pattern 'your:pattern:*' | head -10

   # If pattern is correct, run cluster-wide deletion
   ./delete-keys-cluster.sh user-redis-info.txt 'your:pattern:*'
   ```

3. **Use specific patterns:**
   - ❌ Bad: `'*'` (deletes everything!)
   - ❌ Risky: `'user:*'` (might delete more than intended)
   - ✅ Good: `'user:temp:*'` (specific subset)
   - ✅ Better: `'user:session:expired:2024:*'` (very specific)

---

## Fast Key Deletion Script (No Counting)

### Quick Start

**⚠️ FAST MODE - Deletes immediately without counting!**

```bash
./delete-keys-cluster-fast.sh user-redis-info.txt 'temp:*'
```

### When to Use Fast Mode

Use the fast deletion script when:
- ✅ You already know how many keys exist (used count script earlier)
- ✅ You don't care about the exact count
- ✅ You want maximum speed
- ✅ The pattern is very specific and safe

### Differences from Regular Delete

| Feature | Regular Delete | Fast Delete |
|---------|---------------|-------------|
| Count keys first | ✅ Yes | ❌ No |
| Show count before delete | ✅ Yes | ❌ No |
| Speed | Slower (counts + deletes) | Faster (deletes only) |
| Safety | Safer (see count first) | Less safe |
| Confirmation required | ✅ Yes | ✅ Yes |
| Progress tracking | ✅ Yes | ✅ Yes |

### Time Savings

With ~7.8M keys:
- **Regular delete**: Count (3-5 min) + Delete (20-40 min) = **23-45 minutes**
- **Fast delete**: Delete only = **20-40 minutes**
- **Time saved**: ~3-5 minutes (skip counting phase)

### Usage Example

```bash
# If you already counted and know it's safe to delete:
./count-keys-cluster.sh user-redis-info.txt 'temp:*'
# Saw: 1500 keys total

# Now delete without counting again:
./delete-keys-cluster-fast.sh user-redis-info.txt 'temp:*'
```

### Example Output

```
=======================================
Redis Cluster Key Deletion (Fast)
=======================================
Pattern:       temp:*
Instances:     6
Mode:          Fast (no counting)
=======================================

⚠️  WARNING ⚠️
This will PERMANENTLY DELETE all keys matching 'temp:*'
across 6 Redis instances!

Note: This is the FAST mode - keys will be deleted immediately.
You will NOT see the count before deletion.

Pattern: temp:*
Instances:
  - 10.50.1.22:9315
  - 10.50.1.20:9319
  - 10.50.1.20:9315
  - 10.50.1.21:9315
  - 10.50.1.21:9319
  - 10.50.1.22:9319

Type 'DELETE' (in uppercase) to confirm deletion: DELETE

=======================================
Deleting keys...
=======================================

[1/6] Deleting from 10.50.1.22:9315 ... ✓ SUCCESS (1523 keys deleted)
[2/6] Deleting from 10.50.1.20:9319 ... ✓ SUCCESS (1487 keys deleted)
[3/6] Deleting from 10.50.1.20:9315 ... ✓ SUCCESS (1501 keys deleted)
[4/6] Deleting from 10.50.1.21:9315 ... ✓ SUCCESS (0 keys deleted)
[5/6] Deleting from 10.50.1.21:9319 ... ✓ SUCCESS (1498 keys deleted)
[6/6] Deleting from 10.50.1.22:9319 ... ✓ SUCCESS (1512 keys deleted)

=======================================
Deletion Complete
=======================================
  Total instances: 6
  Success:         6
  Failed:          0
  Keys deleted:    7521
=======================================
```

### Recommended Workflow

```bash
# Option 1: Count first, then fast delete
./count-keys-cluster.sh user-redis-info.txt 'QC|ZPP|TASK*'
./delete-keys-cluster-fast.sh user-redis-info.txt 'QC|ZPP|TASK*'

# Option 2: Test pattern first, then fast delete
redis-cli -h 10.50.1.22 -p 9315 --scan --pattern 'QC|ZPP|TASK*' | head -5
./delete-keys-cluster-fast.sh user-redis-info.txt 'QC|ZPP|TASK*'
```

---

## Key Finder Scripts

### Quick Start

**Production-safe method (Recommended):**
```bash
./find-keys-cluster-safe.sh user-redis-info.txt 'user:*'
```

**Fast method (use only on dev/test environments):**
```bash
./find-keys-cluster.sh user-redis-info.txt 'session:*' output.txt
```

### Usage Examples

**Find all keys:**
```bash
./find-keys-cluster-safe.sh user-redis-info.txt
```

**Find keys with specific pattern:**
```bash
./find-keys-cluster-safe.sh user-redis-info.txt 'user:*'
./find-keys-cluster-safe.sh user-redis-info.txt 'session:*'
./find-keys-cluster-safe.sh user-redis-info.txt 'cache:product:*'
```

**Specify custom output file:**
```bash
./find-keys-cluster-safe.sh user-redis-info.txt 'user:*' user-keys.txt
```

### Key Finder Features

- ✅ **Production-safe**: Uses SCAN command (non-blocking)
- ✅ **Multi-cluster support**: Scans all Redis instances in parallel
- ✅ **Pattern matching**: Supports Redis glob patterns (`*`, `?`, `[]`)
- ✅ **Error resilience**: Continues even if some instances fail
- ✅ **Color-coded output**: Green = success, red = failed
- ✅ **Auto-generated output**: Creates timestamped files automatically
- ✅ **Instance labeling**: Each key is labeled with its source instance
- ✅ **Summary statistics**: Shows total keys found across all clusters
- ✅ **Preview**: Displays first 10 keys after completion

### KEYS vs SCAN

**KEYS Command** (`find-keys-cluster.sh`):
- ✅ Fast - returns all keys immediately
- ❌ **Blocks Redis** - can cause performance issues in production
- ✅ Good for: development, testing, small datasets
- ⚠️ **DO NOT USE IN PRODUCTION**

**SCAN Command** (`find-keys-cluster-safe.sh`):
- ✅ **Production-safe** - non-blocking, cursor-based iteration
- ✅ Allows Redis to serve other requests while scanning
- ✅ Recommended for production environments
- ⏱️ Slightly slower but much safer

### Example Output

```
=======================================
Redis Cluster Key Finder (SCAN)
=======================================
Pattern:       user:*
Output file:   redis-keys-20260106-143022.txt
Instances:     6
Method:        SCAN (production-safe, non-blocking)
Scan count:    1000
=======================================

[1/6] Scanning 10.50.1.22:9315 ... ✓ SUCCESS (1523 keys)
[2/6] Scanning 10.50.1.20:9319 ... ✓ SUCCESS (1487 keys)
[3/6] Scanning 10.50.1.20:9315 ... ✓ SUCCESS (1501 keys)
[4/6] Scanning 10.50.1.21:9315 ... ✗ FAILED
    Error: Could not connect to Redis at 10.50.1.21:9315
[5/6] Scanning 10.50.1.21:9319 ... ✓ SUCCESS (1498 keys)
[6/6] Scanning 10.50.1.22:9319 ... ✓ SUCCESS (1512 keys)

=======================================
Summary:
  Total instances: 6
  Success:         5
  Failed:          1
  Total keys:      7521
  Output file:     redis-keys-20260106-143022.txt
=======================================

Preview (first 10 keys):
---------------------------------------
user:12345:profile
user:12345:settings
user:12346:profile
user:12346:settings
user:12347:profile
...
(7521 total keys in redis-keys-20260106-143022.txt)
```

### Output File Format

The output file contains all keys grouped by instance:

```
# Instance: 10.50.1.22:9315
user:12345:profile
user:12345:settings
user:12346:profile

# Instance: 10.50.1.20:9319
user:22345:profile
user:22345:settings

...
```

---

## Flush Scripts

### Method 1: Safe version with confirmation (Recommended)

```bash
./flush-redis-cluster-safe.sh user-redis-info.txt
```

This will:
1. Show you all Redis instances
2. Ask for confirmation
3. Flush each instance
4. Continue even if errors occur
5. Show summary

### Method 2: Pipe input

```bash
cat user-redis-info.txt | ./flush-redis-cluster.sh
```

### Method 3: Redirect input

```bash
./flush-redis-cluster.sh < user-redis-info.txt
```

### Method 4: Direct paste

```bash
./flush-redis-cluster.sh
# Then paste your Redis list and press Ctrl+D
```

## Input Format

The input file should contain one Redis instance per line in `IP:PORT` format:

```
10.50.1.20:9315
10.50.1.20:9319
10.50.1.21:9315
10.50.1.21:9319
10.50.1.22:9315
10.50.1.22:9319
```

- Empty lines are skipped
- Lines starting with `#` are treated as comments

## Features

- ✅ Continues on error (won't stop if one instance fails)
- ✅ Color-coded output (green = success, red = failed)
- ✅ Detailed error messages (connection refused, timeout, etc.)
- ✅ 5-second timeout per instance (auto-detects timeout/gtimeout)
- ✅ Cross-platform (macOS and Linux compatible)
- ✅ Summary statistics
- ✅ Safe version with confirmation prompt

## Requirements

- `redis-cli` must be installed
- Network access to Redis instances
- Bash 4.0+
- **Optional**: `timeout` (Linux) or `gtimeout` (macOS via `brew install coreutils`) for 5-second timeout
  - Script works without timeout, but may hang on unreachable instances

## Example Output

```
=======================================
Redis Cluster FLUSHALL Script
=======================================

[1] Flushing 10.50.1.20:9315 ... ✓ SUCCESS
[2] Flushing 10.50.1.20:9319 ... ✓ SUCCESS
[3] Flushing 10.50.1.21:9315 ... ✗ FAILED
    Error: Could not connect to Redis at 10.50.1.21:9315: Connection refused
[4] Flushing 10.50.1.21:9319 ... ✓ SUCCESS
[5] Flushing 10.50.1.22:9315 ... ✗ FAILED
    Error: Timeout after 5 seconds
[6] Flushing 10.50.1.22:9319 ... ✓ SUCCESS

=======================================
Summary:
  Total:   6
  Success: 4
  Failed:  2
=======================================
```

## Warning

⚠️ **FLUSHALL deletes ALL data from Redis instances. Use with caution!**
