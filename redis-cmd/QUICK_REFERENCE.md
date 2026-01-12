# Quick Reference Guide

## Common Workflows

### 1. Count Keys Before Deleting (Safest - Recommended)

```bash
# Step 1: Count how many keys match
./count-keys-cluster.sh user-redis-info.txt 'QC|ZPP|TASK*'

# Step 2: If count looks correct, delete them (will count again)
./delete-keys-cluster.sh user-redis-info.txt 'QC|ZPP|TASK*'
```

### 1b. Count Then Fast Delete (Faster)

```bash
# Step 1: Count how many keys match
./count-keys-cluster.sh user-redis-info.txt 'QC|ZPP|TASK*'

# Step 2: If count looks correct, delete without counting again
./delete-keys-cluster-fast.sh user-redis-info.txt 'QC|ZPP|TASK*'
```

### 1c. Ultra-Fast Delete (FASTEST - Blocks Redis!)

```bash
# For dev/test or maintenance windows only!
./delete-keys-cluster-ultrafast.sh user-redis-info.txt 'QC|ZPP|TASK*'

# Speed: 1-3 minutes instead of 20-40 minutes
# Trade-off: Blocks Redis for 1-5 seconds per instance
```

### 2. Find and Save Keys to File

```bash
# Fast method (blocks Redis temporarily)
./find-keys-cluster.sh user-redis-info.txt 'QC|ZPP|TASK*' output.txt

# Safe method (production-safe, slower)
./find-keys-cluster-safe.sh user-redis-info.txt 'QC|ZPP|TASK*' output.txt
```

### 3. Test Pattern First

```bash
# Test on one instance to verify pattern is correct
redis-cli -h 10.50.1.22 -p 9315 --scan --pattern 'your:pattern:*' | head -10

# If pattern looks good, run cluster-wide
./delete-keys-cluster.sh user-redis-info.txt 'your:pattern:*'
```

## All Available Scripts

| Script | Purpose | Safe? | Speed |
|--------|---------|-------|-------|
| `count-keys-cluster.sh` | Count keys matching pattern | ✅ Yes (read-only) | Fast |
| `find-keys-cluster-safe.sh` | Find keys (SCAN) | ✅ Yes (non-blocking) | Slow |
| `find-keys-cluster.sh` | Find keys (KEYS) | ⚠️ Blocks Redis | Fast |
| `delete-keys-cluster.sh` | Delete keys with counting (SCAN) | ✅ Requires confirmation | Slow (20-40 min) |
| `delete-keys-cluster-fast.sh` | Delete keys no counting (SCAN) | ✅ Requires confirmation | Slower (20-40 min) |
| `delete-keys-cluster-ultrafast.sh` | Delete keys (KEYS) | ⚠️⚠️ Blocks Redis! | ULTRA FAST (1-3 min) |
| `flush-redis-cluster-safe.sh` | Delete ALL keys | ⚠️ Requires confirmation | Fast |

## Pattern Examples

```bash
# All keys (dangerous!)
'*'

# Keys starting with prefix
'user:*'
'session:*'
'cache:*'

# Keys with specific middle part
'user:session:*'
'cache:product:*'

# Complex patterns (your use case)
'QC|ZPP|TASK*'
'QC|ZPP|TASK|PENDING*'

# Keys with wildcards
'user:?:profile'  # ? matches exactly one character
'user:[abc]:*'    # matches user:a:*, user:b:*, user:c:*
```

## Safety Checklist

Before deleting keys:

- [ ] Run `count-keys-cluster.sh` first to see how many keys match
- [ ] Test pattern on one instance with `redis-cli --scan --pattern`
- [ ] Verify the pattern matches ONLY what you want to delete
- [ ] Make sure pattern is specific enough (avoid `'*'` or broad patterns)
- [ ] Have a backup or know you can regenerate the data
- [ ] Run during low-traffic time if possible

## Performance Notes

With your dataset (~1.3M keys per instance):

| Operation | Estimated Time |
|-----------|----------------|
| Count keys | 2-5 minutes |
| Find all keys | 15-30 minutes |
| Delete keys | 20-40 minutes |

**Tip**: Use more specific patterns to reduce the number of keys and speed up operations.

## Common Issues

### Issue: "mapfile: command not found"
**Solution**: Already fixed! Scripts now work with Bash 3.2+

### Issue: Script hangs or takes too long
**Solution**: You have millions of keys. Either:
- Use more specific patterns
- Run in background with `nohup`
- Be patient (SCAN is safe but slow on large datasets)

### Issue: Want to stop a running script
**Solution**: Press Ctrl+C to cancel safely

### Issue: Need to delete millions of keys faster
**Solution**: Consider using Redis FLUSHDB (deletes entire database) or use more specific patterns to delete in smaller batches

## Running in Background

For long-running operations:

```bash
# Run in background
nohup ./delete-keys-cluster.sh user-redis-info.txt 'pattern:*' &

# Check progress
tail -f nohup.out

# Check if still running
ps aux | grep delete-keys-cluster
```
