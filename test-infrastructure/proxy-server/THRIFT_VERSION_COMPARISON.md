# Thrift Protocol Version Comparison

Comparison of Thrift IDL files used by different Databricks SQL drivers.

## File Size Comparison

| File | Lines | Size (bytes) | Comment Lines | Structs | Purpose |
|------|-------|--------------|---------------|---------|---------|
| **Runtime TCLIService.thrift** | 2,368 | 80,717 | ~600 | ~100 | Internal Databricks (source of truth) |
| **Universe TCLIService_simbaodbc.thrift** | 1,802 | 58,400 | 361 | 92 | Simba ODBC/JDBC driver |
| **Universe TCLIService.thrift** | 737 | 21,882 | 0 | 86 | Java, Node.js, Go drivers |
| **Universe TCLIService_py.thrift** | ~740 | 22,003 | 0 | 86 | Python driver |

## Key Findings

### Why is Simba Version Larger? 🤔

The Simba ODBC version is **2.4x larger** (58KB vs 22KB) than the standard driver versions because:

#### 1. **Full Documentation Preserved** (Main Factor)
- **Simba**: 361 comment lines with full descriptions
- **Regular**: 0 comment lines (all stripped)
- **Impact**: ~60% of the size difference

**Example:**
```thrift
// Simba version (with comments):
struct TExecuteStatementReq {
  // The session to execute the statement against
  1: required TSessionHandle sessionHandle

  // The statement to be executed (DML, DDL, SET, etc)
  2: required string statement
  ...
}

// Regular version (no comments):
struct TExecuteStatementReq {
  1: required TSessionHandle sessionHandle
  2: required string statement
  ...
}
```

#### 2. **Additional Hive Protocol Support**
- **Simba**: Includes `HIVE_CLI_SERVICE_PROTOCOL_V11` (timestamp with local timezone)
- **Others**: Stop at `HIVE_CLI_SERVICE_PROTOCOL_V10`
- **New Type**: `TIMESTAMPLOCALTZ_TYPE` for ODBC compatibility

#### 3. **More Complete Struct Definitions**
- **Simba**: 92 structs (includes delegation tokens, all value types)
- **Regular**: 86 structs (streamlined for modern usage)
- **Unique to Simba**:
  - `TGetDelegationTokenReq/Resp`
  - `TCancelDelegationTokenReq/Resp`
  - `TRenewDelegationTokenReq/Resp`
  - Full `TBoolValue`, `TByteValue`, `TI16Value`, etc. (row-based format)

#### 4. **Legacy Row-Based Format Support**
Simba includes full support for row-based result formats (older Hive protocol):
```thrift
struct TBoolValue { 1: optional bool value }
struct TByteValue { 1: optional byte value }
struct TI16Value { 1: optional i16 value }
struct TI32Value { 1: optional i32 value }
struct TI64Value { 1: optional i64 value }
struct TDoubleValue { 1: optional double value }
struct TStringValue { 1: optional string value }
```

Modern drivers use columnar format exclusively (Arrow/CloudFetch).

## Protocol Version Differences

### Spark Protocol Support

| Protocol Version | Simba | Regular | Python | Runtime |
|-----------------|-------|---------|--------|---------|
| SPARK_CLI_SERVICE_PROTOCOL_V1 | ✅ | ✅ | ✅ | ✅ |
| SPARK_CLI_SERVICE_PROTOCOL_V2 | ✅ | ✅ | ✅ | ✅ |
| SPARK_CLI_SERVICE_PROTOCOL_V3 | ✅ | ✅ | ✅ | ✅ |
| SPARK_CLI_SERVICE_PROTOCOL_V4 | ✅ | ✅ | ✅ | ✅ |
| SPARK_CLI_SERVICE_PROTOCOL_V5 | ✅ | ✅ | ✅ | ✅ |
| SPARK_CLI_SERVICE_PROTOCOL_V6 | ✅ | ✅ | ✅ | ✅ |
| SPARK_CLI_SERVICE_PROTOCOL_V7 | ✅ | ✅ | ✅ | ✅ |
| SPARK_CLI_SERVICE_PROTOCOL_V8 | ✅ | ✅ | ✅ | ✅ |
| SPARK_CLI_SERVICE_PROTOCOL_V9 | ❌ | ✅ | ✅ | ✅ |

**Simba is missing SPARK V9** (parameterized queries v2)

### Hive Protocol Support

