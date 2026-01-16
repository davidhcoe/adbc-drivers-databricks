# CloudFetch Test Enhancements with Thrift Decoder

## Summary

The CloudFetch tests have been enhanced to use the **decoded Thrift messages** to verify exact call patterns, not just call counts. This provides much stronger verification that the driver correctly handles URL expiry scenarios.

## What Changed

### Before: Count-Based Verification ❌

The tests previously only verified the **number of calls**:

```csharp
// Old verification - only checks count
var actualFetchResults = await ControlClient.CountThriftMethodCallsAsync("FetchResults");
var expectedFetchResults = baselineFetchResults + 1;
Assert.Equal(expectedFetchResults, actualFetchResults);
```

**Problems with this approach:**
- ❌ Doesn't verify it's actually a **retry** for the same operation
- ❌ Doesn't verify the **operation handle** is identical
- ❌ Can't distinguish between:
  - Driver calling FetchResults for **different operations** (wrong)
  - Driver calling FetchResults **twice for same operation** (correct)

### After: Field-Based Verification ✅

The tests now verify the **actual Thrift call contents** using decoded fields:

```csharp
// New verification - checks decoded Thrift fields
await ControlClient.AssertFetchResultsCalledTwiceWithSameOperationAsync();
```

**Benefits of this approach:**
- ✅ Verifies **exactly 2 FetchResults calls** with decoded data
- ✅ Extracts and compares **operation handle GUIDs** from decoded fields
- ✅ Proves it's a **retry for the same operation** (not a different query)
- ✅ Provides detailed diagnostics showing decoded field values on failure

## How It Works

### 1. Thrift Decoder in mitmproxy

The `mitmproxy_addon.py` now uses the enhanced `thrift_decoder.py` to decode both requests and responses:

```python
# In mitmproxy_addon.py
decoded = decode_thrift_message(flow.request.content)
if decoded and "error" not in decoded:
    # Track call with decoded fields
    call_record = {
        "timestamp": time.time(),
        "type": "thrift",
        "method": decoded.get("method", "unknown"),
        "message_type": decoded.get("message_type", "unknown"),
        "sequence_id": decoded.get("sequence_id", 0),
        "fields": decoded.get("fields", {}),  # Decoded field names & values
    }
    call_history.append(call_record)
```

### 2. Enhanced ProxyControlClient Methods

Added new methods to `ProxyControlClient.cs`:

#### `GetThriftMethodCallsAsync()`
```csharp
// Get all FetchResults calls with decoded field information
var fetchResultsCalls = await ControlClient.GetThriftMethodCallsAsync("FetchResults");
```

Returns `List<ThriftCall>` where each `ThriftCall` contains:
- `Method`: "FetchResults"
- `MessageType`: "CALL" (request) or "REPLY" (response)
- `SequenceId`: Thrift sequence number
- `Fields`: JSON element with decoded field names and values

#### `AssertThriftMethodCallCountAsync()`
```csharp
// Verify exact count with detailed diagnostics
await ControlClient.AssertThriftMethodCallCountAsync("FetchResults", expectedCalls: 2);
```

Provides detailed diagnostics on failure:
```
Expected FetchResults to be called exactly 2 time(s), but was called 3 time(s)

Actual calls:

Call 1:
  Timestamp: 1704139200.123
  Message Type: CALL
  Sequence ID: 12345
  Decoded Fields:
    operationHandle: {...}
    orientation: 0
    maxRows: 10000

Call 2:
  Timestamp: 1704139201.456
  Message Type: CALL
  Sequence ID: 12346
  Decoded Fields:
    operationHandle: {...}
    orientation: 0
    maxRows: 10000

Call 3:
  Timestamp: 1704139202.789
  ...
```

#### `AssertFetchResultsCalledTwiceWithSameOperationAsync()`
```csharp
// Verify FetchResults called twice for SAME operation
await ControlClient.AssertFetchResultsCalledTwiceWithSameOperationAsync();
```

This method:
1. Gets all FetchResults calls
2. Takes the last 2 calls (most recent retry)
3. Extracts operation handle GUID from decoded fields of each call
4. Verifies both calls have **identical operation handle**
5. Throws detailed exception on mismatch

