#!/usr/bin/env python3
"""
Test script for enhanced Thrift decoder with field name resolution.

This script demonstrates the improvement: instead of generic field_1, field_2,
the decoder now shows semantic field names like sessionHandle, statement, etc.
"""

import sys
from thrift_decoder import decode_thrift_message, format_thrift_message, THRIFT_TYPES_AVAILABLE

# Add databricks-sql-python to path
sys.path.insert(0, '/Users/e.wang/Documents/dev/databricks-sql-python/src')

# Import Thrift types to create a test message
try:
    from databricks.sql.thrift_api.TCLIService import ttypes
    from thrift.protocol import TBinaryProtocol
    from thrift.transport import TTransport
    TEST_AVAILABLE = True
except ImportError:
    TEST_AVAILABLE = False
    print("Warning: Could not import Thrift types for test generation")

def create_test_execute_statement_request():
    """Create a sample TExecuteStatementReq message for testing."""
    if not TEST_AVAILABLE:
        return None

    # Create a sample ExecuteStatement request
    session_handle = ttypes.TSessionHandle(
        sessionId=ttypes.THandleIdentifier(guid=b'test_session_guid', secret=b'test_secret')
    )

    req = ttypes.TExecuteStatementReq(
        sessionHandle=session_handle,
        statement="SELECT * FROM test_table WHERE id = 123",
        confOverlay={"spark.sql.adaptive.enabled": "true"},
        runAsync=True,
        queryTimeout=30,
    )

    # Serialize to binary format
    transport = TTransport.TMemoryBuffer()
    protocol = TBinaryProtocol.TBinaryProtocol(transport)

    # Write message header
    protocol.writeMessageBegin("ExecuteStatement", 1, 0)  # method, type=CALL, seqid

    # Write the struct
    req.write(protocol)

    return transport.getvalue()

def test_decoder():
    """Test the enhanced decoder."""
    print("=" * 80)
    print("Testing Enhanced Thrift Decoder with Field Name Resolution")
    print("=" * 80)
    print()

    print(f"Thrift types available: {THRIFT_TYPES_AVAILABLE}")
    print()

    if not TEST_AVAILABLE:
        print("Cannot run test without Thrift types. Please ensure databricks-sql-python is available.")
        return

    # Create a test message
    print("Creating test ExecuteStatement request...")
    message_bytes = create_test_execute_statement_request()

    if not message_bytes:
        print("Failed to create test message")
        return

    print(f"Message size: {len(message_bytes)} bytes")
    print()

    # Decode the message
    print("Decoding message...")
    decoded = decode_thrift_message(message_bytes)

    if not decoded:
        print("Failed to decode message")
        return

    # Format and print
    print()
    print("=" * 80)
    print("DECODED MESSAGE:")
    print("=" * 80)
    formatted = format_thrift_message(decoded)
    print(formatted)
    print()

    # Show the improvement
    if decoded.get("field_names_resolved"):
        print("✅ SUCCESS: Field names were resolved using thrift_spec!")
        print()
        print("Before enhancement, you would see:")
        print("  field_1 (STRUCT): ...")
        print("  field_2 (STRING): SELECT * FROM test_table WHERE id = 123")
        print("  field_3 (MAP): {'spark.sql.adaptive.enabled': 'true'}")
        print()
        print("Now you see:")
        fields = decoded.get("fields", {})
        for fname, fdata in list(fields.items())[:3]:
            if isinstance(fdata, dict) and "value" in fdata:
                print(f"  {fname} ({fdata['type']}): {str(fdata['value'])[:60]}...")
    else:
        print("⚠️  Field names not resolved. Check that databricks-sql-python is in sys.path")

if __name__ == "__main__":
    test_decoder()
