// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Coding Conventions for this file:
//
// Structs/Enums/Unions
// * Struct, Enum, and Union names begin with a "T",
//   and use a capital letter for each new word, with no underscores.
// * All fields should be declared as either optional or required.
//
// Functions
// * Function names start with a capital letter and have a capital letter for
//   each new word, with no underscores.
// * Each function should take exactly one parameter, named TFunctionNameReq,
//   and should return either void or TFunctionNameResp. This convention allows
//   incremental updates.
//
// Services
// * Service names begin with the letter "T", use a capital letter for each
//   new word (with no underscores), and end with the word "Service".

namespace java org.apache.hive.service.rpc.thrift
namespace cpp apache.hive.service.rpc.thrift

// List of protocol versions. A new token should be
// added to the end of this list every time a change is made.
enum TProtocolVersion {
  // Workaround for hive-jdbc client linking with this code instead of hive-service-rpc:
  // TODO: Remove once this is moved out of org.apache.hive package.
  __HIVE_JDBC_WORKAROUND = -7

  // Test protocol version that is not recognized by clients.
  // For testing that Simba JDBC/ODBC drivers can still negotiate the connection.
  // Can be set via spark.hadoop.spark.thriftserver.serverVersion=65281 config
  __TEST_PROTOCOL_VERSION = 0xFF01

  HIVE_CLI_SERVICE_PROTOCOL_V1 = 0

  // V2 adds support for asynchronous execution
  HIVE_CLI_SERVICE_PROTOCOL_V2 = 1

  // V3 add varchar type, primitive type qualifiers
  HIVE_CLI_SERVICE_PROTOCOL_V3 = 2

  // V4 add decimal precision/scale, char type
  HIVE_CLI_SERVICE_PROTOCOL_V4 = 3

  // V5 adds error details when GetOperationStatus returns in error state
  HIVE_CLI_SERVICE_PROTOCOL_V5 = 4

  // V6 uses binary type for binary payload (was string) and uses columnar result set
  HIVE_CLI_SERVICE_PROTOCOL_V6 = 5

  // V7 adds support for delegation token based connection
  HIVE_CLI_SERVICE_PROTOCOL_V7 = 6

  // V8 adds support for interval types
  HIVE_CLI_SERVICE_PROTOCOL_V8 = 7

  // V9 adds support for serializing ResultSets in SerDe
  HIVE_CLI_SERVICE_PROTOCOL_V9 = 8

  // V10 adds support for in place updates via GetOperationStatus
  HIVE_CLI_SERVICE_PROTOCOL_V10 = 9

  // Spark protocol versions enhancements
  // Version format: 0xA5XX

  // Spark V1:
  // - On top of HIVE_CLI_SERVICE_PROTOCOL_V8
  // - Adds optional list<TGetInfoType> getInfos to TOpenSessionReq
  //   and responds with list<TGetInfoValue> getInfos in TOpenSessionResp
  // - Adds TSparkGetDirectResults to TExecuteStatementReq and other operation req.
  //   Responds with TSparkDirectResults, which shortcuts the sequence of
  //   GetOperationStatus, GetResultSetMetadata, FetchResults and CloseOperation,
  //   normally triggered by operation requests.
  // - Changes semantics of TFetchResultsResp.hasMoreRows:
  //   - If hasMoreRows == false, there are no more rows
  //   - If hasMoreRows == true, there may be more rows, even if returned row count is 0
  //   (Hive protocol always returned hasMoreRows == false)
  //   This way, an empty FetchResults is not needed at end of fetching, while an empty fetch
  //   result may not always mean end of results.
  SPARK_CLI_SERVICE_PROTOCOL_V1 = 0xA501

  // Spark V2:
  // - Rebases the changes on top of HIVE_CLI_SERVICE_PROTOCOL_V10
  SPARK_CLI_SERVICE_PROTOCOL_V2 = 0xA502

  // Spark V3:
  // - Adds result fetching via cloud object stores
  SPARK_CLI_SERVICE_PROTOCOL_V3 = 0xA503

  // Spark V4:
  // - Adds the support for multiple catalogs in metadata operations
  SPARK_CLI_SERVICE_PROTOCOL_V4 = 0xA504

  // Spark V5:
  // - Return Arrow metadata in TGetResultSetMetadataResp
  // - Shortcut to return resultSetMetadata from FetchResults
  // - Support for Arrow types for Timestamp, Decimal and complex types
  SPARK_CLI_SERVICE_PROTOCOL_V5 = 0xA505

  // Spark V6:
  // - Returns compressed Arrow batches
  // - Adds support for async execution of metadata operations
  SPARK_CLI_SERVICE_PROTOCOL_V6 = 0xA506

  // Spark V7:
  // - Add resultPersistenceMode flag to TExecuteStatementReq
  SPARK_CLI_SERVICE_PROTOCOL_V7 = 0xA507

  // Spark V8:
  // - Add support for Parameterized Queries
  SPARK_CLI_SERVICE_PROTOCOL_V8 = 0xA508

  // Spark V9:
  // - Add support for async metadata operations
  SPARK_CLI_SERVICE_PROTOCOL_V9 = 0xA509
}

enum TTypeId {
  BOOLEAN_TYPE,
  TINYINT_TYPE,
  SMALLINT_TYPE,
  INT_TYPE,
  BIGINT_TYPE,
  FLOAT_TYPE,
  DOUBLE_TYPE,
  STRING_TYPE,
  TIMESTAMP_TYPE,
  BINARY_TYPE,
  ARRAY_TYPE,
  MAP_TYPE,
  STRUCT_TYPE,
  UNION_TYPE,
  USER_DEFINED_TYPE,
  DECIMAL_TYPE,
  NULL_TYPE,
  DATE_TYPE,
  VARCHAR_TYPE,
  CHAR_TYPE,
  INTERVAL_YEAR_MONTH_TYPE,
  INTERVAL_DAY_TIME_TYPE
}

const set<TTypeId> PRIMITIVE_TYPES = [
  TTypeId.BOOLEAN_TYPE,
  TTypeId.TINYINT_TYPE,
  TTypeId.SMALLINT_TYPE,
  TTypeId.INT_TYPE,
  TTypeId.BIGINT_TYPE,
  TTypeId.FLOAT_TYPE,
  TTypeId.DOUBLE_TYPE,
  TTypeId.STRING_TYPE,
  TTypeId.TIMESTAMP_TYPE,
  TTypeId.BINARY_TYPE,
  TTypeId.DECIMAL_TYPE,
  TTypeId.NULL_TYPE,
  TTypeId.DATE_TYPE,
  TTypeId.VARCHAR_TYPE,
  TTypeId.CHAR_TYPE,
  TTypeId.INTERVAL_YEAR_MONTH_TYPE,
  TTypeId.INTERVAL_DAY_TIME_TYPE
]

const set<TTypeId> COMPLEX_TYPES = [
  TTypeId.ARRAY_TYPE
  TTypeId.MAP_TYPE
  TTypeId.STRUCT_TYPE
  TTypeId.UNION_TYPE
  TTypeId.USER_DEFINED_TYPE
]

const set<TTypeId> COLLECTION_TYPES = [
  TTypeId.ARRAY_TYPE
  TTypeId.MAP_TYPE
]

const map<TTypeId,string> TYPE_NAMES = {
  TTypeId.BOOLEAN_TYPE: "BOOLEAN",
  TTypeId.TINYINT_TYPE: "TINYINT",
  TTypeId.SMALLINT_TYPE: "SMALLINT",
  TTypeId.INT_TYPE: "INT",
  TTypeId.BIGINT_TYPE: "BIGINT",
  TTypeId.FLOAT_TYPE: "FLOAT",
  TTypeId.DOUBLE_TYPE: "DOUBLE",
  TTypeId.STRING_TYPE: "STRING",
  TTypeId.TIMESTAMP_TYPE: "TIMESTAMP",
  TTypeId.BINARY_TYPE: "BINARY",
  TTypeId.ARRAY_TYPE: "ARRAY",
  TTypeId.MAP_TYPE: "MAP",
  TTypeId.STRUCT_TYPE: "STRUCT",
  TTypeId.UNION_TYPE: "UNIONTYPE",
  TTypeId.DECIMAL_TYPE: "DECIMAL",
  TTypeId.NULL_TYPE: "NULL"
  TTypeId.DATE_TYPE: "DATE"
  TTypeId.VARCHAR_TYPE: "VARCHAR"
  TTypeId.CHAR_TYPE: "CHAR"
  TTypeId.INTERVAL_YEAR_MONTH_TYPE: "INTERVAL_YEAR_MONTH"
  TTypeId.INTERVAL_DAY_TIME_TYPE: "INTERVAL_DAY_TIME"
}

// Thrift does not support recursively defined types or forward declarations,
// which makes it difficult to represent Hive's nested types.
// To get around these limitations TTypeDesc employs a type list that maps
// integer "pointers" to TTypeEntry objects. The following examples show
// how different types are represented using this scheme:
//
// "INT":
// TTypeDesc {
//   types = [
//     TTypeEntry.primitive_entry {
//       type = INT_TYPE
//     }
//   ]
// }
//
// "ARRAY<INT>":
// TTypeDesc {
//   types = [
//     TTypeEntry.array_entry {
//       object_type_ptr = 1
//     },
//     TTypeEntry.primitive_entry {
//       type = INT_TYPE
//     }
//   ]
// }
//
// "MAP<INT,STRING>":
// TTypeDesc {
//   types = [
//     TTypeEntry.map_entry {
//       key_type_ptr = 1
//       value_type_ptr = 2
//     },
//     TTypeEntry.primitive_entry {
//       type = INT_TYPE
//     },
//     TTypeEntry.primitive_entry {
//       type = STRING_TYPE
//     }
//   ]
// }

typedef i32 TTypeEntryPtr

// Valid TTypeQualifiers key names
const string CHARACTER_MAXIMUM_LENGTH = "characterMaximumLength"

// Type qualifier key name for decimal
const string PRECISION = "precision"
const string SCALE = "scale"

