# Operation GUID Validation in CloudFetch Tests

## Summary

The enhanced CloudFetch tests now include **strict validation** of operation GUIDs to ensure:
1. ✅ **Operation GUIDs are always non-empty** - Empty GUIDs cause immediate test failure
2. ✅ **Different operations have different GUIDs** - Each query gets a unique operation
3. ✅ **Same operation retry uses same GUID** - URL refresh doesn't create new operation

## Why This Matters

### Problem: Counting Calls is Not Enough

**Before enhancement**, tests only counted FetchResults calls:
```csharp
// Old: Just counts
Assert.Equal(expectedCount, actualCount);
```

This could pass even if:
- ❌ Driver called FetchResults for a **different operation** (wrong GUID)
- ❌ Driver created a **new operation** instead of retrying (new GUID)
- ❌ Operation GUID was **empty** (decoding failure)

**After enhancement**, tests validate actual operation GUIDs:
```csharp
// New: Validates GUIDs are non-empty and identical
await ControlClient.AssertFetchResultsCalledTwiceWithSameOperationAsync();
```

This catches bugs where:
- ✅ Driver uses wrong operation handle
- ✅ Driver creates new operation instead of retrying
- ✅ Thrift decoding fails

## GUID Validation Rules

### Rule 1: GUIDs Must Be Non-Empty

**Validation**:
```csharp
if (string.IsNullOrEmpty(firstOperationHandle))
{
    throw new XunitException(
        "First FetchResults call has EMPTY operation handle.\n" +
        "This indicates either:\n" +
        "  1. Thrift decoding failed\n" +
        "  2. The decoded structure changed\n" +
        "  3. The operation handle was not properly set by the driver");
}
```

**When This Fails**:
- Thrift decoder can't extract GUID from decoded fields
- Driver sent a request with no operation handle
- Decoded Thrift structure changed unexpectedly

**Example Error**:
```
First FetchResults call has EMPTY operation handle.

FetchResults Call Analysis:

First Call (index 0):
  Timestamp: 1704139200.123
  Extracted operation handle: ''
  Handle length: 0 chars
  Handle is empty: True
```

### Rule 2: Retries Must Use Same GUID

**Validation**:
```csharp
if (firstOperationHandle != secondOperationHandle)
{
    throw new XunitException(
        $"FetchResults calls have DIFFERENT operation handles:\n" +
        $"  First call:  {firstOperationHandle}\n" +
        $"  Second call: {secondOperationHandle}\n" +
        "Expected them to be identical (retry with same operation after URL expiry).\n" +
        "Having different handles means the driver created a NEW operation instead of retrying.");
}
```

**When This Fails**:
- Driver created a **new operation** for URL refresh (wrong behavior)
- Driver mixed up operation handles from different queries
- Driver has a bug in retry logic

**Example Error**:
```
FetchResults calls have DIFFERENT operation handles:

FetchResults Call Analysis:

First Call (index 0):
  Timestamp: 1704139200.123
  Extracted operation handle: 'abc-123-operation-guid'
  Handle length: 23 chars
  Handle is empty: False

Second Call (index 1):
  Timestamp: 1704139201.456
  Extracted operation handle: 'def-456-operation-guid'
  Handle length: 23 chars
  Handle is empty: False

Expected them to be identical (retry with same operation after URL expiry).
Having different handles means the driver created a NEW operation instead of retrying.
```

### Rule 3: Different Operations Have Different GUIDs

**Verified by Test**:
```python
# Create two different operations
request1 = create_fetchresults_request("operation-aaa")
request2 = create_fetchresults_request("operation-bbb")

guid1 = extract_guid(decoded1)  # "operation-aaa"
guid2 = extract_guid(decoded2)  # "operation-bbb"

assert guid1 != guid2  # ✅ Different operations have different GUIDs
```

**Why This is Important**:
- Each ExecuteStatement creates a unique operation with unique GUID
- Different queries must never share operation GUIDs
- This is fundamental to Databricks protocol design

## GUID Structure

### Thrift Binary Format

