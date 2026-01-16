#!/usr/bin/env python3
"""
Test script to verify field name resolution for both request and response messages.

This demonstrates that the enhanced decoder can resolve semantic field names
for both incoming requests (CALL) and outgoing responses (REPLY).
"""

import sys
from thrift_decoder import decode_thrift_message, format_thrift_message, THRIFT_TYPES_AVAILABLE

# Add databricks-sql-python to path
sys.path.insert(0, '/Users/e.wang/Documents/dev/databricks-sql-python/src')

# Import Thrift types to create test messages
try:
    from databricks.sql.thrift_api.TCLIService import ttypes
    from thrift.protocol import TBinaryProtocol
    from thrift.transport import TTransport
    TEST_AVAILABLE = True
except ImportError:
    TEST_AVAILABLE = False
    print("Warning: Could not import Thrift types for test generation")


def create_test_request():
    """Create a sample ExecuteStatement REQUEST message."""
    if not TEST_AVAILABLE:
        return None

    # Create request
    session_handle = ttypes.TSessionHandle(
        sessionId=ttypes.THandleIdentifier(
            guid=b'test_session_guid_16',  # Must be 16 bytes
            secret=b'test_secret_byte_16'   # Must be 16 bytes
        )
    )

    req = ttypes.TExecuteStatementReq(
        sessionHandle=session_handle,
        statement="SELECT id, name, price FROM products WHERE price > 100",
        confOverlay={"spark.sql.adaptive.enabled": "true", "spark.sql.shuffle.partitions": "200"},
        runAsync=True,
        queryTimeout=60,
    )

    # Serialize to binary format
    transport = TTransport.TMemoryBuffer()
    protocol = TBinaryProtocol.TBinaryProtocol(transport)

    # Write message header (method, type=CALL, seqid)
    protocol.writeMessageBegin("ExecuteStatement", 1, 12345)
    req.write(protocol)

    return transport.getvalue()


def create_test_response():
    """Create a sample ExecuteStatement RESPONSE message."""
    if not TEST_AVAILABLE:
        return None

    # Create response with status and operation handle
    status = ttypes.TStatus(
        statusCode=ttypes.TStatusCode.SUCCESS_STATUS,
        infoMessages=["Query executed successfully"],
    )

    operation_handle = ttypes.TOperationHandle(
        operationId=ttypes.THandleIdentifier(
            guid=b'operation_guid_16',  # Must be 16 bytes
            secret=b'operation_secret16'  # Must be 16 bytes
        ),
        operationType=ttypes.TOperationType.EXECUTE_STATEMENT,
        hasResultSet=True,
    )

    resp = ttypes.TExecuteStatementResp(
        status=status,
        operationHandle=operation_handle,
    )

    # Serialize to binary format
    transport = TTransport.TMemoryBuffer()
    protocol = TBinaryProtocol.TBinaryProtocol(transport)

    # Write message header (method, type=REPLY, seqid)
    protocol.writeMessageBegin("ExecuteStatement", 2, 12345)
    resp.write(protocol)

    return transport.getvalue()


def create_test_fetchresults_response():
    """Create a sample FetchResults RESPONSE message with actual result data."""
    if not TEST_AVAILABLE:
        return None

    # Create status
    status = ttypes.TStatus(
        statusCode=ttypes.TStatusCode.SUCCESS_STATUS,
    )

    # Create a simple result set with one row
    col_values = ttypes.TColumn(
        stringVal=ttypes.TStringColumn(
            values=["Alice", "Bob", "Charlie"],
            nulls=b'\x00'  # No nulls
        )
    )

    row_set = ttypes.TRowSet(
        startRowOffset=0,
        rows=[],  # Empty for columnar format
        columns=[col_values],
    )

    resp = ttypes.TFetchResultsResp(
        status=status,
        hasMoreRows=False,
        results=row_set,
    )

    # Serialize
    transport = TTransport.TMemoryBuffer()
    protocol = TBinaryProtocol.TBinaryProtocol(transport)
    protocol.writeMessageBegin("FetchResults", 2, 12346)
    resp.write(protocol)

    return transport.getvalue()