union TTypeQualifierValue {
  1: optional i32 i32Value
  2: optional string stringValue
}

// Type qualifiers for primitive type.
struct TTypeQualifiers {
  1: required map <string, TTypeQualifierValue> qualifiers
}

// Type entry for a primitive type.
struct TPrimitiveTypeEntry {
  // The primitive type token. This must satisfy the condition
  // that type is in the PRIMITIVE_TYPES set.
  1: required TTypeId type
  2: optional TTypeQualifiers typeQualifiers
}

// Type entry for an ARRAY type.
struct TArrayTypeEntry {
  1: required TTypeEntryPtr objectTypePtr
}

// Type entry for a MAP type.
struct TMapTypeEntry {
  1: required TTypeEntryPtr keyTypePtr
  2: required TTypeEntryPtr valueTypePtr
}

// Type entry for a STRUCT type.
struct TStructTypeEntry {
  1: required map<string, TTypeEntryPtr> nameToTypePtr
}

// Type entry for a UNIONTYPE type.
struct TUnionTypeEntry {
  1: required map<string, TTypeEntryPtr> nameToTypePtr
}

struct TUserDefinedTypeEntry {
  // The fully qualified name of the class implementing this type.
  1: required string typeClassName
}

// We use a union here since Thrift does not support inheritance.
union TTypeEntry {
  1: TPrimitiveTypeEntry primitiveEntry
  2: TArrayTypeEntry arrayEntry
  3: TMapTypeEntry mapEntry
  4: TStructTypeEntry structEntry
  5: TUnionTypeEntry unionEntry
  6: TUserDefinedTypeEntry userDefinedTypeEntry
}

// Type descriptor for columns.
struct TTypeDesc {
  // The "top" type is always the first element of the list.
  // If the top type is an ARRAY, MAP, STRUCT, or UNIONTYPE
  // type, then subsequent elements represent nested types.
  1: required list<TTypeEntry> types
}

// A result set column descriptor.
struct TColumnDesc {
  // The name of the column
  1: required string columnName

  // The type descriptor for this column
  2: required TTypeDesc typeDesc

  // The ordinal position of this column in the schema
  3: required i32 position

  4: optional string comment
}

// Metadata used to describe the schema (column names, types, comments)
// of result sets.
struct TTableSchema {
  1: required list<TColumnDesc> columns
}

// A Boolean column value.
struct TBoolValue {
  // NULL if value is unset.
  1: optional bool value
}

// A Byte column value.
struct TByteValue {
  // NULL if value is unset.
  1: optional byte value
}

// A signed, 16 bit column value.
struct TI16Value {
  // NULL if value is unset
  1: optional i16 value
}

// A signed, 32 bit column value
struct TI32Value {
  // NULL if value is unset
  1: optional i32 value
}

// A signed 64 bit column value
struct TI64Value {
  // NULL if value is unset
  1: optional i64 value
}

// A floating point 64 bit column value
struct TDoubleValue {
  // NULL if value is unset
  1: optional double value
}

struct TStringValue {
  // NULL if value is unset
  1: optional string value
}

// A single column value in a result set.
// Note that Hive's type system is richer than Thrift's,
// so in some cases we have to map multiple Hive types
// to the same Thrift type. On the client-side this is
// disambiguated by looking at the Schema of the
// result set.
union TColumnValue {
  1: TBoolValue   boolVal      // BOOLEAN
  2: TByteValue   byteVal      // TINYINT
  3: TI16Value    i16Val       // SMALLINT
  4: TI32Value    i32Val       // INT
  5: TI64Value    i64Val       // BIGINT, TIMESTAMP
  6: TDoubleValue doubleVal    // FLOAT, DOUBLE
  7: TStringValue stringVal    // STRING, LIST, MAP, STRUCT, UNIONTYPE, BINARY, DECIMAL, NULL, INTERVAL_YEAR_MONTH, INTERVAL_DAY_TIME
}

// Represents a row in a rowset.
struct TRow {
  1: required list<TColumnValue> colVals
}

struct TBoolColumn {
  1: required list<bool> values
  2: required binary nulls
}

struct TByteColumn {
  1: required list<byte> values
  2: required binary nulls
}

struct TI16Column {
  1: required list<i16> values
  2: required binary nulls
}

struct TI32Column {
  1: required list<i32> values
  2: required binary nulls
}

struct TI64Column {
  1: required list<i64> values
  2: required binary nulls
}

struct TDoubleColumn {
  1: required list<double> values
  2: required binary nulls
}

struct TStringColumn {
  1: required list<string> values
  2: required binary nulls
}

struct TBinaryColumn {
  1: required list<binary> values
  2: required binary nulls
}

// Note that Hive's type system is richer than Thrift's,
// so in some cases we have to map multiple Hive types
// to the same Thrift type. On the client-side this is
// disambiguated by looking at the Schema of the
// result set.
union TColumn {
  1: TBoolColumn   boolVal      // BOOLEAN
  2: TByteColumn   byteVal      // TINYINT
  3: TI16Column    i16Val       // SMALLINT
  4: TI32Column    i32Val       // INT
  5: TI64Column    i64Val       // BIGINT, TIMESTAMP
  6: TDoubleColumn doubleVal    // FLOAT, DOUBLE
  7: TStringColumn stringVal    // STRING, LIST, MAP, STRUCT, UNIONTYPE, DECIMAL, NULL
  8: TBinaryColumn binaryVal    // BINARY
}

// Represents the RowSet implementation used by the Thrift
// server to return results to the client.
enum TSparkRowSetType {
  // the ArrowBasedSet format that returns a list of Arrow batches
  ARROW_BASED_SET,
  // the ColumnBasedSet format that returns a list of columns
  COLUMN_BASED_SET,
  // deprecated, added for completeness
  ROW_BASED_SET,
  // expect downloadable results in serialized Arrow format
  URL_BASED_SET
}

enum TDBSqlCompressionCodec {
  // compression unused
  NONE,
  // inline Arrow batches
  LZ4_FRAME,
  // Cloud Fetch files
  LZ4_BLOCK
}

struct TDBSqlJsonArrayFormat {
  1: optional TDBSqlCompressionCodec compressionCodec
}

struct TDBSqlCsvFormat {
  1: optional TDBSqlCompressionCodec compressionCodec
}

enum TDBSqlArrowLayout {
  ARROW_BATCH, // Only supported for inline results
  ARROW_STREAMING // Supported for both inline and url-based results
}

struct TDBSqlArrowFormat {
  1: optional TDBSqlArrowLayout arrowLayout
  2: optional TDBSqlCompressionCodec compressionCodec
}

// Result format for the query. Delivery mode can be either inline or external links.
union TDBSqlResultFormat {
  1: TDBSqlArrowFormat arrowFormat
  2: TDBSqlCsvFormat csvFormat
  3: TDBSqlJsonArrayFormat jsonArrayFormat
}

// Represents an Arrow record batch and the number of rows
// that are serialized in the batch
struct TSparkArrowBatch {
  1: required binary batch
  2: required i64 rowCount
}

struct TSparkArrowResultLink {
  // the download URL
  1: required string fileLink
  // UTC offset in milliseconds
  2: required i64 expiryTime
  // the row offset in the complete row set
  3: required i64 startRowOffset
  // the total number of rows included in the file
  4: required i64 rowCount
  // the size in bytes of all uncompressed Arrow batches in the file
  5: required i64 bytesNum
  // http headers
  6: optional map<string, string> httpHeaders
}

// Metadata of a cloud file in a cloud fetch result, used to populate result manifest
// and enable fetching results from control plane.
struct TDBSqlCloudResultFile {
  // path of the file in cloud storage; should not be logged
  1: optional string filePath
  // the row offset in the complete row set
  2: optional i64 startRowOffset
  // the total number of rows included in the file
  3: optional i64 rowCount
  // the size in bytes of all uncompressed Arrow batches in the file
  4: optional i64 uncompressedBytes
  // the size in bytes of all compressed Arrow batches in the file
  // (if compression is disabled, the value is equal to uncompressedBytes)
  5: optional i64 compressedBytes
  // download Link for the file
  6: optional string fileLink
  // expiry time of the download link (UTC offset in milliseconds)
  7: optional i64 linkExpiryTime
  // http headers
  8: optional map<string, string> httpHeaders
}

// Represents a rowset
struct TRowSet {
  // The starting row offset of this rowset.
  1: required i64 startRowOffset
  2: required list<TRow> rows
  3: optional list<TColumn> columns
  4: optional binary binaryColumns
  5: optional i32 columnCount
  0x501: optional list<TSparkArrowBatch> arrowBatches;
  // list of files including a set of consecutive Arrow batches
  0x502: optional list<TSparkArrowResultLink> resultLinks;
  // Metadata of cloud fetch result files which may include the file paths
  // in cloud storage and/or external download links for those files
  0xD01: optional list<TDBSqlCloudResultFile> cloudFetchResults;
  // Small result set that can be inlined in the response. This
  // is the same binary data that is written directly to cloud storage.
  0xD02: optional binary smallInlineCloudResult;
  // Row count field for non list<> based results (ex: binary smallInlineCloudResult).
  0xD03: optional i64 rowCount;
}

// Represents a temp view
struct TDBSqlTempView {
  1: optional string name
  2: optional string sqlStatement
  3: optional map<string, string> properties
  // View schema as JSON
  4: optional string viewSchema
  5: optional string tableType
}

// Represents the set of session capabilities
struct TDBSqlSessionCapabilities {
  1: optional bool supportsMultipleCatalogs
}

// Represents catalyst ExpressionInfo used for serde for temporary
// SQL and Python functions. All instance fields in ExpressionInfo should
// map to fields here.
struct TExpressionInfo {
    1: optional string className
    2: optional string usage
    3: optional string name
    4: optional string extended
    5: optional string db
    6: optional string arguments
    7: optional string examples
    8: optional string note
    9: optional string group
    10: optional string since
    11: optional string deprecated
    12: optional string source
}