| Protocol Version | Simba | Regular | Runtime |
|-----------------|-------|---------|---------|
| HIVE_CLI_SERVICE_PROTOCOL_V1-V10 | ✅ | ✅ | ✅ |
| HIVE_CLI_SERVICE_PROTOCOL_V11 | ✅ | ❌ | ❌ |

**Only Simba has V11** (timestamp with local timezone)

## Field Differences in TExecuteStatementReq

| Field ID | Field Name | Simba | Regular | Python | Runtime |
|----------|-----------|-------|---------|--------|---------|
| 1-5 | Core Hive fields | ✅ | ✅ | ✅ | ✅ |
| 0x501-0x508 | Spark V1-V8 extensions | ✅ | ✅ | ✅ | ✅ |
| 0x509 | maxBytesPerBatch | ❌ | ✅ | ✅ | ✅ |
| 0x510 | statementConf | ❌ | ✅ | ✅ | ✅ |
| 0xD01 | operationId (internal) | ❌ | ❌ | ❌ | ✅ |
| 0xD02 | sessionConf (internal) | ❌ | ❌ | ❌ | ✅ |
| 0xD19 | enforceEmbeddedSchemaCorrectness | ❌ | ❌ | ✅ | ✅ |

## Why Different Versions?

### Simba ODBC/JDBC Driver
- **Audience**: Enterprise ODBC/JDBC clients (Tableau, Power BI, etc.)
- **Requirements**:
  - Maximum compatibility with legacy Hive clients
  - Support for TIMESTAMPLOCALTZ (ODBC standard)
  - Delegation token support for Kerberos
  - Row-based format for older clients
- **Trade-off**: Larger file, but handles all client types
- **Documentation**: Kept for driver developers

### Regular Drivers (Java, Node.js, Go)
- **Audience**: Modern application developers
- **Requirements**:
  - Lightweight, fast
  - Columnar/Arrow format only
  - No legacy protocol baggage
- **Trade-off**: Smaller, but requires modern protocol
- **Documentation**: Stripped (refer to runtime source)

### Python Driver
- **Special**: Includes internal field `0xD19` (enforceEmbeddedSchemaCorrectness)
- **Why**: Used for specific Python client validation scenarios

### Runtime (Internal)
- **Purpose**: Source of truth for all protocol definitions
- **Content**: All features, including internal 0xD00+ fields
- **Usage**: Not distributed externally

## Compatibility Matrix

### Will Simba ODBC Driver Work with Your Decoder?

✅ **YES** - Your decoder will work perfectly because:

1. **Same field IDs 1-5 and 0x501-0x508**
   - All core fields are identical

2. **Missing fields are optional**
   - Simba doesn't send 0x509-0x510
   - Your decoder will just not show them (perfectly fine)

3. **TIMESTAMPLOCALTZ handled gracefully**
   - If Simba sends this type, decoder shows it as type ID
   - No crashes, just might show `type_23` instead of name

4. **Protocol version negotiation works**
   - Simba negotiates down to V8 or lower
   - Your decoder knows V1-V9, so V8 is fully covered

### Decoding Priority for Your Use Case

**Best choice**: Continue using **Python-generated types** from databricks-sql-python because:

✅ Covers all modern drivers (Java, Python, Node.js, Go)
✅ Includes Python-specific field (0xD19)
✅ Works with Simba ODBC (common fields)
✅ Missing Simba-specific fields are optional (won't break)
✅ Lighter weight than Simba version

Only switch to Simba version if:
- You need to decode delegation token operations
- You need row-based format support
- You need TIMESTAMPLOCALTZ type resolution

## Summary

| Aspect | Simba Version | Regular Version | Your Current Decoder |
|--------|--------------|-----------------|---------------------|
| **Size** | 58KB (2.4x) | 22KB | Using Python (22KB) |
| **Documentation** | ✅ Full | ❌ Stripped | Uses generated code |
| **Protocol Coverage** | V1-V8, V11 | V1-V9 | V1-V9 ✅ |
| **Legacy Support** | ✅ Extensive | ❌ Minimal | ❌ Minimal ✅ |
| **Field Coverage** | 92 structs | 86 structs | 86 structs ✅ |
| **Best For** | ODBC/JDBC | Modern drivers | Testing modern drivers ✅ |

**Recommendation**: ✅ **Keep your current setup** using databricks-sql-python generated code. It's the sweet spot for testing modern ADBC/SQL drivers while maintaining compatibility with Simba ODBC traffic (common fields overlap perfectly).