def test_decoder():
    """Test the enhanced decoder with both request and response messages."""
    print("=" * 80)
    print("Testing Request/Response Field Name Resolution")
    print("=" * 80)
    print()

    print(f"Thrift types available: {THRIFT_TYPES_AVAILABLE}")
    print()

    if not TEST_AVAILABLE:
        print("Cannot run test without Thrift types.")
        print("Please ensure databricks-sql-python is available.")
        return

    # Test 1: REQUEST message
    print("=" * 80)
    print("TEST 1: ExecuteStatement REQUEST")
    print("=" * 80)
    print()

    request_bytes = create_test_request()
    if not request_bytes:
        print("Failed to create test request")
        return

    print(f"Message size: {len(request_bytes)} bytes")
    print()

    decoded_req = decode_thrift_message(request_bytes)
    if not decoded_req:
        print("Failed to decode request")
        return

    print(format_thrift_message(decoded_req))
    print()

    if decoded_req.get("field_names_resolved"):
        print("✅ SUCCESS: Request field names resolved!")
        fields = decoded_req.get("fields", {})
        print(f"   Resolved {len(fields)} fields:")
        for fname in list(fields.keys())[:5]:
            print(f"     - {fname}")
    else:
        print("❌ FAILURE: Request field names NOT resolved")

    print()
    print()

    # Test 2: RESPONSE message
    print("=" * 80)
    print("TEST 2: ExecuteStatement RESPONSE")
    print("=" * 80)
    print()

    response_bytes = create_test_response()
    if not response_bytes:
        print("Failed to create test response")
        return

    print(f"Message size: {len(response_bytes)} bytes")
    print()

    decoded_resp = decode_thrift_message(response_bytes)
    if not decoded_resp:
        print("Failed to decode response")
        return

    print(format_thrift_message(decoded_resp))
    print()

    if decoded_resp.get("field_names_resolved"):
        print("✅ SUCCESS: Response field names resolved!")
        fields = decoded_resp.get("fields", {})
        print(f"   Resolved {len(fields)} fields:")
        for fname in fields.keys():
            print(f"     - {fname}")
    else:
        print("❌ FAILURE: Response field names NOT resolved")

    print()
    print()

    # Test 3: FetchResults RESPONSE with data
    print("=" * 80)
    print("TEST 3: FetchResults RESPONSE (with result data)")
    print("=" * 80)
    print()

    fetch_bytes = create_test_fetchresults_response()
    if not fetch_bytes:
        print("Failed to create FetchResults response")
        return

    print(f"Message size: {len(fetch_bytes)} bytes")
    print()

    decoded_fetch = decode_thrift_message(fetch_bytes)
    if not decoded_fetch:
        print("Failed to decode FetchResults response")
        return

    print(format_thrift_message(decoded_fetch))
    print()

    if decoded_fetch.get("field_names_resolved"):
        print("✅ SUCCESS: FetchResults response field names resolved!")
        fields = decoded_fetch.get("fields", {})
        print(f"   Resolved {len(fields)} fields:")
        for fname in fields.keys():
            print(f"     - {fname}")
    else:
        print("❌ FAILURE: FetchResults response field names NOT resolved")

    print()
    print()

    # Summary
    print("=" * 80)
    print("SUMMARY")
    print("=" * 80)
    print()
    req_ok = decoded_req.get("field_names_resolved", False)
    resp_ok = decoded_resp.get("field_names_resolved", False)
    fetch_ok = decoded_fetch.get("field_names_resolved", False)

    if req_ok and resp_ok and fetch_ok:
        print("✅ ALL TESTS PASSED")
        print()
        print("Your decoder can now resolve field names for:")
        print("  • Request messages (CALL) - shows semantic field names")
        print("  • Response messages (REPLY) - shows semantic field names")
        print("  • Complex nested structures - handles TRowSet, TColumn, etc.")
        print()
        print("This means debugging Thrift traffic is now much easier!")
    else:
        print("❌ SOME TESTS FAILED")
        print(f"  Request:  {'✅' if req_ok else '❌'}")
        print(f"  Response: {'✅' if resp_ok else '❌'}")
        print(f"  FetchResults: {'✅' if fetch_ok else '❌'}")


if __name__ == "__main__":
    test_decoder()