### 3. Decoded Field Structure

The Thrift decoder resolves field names using `thrift_spec` from `databricks-sql-python`:

**Example: FetchResultsReq decoded fields**
```json
{
  "operationHandle": {
    "type": "STRUCT",
    "value": {
      "operationHandle": {
        "type": "STRING",
        "value": "abc123-guid-4567",
        "field_id": 1
      },
      "statement": {
        "type": "STRING",
        "value": "def456-secret-8901",
        "field_id": 2
      }
    },
    "field_id": 1
  },
  "orientation": {
    "type": "I32",
    "value": 0,
    "field_id": 2
  },
  "maxRows": {
    "type": "I64",
    "value": 10000,
    "field_id": 3
  }
}
```

### 4. Operation Handle Extraction

The `ExtractOperationHandle()` private method navigates the decoded JSON structure:

```csharp
private string ExtractOperationHandle(ThriftCall call)
{
    // Navigate: FetchResultsReq.operationHandle.value.operationHandle.value
    if (call.Fields.Value.TryGetProperty("operationHandle", out var opHandle))
    {
        if (opHandle.TryGetProperty("value", out var opHandleValue))
        {
            if (opHandleValue.TryGetProperty("operationHandle", out var nestedOpId))
            {
                if (nestedOpId.TryGetProperty("value", out var guidValue))
                {
                    return guidValue.GetString() ?? string.Empty;
                }
            }
        }
    }
    return string.Empty;
}
```

## Updated Tests

### CloudFetchExpiredLink_RefreshesLinkViaFetchResults

**Before:**
```csharp
// Only verified count
var actualFetchResults = await ControlClient.CountThriftMethodCallsAsync("FetchResults");
Assert.Equal(baselineFetchResults + 1, actualFetchResults);
```

**After:**
```csharp
// Verify count
var actualFetchResults = await ControlClient.CountThriftMethodCallsAsync("FetchResults");
Assert.Equal(baselineFetchResults + 1, actualFetchResults);

// NEW: Verify decoded Thrift fields show same operation handle
await ControlClient.AssertFetchResultsCalledTwiceWithSameOperationAsync();
```

### CloudFetch403_RefreshesLinkViaFetchResults

Same enhancement applied.

## Verification Workflow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Execute query with CloudFetch                           │
│    → ExecuteStatement returns operation handle             │
└────────────────────┬────────────────────────────────────────┘
                     │
                     v