// An TDBSqlConfValue represents the value for the respective spark conf,
// along with some metadata which can be used to determine if and how the value
// should be used.
struct TDBSqlConfValue {
  1: optional string value
}

// Represents a SQL variable.
struct TSQLVariable {
  // name of the catalog
  1: optional TIdentifier catalogName
  // name of the schema
  2: optional TIdentifier schemaName
  // name of the variable
  3: optional TIdentifier variableName

  // the default expression sql of the variable
  4: optional string defaultExpressionSQL
  // the serialized data type of the variable
  5: optional string variableDataType
  // the serialized current value of the variable
  6: optional string currentValue
}

// Represents the state of the MST (Multi-Statement Transaction) for a session
struct TDBSqlMSTConf {
  1: optional string txnId
  2: optional string serializedMSTState
  3: optional bool isAborted
  // e.g. transaction timed out, query failed, ongoing query canceled etc.
  4: optional string abortReason
  // The version of the serialization format used to serialize the MST state to serializedMSTState.
  // This is used to determine how to deserialize the state.
  5: optional i32 serializationVersion
}

// Used by DBR to relay info on transaction boundaries(start/end) to sql gateway
// It helps with concurrent queries resulting in concurrent session state updates
// in SQL Gateway (by a compareAndSet approach) for xDBC.
// Design doc - go/sqlgwXdbcMst
struct TDBSqlMSTControlBits {
  1: optional string prevTxnId
  2: optional string newTxnId
}

struct TDBSqlTempTableNamespace {
  1: optional string catalogName
  2: optional string schemaName
}

struct TDBSqlAutoCommitConf {
  1: optional bool autoCommit
}

// Represents session configuration properties
struct TDBSqlSessionConf {
  1: optional map<string, string> confs
  2: optional list<TDBSqlTempView> tempViews
  3: optional string currentDatabase
  4: optional string currentCatalog
  5: optional TDBSqlSessionCapabilities sessionCapabilities
  6: optional list<TExpressionInfo> expressionsInfos
  7: optional map<string, TDBSqlConfValue> internalConfs
  8: optional list<TSQLVariable> tempVariables
  // One DBSql Session can have up to one MST (Multi-Statement Transaction) active at a time.
  9: optional TDBSqlMSTConf mstConf
  10: optional TDBSqlTempTableNamespace tempTableNamespace
  11: optional TDBSqlMSTControlBits mstControlBits
  12: optional TDBSqlAutoCommitConf autoCommitConf
}

// Represents the idempotency type of an operation
enum TOperationIdempotencyType {
  UNKNOWN,
  NON_IDEMPOTENT,
  IDEMPOTENT
}

// Represents which level a timeout enforced on an operation is defined
enum TOperationTimeoutLevel {
  CLUSTER,
  SESSION
}

// The return status code contained in each response.
enum TStatusCode {
  SUCCESS_STATUS,
  SUCCESS_WITH_INFO_STATUS,
  STILL_EXECUTING_STATUS,
  ERROR_STATUS,
  INVALID_HANDLE_STATUS
}

// The return status of a remote request
struct TStatus {
  1: required TStatusCode statusCode

  // If status is SUCCESS_WITH_INFO, info_msgs may be populated with
  // additional diagnostic information.
  2: optional list<string> infoMessages

  // If status is ERROR, then the following fields may be set
  3: optional string sqlState  // as defined in the ISO/IEF CLI specification
  4: optional i32 errorCode    // internal error code
  5: optional string errorMessage

  // The preferred error message for displaying in user interfaces.
  6: optional string displayMessage

  // Optional additional error details in JSON format (e.g. error class, query context).
  // Applications should avoid displaying this to the end user
  0x501: optional string errorDetailsJson

  // Binary blob representing the checksum of the main response.
  0xD01: optional binary responseValidation

  // Whether the response was served off of the response cache.
  0xD02: optional bool servedByResponseCache
}

// The state of an operation (i.e. a query or other
// asynchronous operation that generates a result set)
// on the server.
enum TOperationState {
  // The operation has been initialized
  INITIALIZED_STATE,

  // The operation is running. In this state the result
  // set is not available.
  RUNNING_STATE,

  // The operation has completed. When an operation is in
  // this state its result set may be fetched.
  FINISHED_STATE,

  // The operation was canceled by a client
  CANCELED_STATE,

  // The operation was closed by a client
  CLOSED_STATE,

  // The operation failed due to an error
  ERROR_STATE,

  // The operation is in an unrecognized state
  UKNOWN_STATE,

  // The operation is in an pending state
  PENDING_STATE,

  // The operation is in an timedout state
  TIMEDOUT_STATE,
}

// A string identifier. This is interpreted literally.
typedef string TIdentifier

// A search pattern.
//
// Valid search pattern characters:
// '_': Any single character.
// '%': Any sequence of zero or more characters.
// '\': Escape character used to include special characters,
//      e.g. '_', '%', '\'. If a '\' precedes a non-special
//      character it has no special meaning and is interpreted
//      literally.
typedef string TPattern


// A search pattern or identifier. Used as input
// parameter for many of the catalog functions.
typedef string TPatternOrIdentifier

struct TNamespace {
  1: optional TIdentifier catalogName
  2: optional TIdentifier schemaName
}

struct THandleIdentifier {
  // 16 byte globally unique identifier
  // This is the public ID of the handle and
  // can be used for reporting.
  1: required binary guid,

  // 16 byte secret generated by the server
  // and used to verify that the handle is not
  // being hijacked by another user.
  2: required binary secret,

  // Stores the execution version of the query. The execution version is used to keep track of the
  // number of query migrations a query experienced, and is incremented each time a query is
  // migrated. This will be used to resolve race conditions with query migration involving migrating
  // to the same cluster.
  0xD01: optional i16 executionVersion
}

// Client-side handle to persistent
// session information on the server-side.
struct TSessionHandle {
  1: required THandleIdentifier sessionId

  // client protocol version, this is used for auto session reopen if
  // the corresponding session does not exists on the driver.
  // This is currently used by sqlgateway cluster.
  0xD01: optional TProtocolVersion serverProtocolVersion
}

// The subtype of an OperationHandle.
enum TOperationType {
  EXECUTE_STATEMENT,
  GET_TYPE_INFO,
  GET_CATALOGS,
  GET_SCHEMAS,
  GET_TABLES,
  GET_TABLE_TYPES,
  GET_COLUMNS,
  GET_FUNCTIONS,
  UNKNOWN,
}

// Client-side reference to a task running
// asynchronously on the server.
struct TOperationHandle {
  1: required THandleIdentifier operationId
  2: required TOperationType operationType

  // If hasResultSet = TRUE, then this operation
  // generates a result set that can be fetched.
  // Note that the result set may be empty.
  //
  // If hasResultSet = FALSE, then this operation
  // does not generate a result set, and calling
  // GetResultSetMetadata or FetchResults against
  // this OperationHandle will generate an error.
  3: required bool hasResultSet

  // For operations that don't generate result sets,
  // modifiedRowCount is either:
  //
  // 1) The number of rows that were modified by
  //    the DML operation (e.g. number of rows inserted,
  //    number of rows deleted, etc).
  //
  // 2) 0 for operations that don't modify or add rows.
  //
  // 3) < 0 if the operation is capable of modifiying rows,
  //    but Hive is unable to determine how many rows were
  //    modified. For example, Hive's LOAD DATA command
  //    doesn't generate row count information because
  //    Hive doesn't inspect the data as it is loaded.
  //
  // modifiedRowCount is unset if the operation generates
  // a result set.
  4: optional double modifiedRowCount
}


// OpenSession()
//
// Open a session (connection) on the server against
// which operations may be executed.
struct TOpenSessionReq {
  // The version of the HiveServer2 protocol that the client is using.
  // 1. If client_protocol_i64 is not set by the incoming TOpenSessionReq request, it means the client
  // is using a protocol version that is numerically lower or equal to SPARK_CLI_SERVICE_PROTOCOL_V2 to
  // connect. Thus, the server version is the minimum between the server default protocol version and
  // SPARK_CLI_SERVICE_PROTOCOL_V2.
  // --> 1.1 If client_protocol is unset, it means that the client wants the server to pick the version,
  // and so the server will respond with the server version.
  // --> 1.2 Otherwise, the server responds with a version being the minimum of client and server versions.
  // 2. Otherwise, the server responds with a version being the minimum of client_protocol_i64 and
  // the server default protocol version. The server knows any client version that is smaller than its
  // default serverVersion. If the client_protocol_i64 field is set it also overrides the value set by
  // the client_protocol field.
  //
  // FIXME:
  // Workaround for hive-jdbc client linking with this code instead of hive-service-rpc:
  // Because this code is in org.apache.hive.service.cli.thrift, hive-jdbc package
  // uses it, instead of true Hive code from hive-service-rpc.
  // We want the default in the server to be unset (so that the server chooses), but Hive JDBC client
  // needs to set it.
  // We hack it around manually in the generated code for TOpenSessionReq:
  // __HIVE_JDBC_WORKAROUND is turned into:
  // - HIVE_CLI_PROTOCOL_V8 in TOpenSessionReqStandardScheme.write (in the client)
  //   (because hive-jdbc needs to set it to the Hive protocol it supports)
  // - TOpenSessionReqStandardScheme.read (in the server) unsets it
  //   (because we want to return the server version when it's not set)
  // Note: this has to be manually updated when the thrift code is generated.
  // TODO (DBR 7.0): Remove once this is moved out of org.apache.hive package.
  1: optional TProtocolVersion client_protocol = TProtocolVersion.__HIVE_JDBC_WORKAROUND

  // Username and password for authentication.
  // Depending on the authentication scheme being used,
  // this information may instead be provided by a lower
  // protocol layer, in which case these fields may be
  // left unset.
  2: optional string username
  3: optional string password

  // Configuration overlay which is applied when the session is
  // first created.
  4: optional map<string, string> configuration

  // List of GetInfo calls to directly ask during opening of session
  0x501: optional list<TGetInfoType> getInfos