Operation GUIDs in Thrift binary protocol:
- **Type**: Binary string (TType.STRING with binary content)
- **Length**: Maximum 16 bytes
- **Encoding**: UTF-8 when decoded, with null padding removed

### Example GUIDs

Real production GUIDs look like:
```
01234567-89ab-cdef-0123-456789abcdef  (36 chars UUID format, truncated to 16 bytes)
abc-123-operation-guid                 (23 chars, truncated to 16 bytes)
```

After Thrift encoding (16 byte limit):
```
Original: "01234567-89ab-cdef-0123-456789abcdef" (36 chars)
Encoded:  "01234567-89ab-c" (16 bytes)

Original: "abc-123-operation-guid" (22 chars)
Encoded:  "abc-123-operatio" (16 bytes)

Original: "operation-aaa" (13 chars)
Encoded:  "operation-aaa\x00\x00\x00" (16 bytes with null padding)
Extracted: "operation-aaa" (null padding removed)
```

## Extraction Path

### Decoded Structure

The Thrift decoder creates this nested structure:

```
FetchResultsReq
└─ operationHandle [field_id=1] (STRUCT)
   └─ value: TOperationHandle
      └─ operationHandle [field_id=1] (STRUCT)  ← reuses parent field name
         └─ value: THandleIdentifier
            └─ operationHandle [field_id=1] (STRING)  ← reuses parent field name again
               └─ value: "abc-123-guid" (actual GUID bytes)
```

**Why field names repeat**: The decoder only builds `field_name_map` for the top-level struct. Nested structs at different levels all have field_id=1, so they all get labeled "operationHandle" from the parent's field mapping.

### Extraction Code (C#)

```csharp
// Navigate: TFetchResultsReq.operationHandle
if (!fields.TryGetProperty("operationHandle", out var opHandleField))
    return string.Empty;

// Get value: TOperationHandle struct
if (!opHandleField.TryGetProperty("value", out var opHandleStruct))
    return string.Empty;

// Navigate: TOperationHandle.operationId (labeled as "operationHandle")
if (!opHandleStruct.TryGetProperty("operationHandle", out var opIdField))
    return string.Empty;

// Get value: THandleIdentifier struct
if (!opIdField.TryGetProperty("value", out var opIdStruct))
    return string.Empty;

// Navigate: THandleIdentifier.guid (labeled as "operationHandle")
if (!opIdStruct.TryGetProperty("operationHandle", out var guidField))
    return string.Empty;

// Get value: actual GUID bytes/string
if (!guidField.TryGetProperty("value", out var guidValue))
    return string.Empty;

string guid = guidValue.GetString() ?? string.Empty;
return guid.TrimEnd('\0');  // Remove null padding
```

## Test Verification

### Test: CloudFetchExpiredLink_RefreshesLinkViaFetchResults

**Flow**:
```
1. Query executes → ExecuteStatement creates operation with GUID "abc-123"
2. FetchResults Call #1 → operationHandle GUID: "abc-123"
3. CloudFetch download → 403 expired
4. FetchResults Call #2 → operationHandle GUID: "abc-123" ✅ SAME
5. CloudFetch retry → Success
```

**Validation**:
```csharp
// Verify FetchResults called twice
Assert.Equal(baselineFetchResults + 1, actualFetchResults);

// NEW: Verify both calls use SAME operation GUID
await ControlClient.AssertFetchResultsCalledTwiceWithSameOperationAsync();
```

**What Gets Checked**:
- ✅ Both GUIDs are non-empty (not "")
- ✅ Both GUIDs are identical ("abc-123" == "abc-123")
- ✅ No extraction errors (not "<error:...>")

### Test Output: Success Case

```
✅ CloudFetchExpiredLink_RefreshesLinkViaFetchResults PASSED

FetchResults Call Analysis:

First Call (index 0):
  Timestamp: 1704139200.123
  Extracted operation handle: 'abc-123-operation-guid'
  Handle length: 23 chars
  Handle is empty: False

Second Call (index 1):
  Timestamp: 1704139201.456
  Extracted operation handle: 'abc-123-operation-guid'
  Handle length: 23 chars
  Handle is empty: False

✅ Both calls use the same operation handle
✅ Driver correctly refreshed URL for same operation
```