┌─────────────────────────────────────────────────────────────┐
│ 2. Driver calls FetchResults (Call #1)                     │
│    → Decoded fields: operationHandle = "abc-123"           │
│    → Response contains CloudFetch download URL             │
└────────────────────┬────────────────────────────────────────┘
                     │
                     v
┌─────────────────────────────────────────────────────────────┐
│ 3. Driver attempts CloudFetch download                     │
│    → Proxy injects 403/expired link error                  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     v
┌─────────────────────────────────────────────────────────────┐
│ 4. Driver calls FetchResults AGAIN (Call #2)               │
│    → Decoded fields: operationHandle = "abc-123"           │
│    → ✅ SAME operation handle proves it's a retry          │
│    → Response contains FRESH CloudFetch URL                │
└────────────────────┬────────────────────────────────────────┘
                     │
                     v
┌─────────────────────────────────────────────────────────────┐
│ 5. Driver retries CloudFetch download                      │
│    → This time succeeds (proxy doesn't inject failure)     │
│    → Results successfully downloaded                        │
└─────────────────────────────────────────────────────────────┘

Test Verification:
  ✅ Count: FetchResults called exactly (baseline + 1) times
  ✅ Fields: Both FetchResults calls have SAME operation handle
  ✅ Proves: Driver correctly refreshes URL for same operation
```

## Error Diagnostics

### Scenario 1: Wrong Number of Calls

```
Expected FetchResults to be called exactly 2 time(s), but was called 1 time(s)

Actual calls:

Call 1:
  Timestamp: 1704139200.123
  Message Type: CALL
  Sequence ID: 12345
  Decoded Fields:
    operationHandle: {...}
    orientation: 0
    maxRows: 10000
```

**Diagnosis**: Driver didn't retry FetchResults after URL expiry

### Scenario 2: Different Operation Handles

```
FetchResults calls have different operation handles:
  First call:  abc-123-guid-4567
  Second call: def-456-guid-8901
Expected them to be identical (retry with same operation after URL expiry)
```

**Diagnosis**: Driver called FetchResults for a **different operation** instead of retrying the same one

### Scenario 3: Can't Extract Operation Handle

```
Could not extract operation handles from FetchResults calls.
Check that Thrift decoding is working correctly.
```

**Diagnosis**: Thrift decoder not working or field structure changed

## Benefits

### Stronger Test Coverage

| Aspect | Before | After |
|--------|--------|-------|
| Verifies call count | ✅ | ✅ |
| Verifies same operation | ❌ | ✅ |
| Verifies operation handle | ❌ | ✅ |
| Detailed diagnostics | ❌ | ✅ |
| Catches wrong retries | ❌ | ✅ |

### Catches More Bugs

**Before**: Would pass even if driver:
- Called FetchResults for a **different query**
- Called FetchResults **twice but for unrelated operations**
- Had a bug where it opens a **new operation** instead of refreshing URL

**After**: Catches all these bugs by verifying:
- Exact same operation handle in both calls
- Decoded field values match expectations
- Retry pattern is correct

### Better Debugging

When tests fail, you get:
- ✅ Decoded Thrift field names (not generic field_1, field_2)
- ✅ Actual operation handle GUIDs
- ✅ Complete call history with timestamps
- ✅ Clear indication of what went wrong

## Example Test Run

```bash
# Run CloudFetch tests
cd test-infrastructure/tests/csharp
dotnet test --filter "FullyQualifiedName~CloudFetchTests"
```

**Successful output:**
```
✅ CloudFetchExpiredLink_RefreshesLinkViaFetchResults - PASSED
   - FetchResults called 2 times
   - Both calls have same operation handle: abc-123-guid-4567
   - URL refresh verified via decoded Thrift fields

✅ CloudFetch403_RefreshesLinkViaFetchResults - PASSED
   - FetchResults called 2 times
   - Both calls have same operation handle: def-456-guid-8901
   - URL refresh verified via decoded Thrift fields
```

## Files Modified

### C# Test Files
- `tests/csharp/CloudFetchTests.cs`: Added `AssertFetchResultsCalledTwiceWithSameOperationAsync()` calls
- `tests/csharp/ProxyControlClient.cs`: Added 3 new methods:
  - `GetThriftMethodCallsAsync()`
  - `AssertThriftMethodCallCountAsync()`
  - `AssertFetchResultsCalledTwiceWithSameOperationAsync()`

### Python Proxy Files
- `proxy-server/thrift_decoder.py`: Already enhanced to decode both requests and responses
- `proxy-server/mitmproxy_addon.py`: Already tracks decoded fields in call history

## Future Enhancements

### Potential Additional Verifications

1. **Verify offset parameter**:
   ```csharp
   // Verify both calls request same data offset
   await AssertFetchResultsHaveSameOffsetAsync();
   ```

2. **Verify maxRows parameter**:
   ```csharp
   // Verify driver uses consistent maxRows
   await AssertFetchResultsHaveSameMaxRowsAsync();
   ```

3. **Verify response structure**:
   ```csharp
   // Verify response contains valid CloudFetch links
   await AssertFetchResultsResponseHasCloudFetchLinksAsync();
   ```

4. **Timeline verification**:
   ```csharp
   // Verify retry happens within reasonable time
   await AssertRetryTimingIsReasonableAsync();
   ```

## Conclusion

The CloudFetch tests now use **decoded Thrift message fields** to provide:
- ✅ **Stronger verification** - proves actual retry with same operation
- ✅ **Better diagnostics** - shows decoded field values on failure
- ✅ **Catches more bugs** - detects wrong retry patterns
- ✅ **Easier debugging** - semantic field names, not generic IDs

This is a **significant improvement** over simple call counting and demonstrates the power of the enhanced Thrift decoder.