  // This flag allows clients to advertise their version to the server
  0x502: optional i64 client_protocol_i64

  // Any additional connection related information passed on by the driver.
  0x503: optional map<string, string> connectionProperties

  // Allows clients to request to open the initial session in the predetermined default namespace.
  // The server shall open the session in the requested namespace.
  0x504: optional TNamespace initialNamespace

  // Should be true if the client can support multiple catalogs
  0x505: optional bool canUseMultipleCatalogs

  // sessionId is added to take an Identifier generated by client. This field
  // is only used by SQL Gateway service for the following purpose:
  // 1) use the same identifier in control plane as in thrift without waiting
  //    for the response.
  // 2) allow same session identifier to be used for different thrift sessions
  //    on different cluster. With SQL Gateway service, we will open sessions on
  //    more than one clusters for one user sessions.
  0xD01: optional THandleIdentifier sessionId
}

struct TOpenSessionResp {
  1: required TStatus status

  // The protocol version that the server is using.
  2: required TProtocolVersion serverProtocolVersion

  // Session Handle
  3: optional TSessionHandle sessionHandle

  // The configuration settings for this session.
  4: optional map<string, string> configuration

  // The initial namespace of the session.
  0x504: optional TNamespace initialNamespace

  // True if the client and server can support multiple catalogs
  0x505: optional bool canUseMultipleCatalogs

  // List of GetInfo responses (positionally aligned with getInfos in TOpenSessionReq)
  0x501: optional list<TGetInfoValue> getInfos
}


// CloseSession()
//
// Closes the specified session and frees any resources
// currently allocated to that session. Any open
// operations in that session will be canceled.
struct TCloseSessionReq {
  1: required TSessionHandle sessionHandle
}

struct TCloseSessionResp {
  1: required TStatus status
}



enum TGetInfoType {
  CLI_MAX_DRIVER_CONNECTIONS =           0,
  CLI_MAX_CONCURRENT_ACTIVITIES =        1,
  CLI_DATA_SOURCE_NAME =                 2,
  CLI_FETCH_DIRECTION =                  8,
  CLI_SERVER_NAME =                      13,
  CLI_SEARCH_PATTERN_ESCAPE =            14,
  CLI_DBMS_NAME =                        17,
  CLI_DBMS_VER =                         18,
  CLI_ACCESSIBLE_TABLES =                19,
  CLI_ACCESSIBLE_PROCEDURES =            20,
  CLI_CURSOR_COMMIT_BEHAVIOR =           23,
  CLI_DATA_SOURCE_READ_ONLY =            25,
  CLI_DEFAULT_TXN_ISOLATION =            26,
  CLI_IDENTIFIER_CASE =                  28,
  CLI_IDENTIFIER_QUOTE_CHAR =            29,
  CLI_MAX_COLUMN_NAME_LEN =              30,
  CLI_MAX_CURSOR_NAME_LEN =              31,
  CLI_MAX_SCHEMA_NAME_LEN =              32,
  CLI_MAX_CATALOG_NAME_LEN =             34,
  CLI_MAX_TABLE_NAME_LEN =               35,
  CLI_SCROLL_CONCURRENCY =               43,
  CLI_TXN_CAPABLE =                      46,
  CLI_USER_NAME =                        47,
  CLI_TXN_ISOLATION_OPTION =             72,
  CLI_INTEGRITY =                        73,
  CLI_GETDATA_EXTENSIONS =               81,
  CLI_NULL_COLLATION =                   85,
  CLI_ALTER_TABLE =                      86,
  CLI_ORDER_BY_COLUMNS_IN_SELECT =       90,
  CLI_SPECIAL_CHARACTERS =               94,
  CLI_MAX_COLUMNS_IN_GROUP_BY =          97,
  CLI_MAX_COLUMNS_IN_INDEX =             98,
  CLI_MAX_COLUMNS_IN_ORDER_BY =          99,
  CLI_MAX_COLUMNS_IN_SELECT =            100,
  CLI_MAX_COLUMNS_IN_TABLE =             101,
  CLI_MAX_INDEX_SIZE =                   102,
  CLI_MAX_ROW_SIZE =                     104,
  CLI_MAX_STATEMENT_LEN =                105,
  CLI_MAX_TABLES_IN_SELECT =             106,
  CLI_MAX_USER_NAME_LEN =                107,
  CLI_OJ_CAPABILITIES =                  115,

  CLI_XOPEN_CLI_YEAR =                   10000,
  CLI_CURSOR_SENSITIVITY =               10001,
  CLI_DESCRIBE_PARAMETER =               10002,
  CLI_CATALOG_NAME =                     10003,
  CLI_COLLATION_SEQ =                    10004,
  CLI_MAX_IDENTIFIER_LEN =               10005,
  CLI_ODBC_KEYWORDS =                    10006,
}

union TGetInfoValue {
  1: string stringValue
  2: i16 smallIntValue
  3: i32 integerBitmask
  4: i32 integerFlag
  5: i32 binaryValue
  6: i64 lenValue
}

// GetInfo()
//
// This function is based on ODBC's CLIGetInfo() function.
// The function returns general information about the data source
// using the same keys as ODBC.
struct TGetInfoReq {
  // The sesssion to run this request against
  1: required TSessionHandle sessionHandle

  2: required TGetInfoType infoType

  0xD01: optional TDBSqlSessionConf sessionConf
}

struct TGetInfoResp {
  1: required TStatus status

  2: required TGetInfoValue infoValue
}

// TSparkGetDirectResults / TSparkDirectResults
//
// Short-cutting GetOperationStatus, GetResultSetMetadata, FetchResults and CloseOperation
// If in request getDirectResults field is set, a response field directResults
// will be set, and contain:
// - the server will directly call a GetOperationStatus and return a GetOperationStatusResp
//   in directResults.operationStatus
// - then, if the query already finished:
//   - If it has a result set (operationHandle.hasResultSet == true):
//     - the server will immediately call GetResultSetMetadata and set
//       TGetResultSetMetadataResp in directResults.resultSetMetadata
//     - if getDirectResults.maxRows > 0 and the client does not request skipping fetching URL
//       results with skipUrlResults, the server will immediately call FetchResults
//       (also passing getDirectResults.maxBytes, if set) and return TFetchResultsResp,
//       with the initial fetched rows in directResults.resultSet.
//     - then, if the result set was returned with complete results of the operation
//       (resultSet.hasMoreRows == false), the server will call CloseOperation and return
//       TCloseOperationResp in directResults.closeOperation.
//   - If it does not have a results set (operationHandle.hasResultSet == false), the server will
//     perform CloseOperation return TCloseOperationResp in directResults.closeOperation.
//     - Note: in this case, fields directResults.resultSetMetadata and
//       directResults.resultSet will remain unset
//     - Note: operations without result sets do not return any rows, so
//       getDirectResults.maxRows may be set to any value in this case; the feature is
//       triggered by the getDirectResults field being set.
// Each response is equivalent to the server calling GetOperationStatus, GetResultSetMetadata,
// FetchResults and CloseOperation, just like if the client sequentially called it after the initial
// operation request, and should be handled by the client as such.
// If any of the response fields is not set, the client should continue from that point, as if it had
// received the last set response.
struct TSparkGetDirectResults {
  // Max number of rows that should be fetched directly
  // If 0, do not do FetchResults
  1: required i64 maxRows

  // The maximum number of bytes that should be returned in the row set
  2: optional i64 maxBytes

  // Whether to include the initial set of URLs in case of a cloud based result in the direct
  // result response. Default behavior is to include unless the field is explicitly set to true.
  0xD01: optional bool skipUrlResults

  // Whether to include resultFiles in resultSetMetadata of the direct result response in case
  // of a cloud based result. resultFiles will not be included by default unless the field is
  // explicitly set to true.
  0xD02: optional bool includeCloudResultFiles
}

struct TSparkDirectResults {
  1: optional TGetOperationStatusResp operationStatus
  2: optional TGetResultSetMetadataResp resultSetMetadata
  3: optional TFetchResultsResp resultSet
  4: optional TCloseOperationResp closeOperation
}

struct TSparkArrowTypes {
 1: optional bool timestampAsArrow
 2: optional bool decimalAsArrow
 3: optional bool complexTypesAsArrow
 4: optional bool intervalTypesAsArrow
 5: optional bool nullTypeAsArrow
 6: optional bool geospatialAsArrow
}

enum TResultPersistenceMode {
  // Only write large results to cloud storage.
  ONLY_LARGE_RESULTS,

  // Write all results to cloud storage except for command results.
  ALL_QUERY_RESULTS,

  // Write all results to cloud storage.
  ALL_RESULTS
}

// ExecuteStatement()
//
// Execute a statement.
// The returned OperationHandle can be used to check on the
// status of the statement, and to fetch results once the
// statement has finished executing.
struct TExecuteStatementReq {
  // The session to execute the statement against
  1: required TSessionHandle sessionHandle

  // The statement to be executed (DML, DDL, SET, etc)
  2: required string statement

  // Configuration properties that are overlayed on top of the
  // the existing session configuration before this statement
  // is executed. These properties apply to this statement
  // only and will not affect the subsequent state of the Session.
  // Deprecation warning: this way of passing session configurations
  // is not supported and may cause undesired behaviour.
  3: optional map<string, string> confOverlay
  (deprecated)

  // Execute asynchronously when runAsync is true
  4: optional bool runAsync = false

  // Directly return initial operation results, see TSparkDirectResults
  0x501: optional TSparkGetDirectResults getDirectResults

  // The number of seconds after which the query will timeout on the server
  5: optional i64 queryTimeout = 0

  // Set the capability of the client to read Arrow serialized results
  0x502: optional bool canReadArrowResult

  // Set the capability of the client to download Arrow serialized results
  0x503: optional bool canDownloadResult

  // Set the capability of the client to read LZ4 compressed results
  0x504: optional bool canDecompressLZ4Result

  // Set the maximum size in bytes of all uncompressed Arrow batches in a file
  0x505: optional i64 maxBytesPerFile

