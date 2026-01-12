# Changelog

## 2026-01-06

### redis-flushall.sh - Key Count Tracking Added

**New Feature**: The script now displays the number of keys deleted from each Redis node and shows the total keys deleted in the summary.

#### What Changed

- Added `get_key_count()` function to retrieve key count using DBSIZE before flushing
- Modified execution loop to track keys deleted per node
- Updated output to show key count for each successful flush
- Added total keys deleted to final summary

#### Before

```
[1/3] Flushing 10.50.1.21:9911 ... ✓ SUCCESS
[2/3] Flushing 10.50.1.21:9912 ... ✓ SUCCESS
[3/3] Flushing 10.50.1.21:9913 ... ✓ SUCCESS

=======================================
FLUSHALL Complete
=======================================
  Total nodes:     3
  Reachable:       3
  Unreachable:     0
  Success:         3
=======================================
```

#### After

```
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

#### Benefits

- ✅ Visibility into how many keys were deleted
- ✅ Per-node statistics for auditing
- ✅ Total count for reporting
- ✅ Helps verify the operation scope
- ✅ Useful for documentation and compliance

#### Technical Details

The script uses the `DBSIZE` command to get the total number of keys in the database before executing `FLUSHALL`. This provides:

1. **Accurate count**: Uses Redis native DBSIZE command
2. **Fast operation**: DBSIZE is O(1) constant time
3. **Non-blocking**: Does not interfere with Redis operations
4. **Safe**: Read-only operation before destructive action

#### Compatibility

- No breaking changes
- Works with all Redis versions
- Compatible with password authentication
- Works with timeout protection

---

## Previous Versions

### redis-list-keys.sh - Initial Release
- List all keys from Redis cluster
- SCAN-based (production-safe)
- Flexible input (file or direct args)
- Timestamped output files

### redis-flushall.sh - Initial Release
- FLUSHALL with flexible input
- Maximum safety confirmations
- Connection testing
- Error resilience