### Test Output: Failure Case (Empty GUID)

```
❌ CloudFetchExpiredLink_RefreshesLinkViaFetchResults FAILED

First FetchResults call has EMPTY operation handle.

FetchResults Call Analysis:

First Call (index 0):
  Timestamp: 1704139200.123
  Extracted operation handle: ''
  Handle length: 0 chars
  Handle is empty: True

This indicates either:
  1. Thrift decoding failed
  2. The decoded structure changed
  3. The operation handle was not properly set by the driver
```

### Test Output: Failure Case (Different GUIDs)

```
❌ CloudFetchExpiredLink_RefreshesLinkViaFetchResults FAILED

FetchResults calls have DIFFERENT operation handles:

FetchResults Call Analysis:

First Call (index 0):
  Timestamp: 1704139200.123
  Extracted operation handle: 'abc-123-operation-guid'
  Handle length: 23 chars
  Handle is empty: False

Second Call (index 1):
  Timestamp: 1704139201.456
  Extracted operation handle: 'xyz-789-operation-guid'
  Handle length: 23 chars
  Handle is empty: False

Expected them to be identical (retry with same operation after URL expiry).
Having different handles means the driver created a NEW operation instead of retrying.
```

## Edge Cases Handled

### 1. Null Padding

GUIDs shorter than 16 bytes have null padding:
```
"abc-123\x00\x00\x00\x00\x00\x00\x00\x00\x00" → "abc-123"
```

**Handling**: `TrimEnd('\0')` removes null bytes

### 2. Extraction Errors

If extraction fails due to exception:
```csharp
catch (Exception ex)
{
    return $"<error: {ex.Message}>";
}
```

**Detection**:
```csharp
if (operationHandle.StartsWith("<error:"))
{
    throw new XunitException($"Error extracting operation handles:\n{diagnostics}");
}
```

### 3. Binary GUID Data

Some drivers may send binary GUID data (not UTF-8):
```csharp
string guid = guidValue.GetString() ?? string.Empty;  // Handles both string and binary
```

### 4. Multiple FetchResults Calls

Tests take the **last 2 calls** to handle baseline scenarios:
```csharp
// Get last two FetchResults calls (most recent retry scenario)
var firstCall = fetchResultsCalls[fetchResultsCalls.Count - 2];
var secondCall = fetchResultsCalls[fetchResultsCalls.Count - 1];
```

This ensures we're comparing the retry scenario, not earlier baseline calls.

## Benefits

### Stronger Verification

| Aspect | Before | After |
|--------|--------|-------|
| Verifies call count | ✅ | ✅ |
| Verifies same operation | ❌ | ✅ |
| Detects empty GUIDs | ❌ | ✅ |
| Detects wrong operation | ❌ | ✅ |
| Detailed diagnostics | ❌ | ✅ |

### Catches More Bugs

✅ Driver creates new operation instead of retrying
✅ Driver uses wrong operation handle
✅ Thrift decoding failures
✅ Protocol structure changes
✅ Operation handle not properly set

### Better Debugging

When tests fail, you see:
- Exact GUID values for both calls
- GUID lengths and non-empty status
- Timestamps showing call sequence
- Clear error messages explaining what's wrong

## Files Modified

### C# Test Files
- `ProxyControlClient.cs`:
  - `AssertFetchResultsCalledTwiceWithSameOperationAsync()` - Enhanced with GUID validation
  - `ExtractOperationHandle()` - Fixed extraction path, added null trimming

### Python Test Files
- `test_fetchresults_structure.py` - Verifies extraction path and different operations

## Conclusion

The CloudFetch tests now include **comprehensive operation GUID validation**:

1. ✅ **GUIDs are always non-empty** - Empty GUIDs cause test failure with detailed diagnostics
2. ✅ **Different operations have different GUIDs** - Verified by test script
3. ✅ **Retry uses same GUID** - Proves driver refreshes URL for same operation

This provides **much stronger verification** than simple call counting and catches bugs that would otherwise go unnoticed.