  // Set to use Arrow dedicated types for specific types, instead of converting to string.
  0x506: optional TSparkArrowTypes useArrowNativeTypes

  // Set the maximum number of rows in the result. This limit is directly
  // applied to the query plan.
  0x507: optional i64 resultRowLimit

  // A list of parameter tuples to be substituted in the query
  0x508: optional TSparkParameterList parameters

  // Set the maximum size in bytes of a singular Arrow batch
  0x509: optional i64 maxBytesPerBatch

  // Set to use sessionless mode. Used to pass session-like configurations for sessionless
  // queries.
  0x510: optional TStatementConf statementConf

  // operationId is added to take an Identifier generated by client. This field
  // is only used by SQL Gateway service currently to allow the same identifier
  // to be used in both control plane and thrift without waiting for the response.
  0xD01: optional THandleIdentifier operationId

  0xD02: optional TDBSqlSessionConf sessionConf

  // Indicates whether the cluster should reject high cost queries.
  // If set to false, it means that query has already been queued on the SQLGateway side (the
  // source of the query is SQLGateway scheduler) and the cluster should attempt to run it.
  0xD03: optional bool rejectHighCostQueries

  // This field sends the estimated cost of a query from SQLGateway to the cluster to avoid
  // re-calculating the cost. This field is most commonly used to set the already calculated cost
  // from a rejected cluster, to avoid re-calculation on other clusters.
  0xD04: optional double estimatedCost

  // Stores the execution version of the query. The execution version is used to keep track of the
  // number of query migrations a query experienced, and is incremented each time a query is
  // migrated. This will be used to resolve race conditions with query migration involving migrating
  // to the same cluster.
  0xD05: optional i16 executionVersion
  (deprecated)

  // Binary blob representing the checksum of the main request identifiers.
  0xD06: optional binary requestValidation

  // When cloud fetch is enabled, this value determines which results are actually written to cloud.
  0xD07: optional TResultPersistenceMode resultPersistenceMode

  // When false, the last Arrow batch or cloud file may contain more rows than the limit prescribes.
  // The client (e.g. Simba JDBC/ODBC) is responsible for discarding the excess rows based on the
  // rowCount in TSparkArrowBatch or TSparkArrowResultLink.
  // When true, Thriftserver guarantees that the last batch or file does not exceed the limit, at
  // the cost of additional processing overhead.
  0xD08: optional bool trimArrowBatchesToLimit

  // Caller expresses fetch disposition of the result; use by SEA to apply e.g. INLINE fetch limits
  0xD09: optional TDBSqlFetchDisposition fetchDisposition

  // If true, Thriftserver promises to return cloud results in accordance with resultPersistenceMode
  // only. It will not disable cloud fetch for server-side reasons such as bucket versioning or
  // region support.
  0xD10: optional bool enforceResultPersistenceMode

  // A list of multiple SQL statements to be executed on DBSQL.
  // This does not work for interactive clusters.
  0xD11: optional list<TDBSqlStatement> statementList

  // Optionally persist the manifest to a file in cloud storage
  0xD12: optional bool persistResultManifest

  // If set, retain the result for the duration given in seconds from the start of execution
  // with a maximum of 31 days.
  0xD13: optional i64 resultRetentionSeconds

  // If set, limit the number of bytes of the result to this value.
  0xD14: optional i64 resultByteLimit

  // If set, results are guaranteed to be returned in this format. Otherwise result format is
  // dynamically chosen by the server based on client's capabilities.
  0xD15: optional TDBSqlResultFormat resultDataFormat

  // Contains the service identity of an internal client (e.g. redash), if present, that originated
  // this request. Main purpose is for SQL Exec API -> SQL GW communication, to allow SQL GW to
  // allowlist some features only for specific internal clients.
  0xD16: optional string originatingClientIdentity

  0xD17: optional bool preferSingleFileResult
  (deprecated)

  // If this flag is set and resultByteLimit is lower than a DBR-configured maximum (default 50MB),
  // then all results will be uploaded on the driver. The effects are:
  //   - each result file (except for the last) is of size maxBytesPerFile.
  //   - if maxBytesPerFile >= resultByteLimit, then result is guaranteed to be a single file.
  // If resultByteLimit exceeds the DBR-configured maximum, then this flag has no effect and
  // executors will still upload.
  0xD18: optional bool preferDriverOnlyUpload

  // If true, results with embedded schemas (e.g., Arrow, CSV) will always have a correct embedded
  // schema. Otherwise, QRC may return cached results with incorrect embedded schemas to improve
  // cache performance for near-identical queries with different column aliases.
  // Defaults to false to maintain previous behavior for existing clients.
  0xD19: optional bool enforceEmbeddedSchemaCorrectness = false

  // Set to allow retries for ExecuteStatement.
  // A ExecuteStatement request with the same token and session for up to 2 hours will
  // always return the previous result. Otherwise it will register as a new request.
  // This can only be set for batch requests in SQLGateway. DBR will not respect this field.
  // This must be a UUID.
  0xD20: optional string idempotencyToken

  // If set, DBR returns an error when truncating based on resultByteLimit instead of returning a
  // success with truncatedByThriftLimit set. This is set by SEA to ensure a query shows as failed
  // in the query history if its result size exceeds system limits (instead of showing as successful
  // in the history, but throwing an error in SEA).
  // Note: this flag only applies to inline Arrow or Cloud Fetch (any format) results.
  0xD21: optional bool throwErrorOnByteLimitTruncation

  // This field sends the query stats of a query from SQLGateway to the cluster to avoid
  // having to re-compute for query acceptance decision. This field is most commonly used to set the already calculated
  // query stats from a rejected cluster after the compilation is complete.
  0xD22: optional map<string, double> queryStats

  // If this field is set, DBR must ensure that the execution of this query is idempotent.
  // When it cannot guarantee, it should just fail instead of blindly executing to avoid duplicate executions of queries
  // with side effects.
  // This is set when a previous execution "might" have successfully completed.
  // This is used with executionVersion which determines the attempt number on the DBR side.
  // Note: types of queries that DBR can guarantee for idempotent execution is expected to change over time.
  0xD23: optional bool ensureIdempotency

  // If set, allow async execution of session state changing operations.
  0xD24: optional bool allowAsyncSessionStateUpdate

  // If set, the query will return small results inline while also uploading to cloud.
  0xD25: optional bool returnSmallResultsInlineWithCloudUpload

  // Set by SQL Gateway to perform an idempotent retry.
  0xD26: optional string internalIdempotencyToken

  // The attempt number of this request from SQL Gateway
  // with the same internal idempotency token. The original attempt
  // of the request with a token should be 0, and it is incremented for
  // every retry attempt with the same token.
  0xD27: optional i16 internalIdempotencyTokenAttemptNumber

  // Set by SQL Gateway to instruct ThriftServer to automatically release the internal
  // idempotency token entries from the seen cache and response cache after a command rejection.
  0xD28: optional bool releaseIdempotencyTokenOnRejection

  // sparkContextId of the cluster that is known to SQL Gateway.
  0xD29: optional string sparkContextId

  // Represents sequenceIds when sequential execution(e.g. queries in batches or MST operations) is
  // enforced among the commands submitted within a session. Sequence IDs, when present,
  // are guaranteed to increment by exactly +1 between consecutive queries in batches or MST operations.
  // When present, DBR uses this ID to ensure queries are processed in the correct sequence.
  0xD30: optional i32 sequenceId
}

// A wrapper struct for DBSQL Statement.
struct TDBSqlStatement {
  // A single SQL statement.
  1: optional string statement
}

union TSparkParameterValue {
  1: string stringValue
  2: double doubleValue
  3: bool booleanValue
}

struct TSparkParameterValueArg {
   // As with the TSparkParameter, TSparkParameterValueArg can either be simple literals (e.g. INT)
   // or complex types themselves.
   // For example, an array of INTs would be encoded as a TSparkParameter with type ARRAY and arguments
   // that are of type INT and values set to serialized integers.
   // A named struct would be encoded as a TSparkParameter with type NAMED_STRUCT and an even number of arguments
   // that are alternating between TSparkParameterValueArg with type STRING and arbitrary TSparkParameterValueArgs.
   // Note: TSparkParameterValueArg can be complex types themselves (e.g. to support arrays of structs).

   // A valid SQL type name, e.g. INT, DECIMAL(10, 5)
   // or a complex type constructor (e.g. ARRAY, NAMED_STRUCT)
   // If type is a literal type, then the key field is value
   // For complex type constructors / functions, the key field is arguments (inputs to the constructor)
   1: optional string type
   2: optional string value
   3: optional list<TSparkParameterValueArg> arguments
}

struct TSparkParameter {
  // a parameter may set either an ordinal, a name or both
  // if no ordinal or name is given the ordinals are assumed to be
  // incremental according to the given parameter order.
  1: optional i32 ordinal
  2: optional string name

  // A valid SQL type name, e.g. INT, DECIMAL(10, 5)
  // or a complex type constructor (e.g. ARRAY, NAMED_STRUCT)
  // If type is a literal type, then the key field is value
  // For complex type constructors / functions, the key field is arguments (inputs to the constructor)
  3: optional string type
  4: optional TSparkParameterValue value
  5: optional list<TSparkParameterValueArg> arguments
}

typedef list<TSparkParameter> TSparkParameterList

// Holds configs for sessionless queries that are sent from
// SQL Exec API -> SQL GW. These configs would normally be
// in a session configuration.
struct TStatementConf {
  // Enables sessionless mode. The other configs should not be
  // used unless this is set to true.
  1: optional bool sessionless
  2: optional TNamespace initialNamespace
  3: optional TProtocolVersion client_protocol
  4: optional i64 client_protocol_i64
}

struct TDBSqlExecuteStatementMSTContext {
  1: optional string txnId
}

struct TExecuteStatementResp {
  1: required TStatus status
  2: optional TOperationHandle operationHandle

  0x501: optional TSparkDirectResults directResults

