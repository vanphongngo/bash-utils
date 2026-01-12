# Redis FLUSHALL Quick Reference

## ⚠️ EXTREME DANGER WARNING

**This script permanently deletes ALL data from Redis instances!**

## Quick Start

### Basic Usage

```bash
# Using config file
./redis-flushall.sh be-ai-redis.txt

# Direct IP:PORT arguments
./redis-flushall.sh 10.50.1.21:9911 10.50.1.21:9912

# With password
./redis-flushall.sh -p mypassword be-ai-redis.txt
```

### Command Options

```bash
-h, --help          Show help
-p, --password      Redis password
-y, --yes           Skip confirmation (DANGEROUS!)
--redis-cli PATH    Custom redis-cli path
--timeout SECONDS   Connection timeout
```

## Safety Checklist

Before executing, verify:

- [ ] **Backups exist** (if data matters)
- [ ] **Correct Redis instances** targeted
- [ ] **Authorization** to delete data
- [ ] **Not production** (or in maintenance window)
- [ ] **Tested on single node** first

## Confirmation Prompt

You must type this **EXACTLY** (case-sensitive):

```
FLUSH ALL DATA
```

Not "flush all data", not "FLUSH ALL", not "yes" - must be exact!

## What Happens

1. ✅ Tests connection to each Redis node
2. ⚠️ Shows all nodes to be flushed
3. 🛑 Asks for confirmation
4. 📊 Gets key count from each node (using DBSIZE)
5. 🗑️ Executes FLUSHALL on each node
6. 📈 Shows keys deleted per node
7. 📊 Shows total keys deleted in summary

## Exit Codes

- `0` - All operations successful
- `1` - Errors occurred (see output)

## Environment Variables

```bash
export REDIS_PASSWORD="mypass"
export REDIS_CLI="/opt/redis/bin/redis-cli"
```

## Examples

### Safe Interactive Mode (Recommended)

```bash
./redis-flushall.sh be-ai-redis.txt

# You will see:
# - Connection test results
# - List of all nodes
# - Confirmation prompt
# - Progress for each node
# - Final summary
```

### Automated Mode (Dangerous!)

```bash
# Skip confirmation - USE EXTREME CAUTION!
./redis-flushall.sh -y be-ai-redis.txt
```

### Mixed Input

```bash
# Combine file and direct nodes
./redis-flushall.sh be-ai-redis.txt 10.50.1.22:9911
```

### With Authentication

```bash
# Password via flag
./redis-flushall.sh -p "MyRedisPass123" be-ai-redis.txt

# Password via environment
export REDIS_PASSWORD="MyRedisPass123"
./redis-flushall.sh be-ai-redis.txt
```

## Output Example

```
=======================================
Redis Cluster FLUSHALL Script
=======================================

Reading nodes from file: be-ai-redis.txt
Found 3 Redis node(s)

Testing connections...
  ✓ 10.50.1.21:9911 - Connected
  ✓ 10.50.1.21:9912 - Connected
  ✗ 10.50.1.21:9913 - Connection failed

Warning: 1 node(s) could not be reached and will be skipped


⚠️  DANGER - DESTRUCTIVE OPERATION ⚠️

This will PERMANENTLY DELETE ALL DATA from 2 Redis instances!
This operation is IRREVERSIBLE and data CANNOT be recovered!

Redis instances to be flushed:
  → 10.50.1.21:9911
  → 10.50.1.21:9912

What will happen:
  ✗ ALL keys will be deleted
  ✗ ALL data will be permanently lost
  ✗ This cannot be undone

Type 'FLUSH ALL DATA' (exact match, case-sensitive) to confirm: FLUSH ALL DATA

=======================================
Executing FLUSHALL...
=======================================

[1/2] Flushing 10.50.1.21:9911 ... ✓ SUCCESS (1523 keys deleted)
[2/2] Flushing 10.50.1.21:9912 ... ✓ SUCCESS (2047 keys deleted)

=======================================
FLUSHALL Complete
=======================================
  Total nodes:     3
  Reachable:       2
  Unreachable:     1
  Success:         2
  Keys deleted:    3570
=======================================
```

## Troubleshooting

### "redis-cli not found"

```bash
# Install redis-cli
brew install redis  # macOS
apt-get install redis-tools  # Ubuntu

# Or specify path
./redis-flushall.sh --redis-cli /path/to/redis-cli be-ai-redis.txt
```

### Connection Failed

1. Check Redis is running: `redis-cli -h <host> -p <port> PING`
2. Check network: `telnet <host> <port>`
3. Check password: Use `-p` flag with correct password
4. Check firewall rules

### Timeout Issues

```bash
# Install timeout (macOS)
brew install coreutils

# The script will auto-detect and use gtimeout
```

## Recovery (If You Made a Mistake)

**IMPORTANT:** FLUSHALL is **IRREVERSIBLE**!

If you need to recover:
1. Stop Redis immediately
2. Copy RDB/AOF backup files to Redis data directory
3. Restart Redis
4. Verify data is restored

**If no backup exists, data is PERMANENTLY LOST!**

## Script Comparison

| Feature | redis-flushall.sh | flush-redis-cluster-safe.sh | flush-redis-cluster.sh |
|---------|-------------------|----------------------------|------------------------|
| Input | File OR args | File only | stdin only |
| Confirmation | Required | Required | No |
| Connection test | Yes | No | No |
| Password support | Yes | No | No |
| Error handling | Comprehensive | Basic | Basic |
| Color output | Yes | Yes | Yes |
| Timeout support | Yes | Yes | Yes |

## Best Practices

### DO

✅ Test on one node first
✅ Have backups before running
✅ Use in dev/test environments
✅ Verify correct Redis instances
✅ Read confirmation prompt carefully

### DON'T

❌ Use on production without backups
❌ Use `-y` flag unless absolutely sure
❌ Skip reading the warnings
❌ Run without understanding consequences
❌ Use on wrong environment

## Alternative Approaches

### Selective Key Deletion

If you need to delete specific keys, use the key deletion scripts instead:

```bash
# Count keys first
./count-keys-cluster.sh be-ai-redis.txt 'pattern:*'

# Delete specific pattern
./delete-keys-cluster.sh be-ai-redis.txt 'pattern:*'
```

### Single Node FLUSHALL

```bash
# Direct redis-cli for single node
redis-cli -h 10.50.1.21 -p 9911 FLUSHALL
```

### Database-Specific Flush

```bash
# Flush only specific database (DB 0 shown)
redis-cli -h 10.50.1.21 -p 9911 -n 0 FLUSHDB
```

## Safety Tips

1. **Always test first** on a single, non-critical node
2. **Double-check** the configuration file
3. **Read warnings** during execution
4. **Have backups** ready
5. **Understand impact** on your application
6. **Coordinate with team** before running in shared environments

## Emergency Stop

If you started the script and need to stop:

1. Press `Ctrl+C` during confirmation prompt (safe)
2. Press `Ctrl+C` during execution (some nodes may already be flushed)
3. Check Redis instances manually to see what was flushed

## Support

For issues or questions:
1. Check script help: `./redis-flushall.sh -h`
2. Review full README.md documentation
3. Test with single node first
4. Verify Redis connectivity manually