  // These optional fields will be present if the query is rejected based on the cluster load.
  // They are intended only for the comminucation between clusters and SQLGateway, and should not
  // leak to the end users.
  0xD01: optional bool executionRejected
  0xD02: optional double maxClusterCapacity
  0xD03: optional double queryCost
  0xD04: optional TDBSqlSessionConf sessionConf
  0xD05: optional double currentClusterLoad
  // This optional field is set if we have the information on whether the query can be executed
  // in an idempotent way.
  0xD06: optional TOperationIdempotencyType idempotencyType

  // Following fields are used to monitor qrc-enabled traffic in realtime
  0xD07: optional bool remoteResultCacheEnabled

  0xD08: optional bool isServerless

  // A list of operation handles when multiple statements are submitted.
  // There will be a 1:1 mapping between TDBSqlStatement in the request with the handle identifiers in the response.
  0xD09: optional list<TOperationHandle> operationHandles

  // When a query is rejected, this field contains the query statistics from the physical plan of a query
  // to SQLGateway where this value gets persisted so that it gets submitted with subsequent to other clusters
  0xD10: optional map<string, double> queryStats

  // If set, it indicates there's an ongoing transaction on the session.
  0xD11: optional TDBSqlExecuteStatementMSTContext mstContext
}

// GetTypeInfo()
//
// Get information about types supported by the HiveServer instance.
// The information is returned as a result set which can be fetched
// using the OperationHandle provided in the response.
//
// Refer to the documentation for ODBC's CLIGetTypeInfo function for
// the format of the result set.
struct TGetTypeInfoReq {
  // The session to run this request against.
  1: required TSessionHandle sessionHandle

  // Directly return initial operation results, see TDBDirectResults
  0x501: optional TSparkGetDirectResults getDirectResults

  // Execute asynchronously when runAsync is true
  0x502: optional bool runAsync = false

  // operationId is added to take an Identifier generated by client. This field
  // is only used by SQL Gateway service currently to allow the same identifier
  // to be used in both control plane and thrift without waiting for the response.
  0xD01: optional THandleIdentifier operationId

  0xD02: optional TDBSqlSessionConf sessionConf
}

struct TGetTypeInfoResp {
  1: required TStatus status
  2: optional TOperationHandle operationHandle

  0x501: optional TSparkDirectResults directResults
}


// GetCatalogs()
//
// Returns the list of catalogs (databases)
// Results are ordered by TABLE_CATALOG
//
// Resultset columns :
// col1
// name: TABLE_CAT
// type: STRING
// desc: Catalog name. NULL if not applicable.
//
struct TGetCatalogsReq {
  // Session to run this request against
  1: required TSessionHandle sessionHandle

  // Directly return initial operation results, see TSparkDirectResults
  0x501: optional TSparkGetDirectResults getDirectResults

  // Execute asynchronously when runAsync is true
  0x502: optional bool runAsync = false

  // operationId is added to take an Identifier generated by client. This field
  // is only used by SQL Gateway service currently to allow the same identifier
  // to be used in both control plane and thrift without waiting for the response.
  0xD01: optional THandleIdentifier operationId

  0xD02: optional TDBSqlSessionConf sessionConf
}

struct TGetCatalogsResp {
  1: required TStatus status
  2: optional TOperationHandle operationHandle

  0x501: optional TSparkDirectResults directResults
}


// GetSchemas()
//
// Retrieves the schema names available in this database.
// The results are ordered by TABLE_CATALOG and TABLE_SCHEM.
// col1
// name: TABLE_SCHEM
// type: STRING
// desc: schema name
// col2
// name: TABLE_CATALOG
// type: STRING
// desc: catalog name
struct TGetSchemasReq {
  // Session to run this request against
  1: required TSessionHandle sessionHandle

  // Name of the catalog. Must not contain a search pattern.
  2: optional TIdentifier catalogName

  // schema name or pattern
  3: optional TPatternOrIdentifier schemaName

  // Directly return initial operation results, see TSparkDirectResults
  0x501: optional TSparkGetDirectResults getDirectResults

  // Execute asynchronously when runAsync is true
  0x502: optional bool runAsync = false

  // operationId is added to take an Identifier generated by client. This field
  // is only used by SQL Gateway service currently to allow the same identifier
  // to be used in both control plane and thrift without waiting for the response.
  0xD01: optional THandleIdentifier operationId

  0xD02: optional TDBSqlSessionConf sessionConf
}

struct TGetSchemasResp {
  1: required TStatus status
  2: optional TOperationHandle operationHandle

  0x501: optional TSparkDirectResults directResults
}


// GetTables()
//
// Returns a list of tables with catalog, schema, and table
// type information. The information is returned as a result
// set which can be fetched using the OperationHandle
// provided in the response.
// Results are ordered by TABLE_TYPE, TABLE_CAT, TABLE_SCHEM, and TABLE_NAME
//
// Result Set Columns:
//
// col1
// name: TABLE_CAT
// type: STRING
// desc: Catalog name. NULL if not applicable.
//
// col2
// name: TABLE_SCHEM
// type: STRING
// desc: Schema name.
//
// col3
// name: TABLE_NAME
// type: STRING
// desc: Table name.
//
// col4
// name: TABLE_TYPE
// type: STRING
// desc: The table type, e.g. "TABLE", "VIEW", etc.
//
// col5
// name: REMARKS
// type: STRING
// desc: Comments about the table
//
struct TGetTablesReq {
  // Session to run this request against
  1: required TSessionHandle sessionHandle

  // Name of the catalog or a search pattern.
  2: optional TPatternOrIdentifier catalogName

  // Name of the schema or a search pattern.
  3: optional TPatternOrIdentifier schemaName

  // Name of the table or a search pattern.
  4: optional TPatternOrIdentifier tableName

  // List of table types to match
  // e.g. "TABLE", "VIEW", "SYSTEM TABLE", "GLOBAL TEMPORARY",
  // "LOCAL TEMPORARY", "ALIAS", "SYNONYM", etc.
  5: optional list<string> tableTypes

  // Directly return initial operation results, see TSparkDirectResults
  0x501: optional TSparkGetDirectResults getDirectResults

  // Execute asynchronously when runAsync is true
  0x502: optional bool runAsync = false

  // operationId is added to take an Identifier generated by client. This field
  // is only used by SQL Gateway service currently to allow the same identifier
  // to be used in both control plane and thrift without waiting for the response.
  0xD01: optional THandleIdentifier operationId

  0xD02: optional TDBSqlSessionConf sessionConf
}

struct TGetTablesResp {
  1: required TStatus status
  2: optional TOperationHandle operationHandle

  0x501: optional TSparkDirectResults directResults
}


// GetTableTypes()
//
// Returns the table types available in this database.
// The results are ordered by table type.
//
// col1
// name: TABLE_TYPE
// type: STRING
// desc: Table type name.
struct TGetTableTypesReq {
  // Session to run this request against
  1: required TSessionHandle sessionHandle

  // Directly return initial operation results, see TSparkDirectResults
  0x501: optional TSparkGetDirectResults getDirectResults

  // Execute asynchronously when runAsync is true
  0x502: optional bool runAsync = false

  // operationId is added to take an Identifier generated by client. This field
  // is only used by SQL Gateway service currently to allow the same identifier
  // to be used in both control plane and thrift without waiting for the response.
  0xD01: optional THandleIdentifier operationId

  0xD02: optional TDBSqlSessionConf sessionConf
}

struct TGetTableTypesResp {
  1: required TStatus status
  2: optional TOperationHandle operationHandle

  0x501: optional TSparkDirectResults directResults
}


// GetColumns()
//
// Returns a list of columns in the specified tables.
// The information is returned as a result set which can be fetched
// using the OperationHandle provided in the response.
// Results are ordered by TABLE_CAT, TABLE_SCHEM, TABLE_NAME,
// and ORDINAL_POSITION.
//
// Result Set Columns are the same as those for the ODBC CLIColumns
// function.
//
struct TGetColumnsReq {
  // Session to run this request against
  1: required TSessionHandle sessionHandle

  // Name of the catalog. Must not contain a search pattern.
  2: optional TIdentifier catalogName

  // Schema name or search pattern
  3: optional TPatternOrIdentifier schemaName

  // Table name or search pattern
  4: optional TPatternOrIdentifier tableName

  // Column name or search pattern
  5: optional TPatternOrIdentifier columnName

  // Directly return initial operation results, see TSparkDirectResults
  0x501: optional TSparkGetDirectResults getDirectResults

  // Execute asynchronously when runAsync is true
  0x502: optional bool runAsync = false

  // operationId is added to take an Identifier generated by client. This field
  // is only used by SQL Gateway service currently to allow the same identifier
  // to be used in both control plane and thrift without waiting for the response.
  0xD01: optional THandleIdentifier operationId

  0xD02: optional TDBSqlSessionConf sessionConf
}

struct TGetColumnsResp {
  1: required TStatus status
  2: optional TOperationHandle operationHandle

  0x501: optional TSparkDirectResults directResults
}


// GetFunctions()
//
// Returns a list of functions supported by the data source. The
// behavior of this function matches
// java.sql.DatabaseMetaData.getFunctions() both in terms of
// inputs and outputs.
//
// Result Set Columns:
//
// col1
// name: FUNCTION_CAT
// type: STRING
// desc: Function catalog (may be null)
//
// col2
// name: FUNCTION_SCHEM
// type: STRING
// desc: Function schema (may be null)
//
// col3
// name: FUNCTION_NAME
// type: STRING
// desc: Function name. This is the name used to invoke the function.
//
// col4
// name: REMARKS
// type: STRING
// desc: Explanatory comment on the function.
//
// col5
// name: FUNCTION_TYPE
// type: SMALLINT
// desc: Kind of function. One of:
//       * functionResultUnknown - Cannot determine if a return value or a table
//                                 will be returned.
//       * functionNoTable       - Does not a return a table.
//       * functionReturnsTable  - Returns a table.
//
// col6
// name: SPECIFIC_NAME
// type: STRING
// desc: The name which uniquely identifies this function within its schema.
//       In this case this is the fully qualified class name of the class
//       that implements this function.
//
struct TGetFunctionsReq {
  // Session to run this request against
  1: required TSessionHandle sessionHandle

  // A catalog name; must match the catalog name as it is stored in the
  // database; "" retrieves those without a catalog; null means
  // that the catalog name should not be used to narrow the search.
  2: optional TIdentifier catalogName

  // A schema name pattern; must match the schema name as it is stored
  // in the database; "" retrieves those without a schema; null means
  // that the schema name should not be used to narrow the search.
  3: optional TPatternOrIdentifier schemaName

  // A function name pattern; must match the function name as it is stored
  // in the database.
  4: required TPatternOrIdentifier functionName

  // Directly return initial operation results, see TSparkDirectResults
  0x501: optional TSparkGetDirectResults getDirectResults

  // Execute asynchronously when runAsync is true
  0x502: optional bool runAsync = false

  // operationId is added to take an Identifier generated by client. This field
  // is only used by SQL Gateway service currently to allow the same identifier
  // to be used in both control plane and thrift without waiting for the response.
  0xD01: optional THandleIdentifier operationId

  0xD02: optional TDBSqlSessionConf sessionConf
}

struct TGetFunctionsResp {
  1: required TStatus status
  2: optional TOperationHandle operationHandle

  0x501: optional TSparkDirectResults directResults
}

struct TGetPrimaryKeysReq {
  // Session to run this request against
  1: required TSessionHandle sessionHandle

  // Name of the catalog.
  2: optional TIdentifier catalogName

  // Name of the schema.
  3: optional TIdentifier schemaName

  // Name of the table.
  4: optional TIdentifier tableName

  // Directly return initial operation results, see TSparkDirectResults
  0x501: optional TSparkGetDirectResults getDirectResults

  // Execute asynchronously when runAsync is true
  0x502: optional bool runAsync = false

  // operationId is added to take an Identifier generated by client. This field
  // is only used by SQL Gateway service currently to allow the same identifier
  // to be used in both control plane and thrift without waiting for the response.
  0xD01: optional THandleIdentifier operationId

  0xD02: optional TDBSqlSessionConf sessionConf
}

struct TGetPrimaryKeysResp {
  1: required TStatus status
  2: optional TOperationHandle operationHandle

  0x501: optional TSparkDirectResults directResults
}

struct TGetCrossReferenceReq {
  // Session to run this request against
  1: required TSessionHandle sessionHandle

  // Name of the parent catalog.
  2: optional TIdentifier parentCatalogName

  // Name of the parent schema.
  3: optional TIdentifier parentSchemaName

  // Name of the parent table.
  4: optional TIdentifier parentTableName

  // Name of the foreign catalog.
  5: optional TIdentifier foreignCatalogName

  // Name of the foreign schema.
  6: optional TIdentifier foreignSchemaName

  // Name of the foreign table.
  7: optional TIdentifier foreignTableName

  // Directly return initial operation results, see TSparkDirectResults
  0x501: optional TSparkGetDirectResults getDirectResults

  // Execute asynchronously when runAsync is true
  0x502: optional bool runAsync = false

  // operationId is added to take an Identifier generated by client. This field
  // is only used by SQL Gateway service currently to allow the same identifier
  // to be used in both control plane and thrift without waiting for the response.
  0xD01: optional THandleIdentifier operationId

  0xD02: optional TDBSqlSessionConf sessionConf
}

struct TGetCrossReferenceResp {
  1: required TStatus status
  2: optional TOperationHandle operationHandle

  0x501: optional TSparkDirectResults directResults
}

// GetOperationStatus()
//
// Get the status of an operation running on the server.
struct TGetOperationStatusReq {
  // Session to run this request against
  1: required TOperationHandle operationHandle
  // optional arguments to get progress information
  2: optional bool getProgressUpdate

  // Opt to get the result set metadata when the operation is in FINISHED_STATE
  0xD01: optional bool getResultSetMetadataOnCompletion

  // Opt to get the retained inline result set when the operation is in FINISHED_STATE
  0xD02: optional bool getInlineResultSetOnCompletion
}

struct TGetOperationStatusResp {
  1: required TStatus status
  2: optional TOperationState operationState

  // sqlState as defined in the ISO/IEF CLI specification
  3: optional string sqlState

  // Internal error code
  4: optional i32 errorCode

  /**
   * The long-form error message. This is deprecated in DBR,
   * however servers expecting to serve to Simba drivers should be careful
   * to keep returning this as these drivers still depend on it.
   *
   * Clients should avoid using this field and prefer displayMessage and diagnosticInfo if given.
   */
  5: optional string errorMessage
  (deprecated)

  // List of statuses of sub tasks
  6: optional string taskStatus

  // When was the operation started
  7: optional i64 operationStarted

  // When was the operation completed
  8: optional i64 operationCompleted

  // If the operation has the result
  9: optional bool hasResultSet

  10: optional TProgressUpdateResp progressUpdateResponse

  11: optional i64 numModifiedRows

  // If operationState is ERROR_STATE, then the following fields may be set

  // The preferred error message for displaying in user interfaces.
  0x501: optional string displayMessage

  // Optional additional diagnostic info, e.g. stack trace. Applications should avoid displaying
  // this to the end user, but it may be used for logging and diagnostic purposes.
  0x502: optional string diagnosticInfo

  // Optional additional error details in JSON format (e.g. error class, query context).
  // Applications should avoid displaying this to the end user
  0x503: optional string errorDetailsJson

  // Binary blob representing the checksum of the main response.
  0xD01: optional binary responseValidation

  // This optional field is set if we have the information on whether the query can be executed
  // in an idempotent way.
  0xD02: optional TOperationIdempotencyType idempotencyType

  // Statement timeout value that is enforced on the operation.
  0xD03: optional i64 statementTimeout

  // The level where the statement timeout enforced on the operation is defined.
  0xD04: optional TOperationTimeoutLevel statementTimeoutLevel

  // Why the operation is closed by ThriftServer. It is only set, if operationState
  // is CLOSED_STATE.
  0xD05: optional TDBSqlCloseOperationReason closeReason

  // A snapshot of the session configuration at the time the operation was completed.
  // This is captured once to provide a consistent view of the session configuration at the
  // time the query reached a terminal state.
  // This is set if and only if the operation has succeeded and the operation is a session
  // state changing operation.
  0xD06: optional TDBSqlSessionConf sessionConfSnapshotOnComplete

  // These optional fields will be present if the query is rejected based on the cluster load.
  // They are intended only for the comminucation between clusters and SQLGateway, and should not
  // leak to the end users.
  0xD07: optional bool executionRejected

  // When a query is rejected, this field contains the query statistics from the physical plan of a query
  // to SQLGateway where this value gets persisted so that it gets submitted with subsequent to other clusters
  0xD08: optional map<string, double> queryStats

  // If the operation state is FINISHED_STATE and getResultSetMetadataOnCompletion is opted yes in
  // TGetOperationStatusReq, return the result set metadata
  0xD09: optional TGetResultSetMetadataResp resultSetMetadata

  // If the operation state is FINISHED_STATE and getInlineResultSetOnCompletion is opted yes
  // in TGetOperationStatusReq, return the retained inline result
  0xD10: optional TFetchResultsResp inlineResultSet
}


// CancelOperation()
//
// Cancels processing on the specified operation handle and
// frees any resources which were allocated.
struct TCancelOperationReq {
  // Operation to cancel
  1: required TOperationHandle operationHandle

  // the execution version of the operation to cancel
  // this is used so that only the operation with the same execution version is canceled,
  // to prevent canceling the newly scheduled query for query migration
  0xD01: optional i16 executionVersion

  // Indicates if the operation is getting canceled and replaced by a subsequent attempt. 
  // Cancellation of an execution is handled differently in such a case mainly in terms of 
  // history event publish.
  0xD02: optional bool replacedByNextAttempt
}

struct TCancelOperationResp {
  1: required TStatus status
}

enum TDBSqlCloseOperationReason {
    NONE,
    COMMAND_INACTIVITY_TIMEOUT,
    CLOSE_SESSION
}

// CloseOperation()
//
// Given an operation in the FINISHED, CANCELED,
// or ERROR states, CloseOperation() will free
// all of the resources which were allocated on
// the server to service the operation.
struct TCloseOperationReq {
  1: required TOperationHandle operationHandle
  0xD01: optional TDBSqlCloseOperationReason closeReason = TDBSqlCloseOperationReason.NONE
}

struct TCloseOperationResp {
  1: required TStatus status
}


// GetResultSetMetadata()
//
// Retrieves schema information for the specified operation
struct TGetResultSetMetadataReq {
  // Operation for which to fetch result set schema information
  1: required TOperationHandle operationHandle

  // Optional switch to include metadata of result files in case of a cloud based result
  0xD01: optional bool includeCloudResultFiles
}

struct TGetResultSetMetadataResp {
  1: required TStatus status
  2: optional TTableSchema schema

  // Set the result format used by the Thrift server.
  // If unset, then we use COLUMN_BASED_SET for protocols with
  // versions higher or equal to V6, and ROW_BASED_SET otherwise.
  0x501: optional TSparkRowSetType resultFormat;

  // The results are LZ4 compressed with ARROW_BASED_SET and
  // URL_BASED_SET row set types.
  0x502: optional bool lz4Compressed;

  // Arrow schema, if results are in Arrow format.
  0x503: optional binary arrowSchema

  // Information about whether the results came from cache.
  0x504: optional TCacheLookupResult cacheLookupResult

  // Uncompressed size in bytes of the result.
  0x505: optional i64 uncompressedBytes;

  // If the result is compressed, the compressed size.
  0x506: optional i64 compressedBytes;

  // If the result set is personal staging operation related information.
  0x507: optional bool isStagingOperation;

  // If cloud fetch was not used for this result, this fields provides the reason for this
  0xD01: optional TCloudFetchDisabledReason reasonForNoCloudFetch

  // Contains list of cloud file metadata in the result. Populated only if result is cloud-based
  // and includeResultFiles is set to true.
  0xD02: optional list<TDBSqlCloudResultFile> resultFiles

  // Location of the cloud file that contains the manifest
  0xD03: optional string manifestFile

  // The format which is used by manifestFile
  0xD04: optional TDBSqlManifestFileFormat manifestFileFormat

  // Time taken (ms) for cache lookup
  0xD05: optional i64 cacheLookupLatency

  // Only populated when remote cache is enabled
  0xD06: optional string remoteCacheMissReason

  // Caller expresses fetch disposition of the result; use by SEA to apply e.g. INLINE fetch limits
  0xD07: optional TDBSqlFetchDisposition fetchDisposition

  // Following fields are used to monitor qrc-enabled traffic in realtime
  0xD08: optional bool remoteResultCacheEnabled

  0xD09: optional bool isServerless

  // Output format of query results. This field describes the format in which results are generated
  // whereas `resultFormat` dictates how those are results are delivered to the user.
  0xD10: optional TDBSqlResultFormat resultDataFormat

  // Whether the result was truncated by the row/byte limit in TExecuteStatementReq. Won't be
  // triggered by a LIMIT clause in the SQL statement.
  0xD11: optional bool truncatedByThriftLimit

  // resultByteLimit that's passed in TExecuteStatementReq; used by SEA for byte limit validations.
  0xD12: optional i64 resultByteLimit

  // Whether the query is a query that should have inline result due to result size being small.
  // - For ARROW_BASED_SET, this is set if ReasonForNoCloudFetch is SmallResultSize.
  // - For URL_BASED_SET, this is set if original ExecuteStatement requested small result retention
  //   and the result is below the small result size threshold.
  0xD13: optional bool isInlineSmallResult
}

enum TCacheLookupResult {
    CACHE_INELIGIBLE,
    LOCAL_CACHE_HIT,
    REMOTE_CACHE_HIT,
    CACHE_MISS
}

enum TCloudFetchDisabledReason {
    ARROW_SUPPORT,
    CLOUD_FETCH_SUPPORT,
    PROTOCOL_VERSION,
    REGION_SUPPORT,
    BLOCKLISTED_OPERATION,
    SMALL_RESULT_SIZE,
    CUSTOMER_STORAGE_SUPPORT,
    UNKNOWN,
    METADATA_OPERATION
}

enum TDBSqlManifestFileFormat {
    // Binary Thrift serialisation of the TGetResultSetMetadataResp
    THRIFT_GET_RESULT_SET_METADATA_RESP
}

enum TFetchOrientation {
  // Get the next rowset. The fetch offset is ignored.
  FETCH_NEXT,

  // Get the previous rowset. The fetch offset is ignored.
  FETCH_PRIOR,

  // Return the rowset at the given fetch offset relative
  // to the curren rowset.
  // NOT SUPPORTED
  FETCH_RELATIVE,

  // Return the rowset at the specified fetch offset.
  // NOT SUPPORTED
  FETCH_ABSOLUTE,

  // Get the first rowset in the result set.
  FETCH_FIRST,

  // Get the last rowset in the result set.
  // NOT SUPPORTED
  FETCH_LAST
}

enum TDBSqlFetchDisposition {
  // Default unknown disposition for non-SEA calls
  DISPOSITION_UNSPECIFIED,

  // INLINE disposition for inlining results within transport structure (incl
  // JSON, gRPC, etc.)
  DISPOSITION_INLINE,

  // EXTERNAL_LINKS disposition for fetches to resolve into URLs, presumeably
  // Cloud Fetch presigned URLs
  DISPOSITION_EXTERNAL_LINKS,

  // INTERNAL_DBFS disposition for returning DBFS file paths for internal clients
  DISPOSITION_INTERNAL_DBFS,

  // INLINE_OR_EXTERNAL_LINKS disposition that will return results inline for small
  // results and return external links for large results.
  DISPOSITION_INLINE_OR_EXTERNAL_LINKS
}

// FetchResults()
//
// Fetch rows from the server corresponding to
// a particular OperationHandle.
struct TFetchResultsReq {
  // Operation from which to fetch results.
  1: required TOperationHandle operationHandle

  // The fetch orientation. This must be either
  // FETCH_NEXT, FETCH_PRIOR or FETCH_FIRST. Defaults to FETCH_NEXT.
  2: required TFetchOrientation orientation = TFetchOrientation.FETCH_NEXT

  // Max number of rows that should be returned in
  // the rowset.
  3: required i64 maxRows

  // The type of a fetch results request. 0 represents Query output. 1 represents Log
  4: optional i16 fetchType = 0

  // The maximum number of bytes that should be returned in the row set
  0x501: optional i64 maxBytes
  // starting offset from which to regenerate link
  // this may also be used in the future in other types of fetch for FETCH_ABSOLUTE
  0x502: optional i64 startRowOffset

  // If set to true, call GetResultSetMetadata and include its respone from within FetchResults
  0x503: optional bool includeResultSetMetadata

  // Set by SQL Gateway to perform an idempotent retry.
  0xD01: optional string internalIdempotencyToken
}

struct TFetchResultsResp {
  1: required TStatus status

  // TRUE if there are more rows left to fetch from the server.
  2: optional bool hasMoreRows

  // The rowset. This is optional so that we have the
  // option in the future of adding alternate formats for
  // representing result set data, e.g. delimited strings,
  // binary encoded, etc.
  3: optional TRowSet results

  0x501: optional TGetResultSetMetadataResp resultSetMetadata

  // Binary blob representing the checksum of the main response.
  0xD01: optional binary responseValidation
}

// GetDelegationToken()
// Retrieve delegation token for the current user
struct  TGetDelegationTokenReq {
  // session handle
  1: required TSessionHandle sessionHandle

  // userid for the proxy user
  2: required string owner

  // designated renewer userid
  3: required string renewer

  0xD01: optional TDBSqlSessionConf sessionConf
}

struct TGetDelegationTokenResp {
  // status of the request
  1: required TStatus status

  // delegation token string
  2: optional string delegationToken
}

// CancelDelegationToken()
// Cancel the given delegation token
struct TCancelDelegationTokenReq {
  // session handle
  1: required TSessionHandle sessionHandle

  // delegation token to cancel
  2: required string delegationToken

  0xD01: optional TDBSqlSessionConf sessionConf
}

struct TCancelDelegationTokenResp {
  // status of the request
  1: required TStatus status
}

// RenewDelegationToken()
// Renew the given delegation token
struct TRenewDelegationTokenReq {
  // session handle
  1: required TSessionHandle sessionHandle

  // delegation token to renew
  2: required string delegationToken

  0xD01: optional TDBSqlSessionConf sessionConf
}

struct TRenewDelegationTokenResp {
  // status of the request
  1: required TStatus status
}

enum TJobExecutionStatus {
    IN_PROGRESS,
    COMPLETE,
    NOT_AVAILABLE
}

struct TProgressUpdateResp {
  1: required list<string> headerNames
  2: required list<list<string>> rows
  3: required double progressedPercentage
  4: required TJobExecutionStatus status
  5: required string footerSummary
  6: required i64 startTime
}

// Request types where SQL Gateway can set an internal idempotency tokens
// to perform retries and clean them after the request is completed.
enum TDBSqlRequestType {
  EXECUTE_STATEMENT,
  FETCH_RESULTS
}

struct TDBSqlIdempotencyTokenReleaseInfo {
  1: required string idempotencyToken
  // The type of the request where the token was used
  2: required TDBSqlRequestType requestType
  // When set to true, ThriftServer removes the response from response
  // cache, but leaves the token in seen cache.
  3: required bool leaveTombstone
}

// Releases the internal idempotency tokens sent by SQL Gateway in ThriftServer.
struct TDBSqlReleaseIdempotencyTokenReq {
  1: required list<TDBSqlIdempotencyTokenReleaseInfo> idempotencyToken
}

struct TDBSqlReleaseIdempotencyTokenResp {
  1: required TStatus status
}

service TCLIService {

  TOpenSessionResp OpenSession(1:TOpenSessionReq req);

  TCloseSessionResp CloseSession(1:TCloseSessionReq req);

  TGetInfoResp GetInfo(1:TGetInfoReq req);

  TExecuteStatementResp ExecuteStatement(1:TExecuteStatementReq req);

  TGetTypeInfoResp GetTypeInfo(1:TGetTypeInfoReq req);

  TGetCatalogsResp GetCatalogs(1:TGetCatalogsReq req);

  TGetSchemasResp GetSchemas(1:TGetSchemasReq req);

  TGetTablesResp GetTables(1:TGetTablesReq req);

  TGetTableTypesResp GetTableTypes(1:TGetTableTypesReq req);

  TGetColumnsResp GetColumns(1:TGetColumnsReq req);

  TGetFunctionsResp GetFunctions(1:TGetFunctionsReq req);

  TGetPrimaryKeysResp GetPrimaryKeys(1:TGetPrimaryKeysReq req);

  TGetCrossReferenceResp GetCrossReference(1:TGetCrossReferenceReq req);

  TGetOperationStatusResp GetOperationStatus(1:TGetOperationStatusReq req);

  TCancelOperationResp CancelOperation(1:TCancelOperationReq req);

  TCloseOperationResp CloseOperation(1:TCloseOperationReq req);

  TGetResultSetMetadataResp GetResultSetMetadata(1:TGetResultSetMetadataReq req);

  TFetchResultsResp FetchResults(1:TFetchResultsReq req);

  TGetDelegationTokenResp GetDelegationToken(1:TGetDelegationTokenReq req);

  TCancelDelegationTokenResp CancelDelegationToken(1:TCancelDelegationTokenReq req);

  TRenewDelegationTokenResp RenewDelegationToken(1:TRenewDelegationTokenReq req);

  TDBSqlReleaseIdempotencyTokenResp ReleaseIdempotencyToken(1:TDBSqlReleaseIdempotencyTokenReq req);
}
