#!/usr/bin/env python3
"""
Test to verify the actual decoded structure of FetchResults requests.
This helps us understand how to extract the operation handle correctly.
"""

import sys
import json
from thrift_decoder import decode_thrift_message, THRIFT_TYPES_AVAILABLE

sys.path.insert(0, '/Users/e.wang/Documents/dev/databricks-sql-python/src')

try:
    from databricks.sql.thrift_api.TCLIService import ttypes
    from thrift.protocol import TBinaryProtocol
    from thrift.transport import TTransport
    TEST_AVAILABLE = True
except ImportError:
    TEST_AVAILABLE = False
    print("Warning: Could not import Thrift types")


def create_fetchresults_request(operation_guid_str="test-operation-guid"):
    """Create a FetchResults request with a specific operation GUID."""
    if not TEST_AVAILABLE:
        return None

    # Create operation handle with a known GUID
    operation_guid = operation_guid_str.encode('utf-8').ljust(16, b'\x00')[:16]
    operation_secret = b'test_secret_data'[:16].ljust(16, b'\x00')

    operation_handle = ttypes.TOperationHandle(
        operationId=ttypes.THandleIdentifier(
            guid=operation_guid,
            secret=operation_secret
        ),
        operationType=ttypes.TOperationType.EXECUTE_STATEMENT,
        hasResultSet=True,
    )

    req = ttypes.TFetchResultsReq(
        operationHandle=operation_handle,
        orientation=ttypes.TFetchOrientation.FETCH_NEXT,
        maxRows=10000,
    )

    # Serialize
    transport = TTransport.TMemoryBuffer()
    protocol = TBinaryProtocol.TBinaryProtocol(transport)
    protocol.writeMessageBegin("FetchResults", 1, 12345)  # CALL
    req.write(protocol)

    return transport.getvalue()


def print_structure(obj, indent=0, max_depth=10):
    """Recursively print the structure of a decoded object."""
    if indent > max_depth:
        print("  " * indent + "... (max depth reached)")
        return

    prefix = "  " * indent

    if isinstance(obj, dict):
        for key, value in obj.items():
            if isinstance(value, dict):
                # Check if this is a Thrift field structure with type/value/field_id
                if "type" in value and "value" in value:
                    field_type = value.get("type", "UNKNOWN")
                    field_id = value.get("field_id", "?")
                    print(f"{prefix}{key} [id={field_id}] ({field_type}):")

                    # Recursively print the value
                    if isinstance(value["value"], (dict, list)):
                        print_structure(value["value"], indent + 1, max_depth)
                    else:
                        print(f"{prefix}  → {repr(value['value'])[:100]}")
                else:
                    print(f"{prefix}{key}:")
                    print_structure(value, indent + 1, max_depth)
            elif isinstance(value, list):
                print(f"{prefix}{key}: (list with {len(value)} items)")
                if value and indent < 3:
                    print(f"{prefix}  [0]:")
                    print_structure(value[0], indent + 2, max_depth)
            else:
                print(f"{prefix}{key}: {repr(value)[:100]}")
    elif isinstance(obj, list):
        for i, item in enumerate(obj[:3]):  # Print first 3 items
            print(f"{prefix}[{i}]:")
            print_structure(item, indent + 1, max_depth)
    else:
        print(f"{prefix}{repr(obj)[:100]}")


def test_fetchresults_structure():
    """Test to understand the actual decoded structure."""
    print("=" * 80)
    print("FetchResults Request Structure Analysis")
    print("=" * 80)
    print()

    if not TEST_AVAILABLE:
        print("Cannot run test without Thrift types")
        return

    print("Creating FetchResults request with operation GUID: 'test-operation-guid'")
    print()

    request_bytes = create_fetchresults_request("test-operation-guid")
    if not request_bytes:
        print("Failed to create request")
        return

    print(f"Message size: {len(request_bytes)} bytes")
    print()

    # Decode
    decoded = decode_thrift_message(request_bytes)
    if not decoded:
        print("Failed to decode message")
        return

    print("=" * 80)
    print("DECODED STRUCTURE:")
    print("=" * 80)
    print()
    print_structure(decoded, indent=0, max_depth=8)
    print()

    # Now try to extract the operation handle
    print("=" * 80)
    print("OPERATION HANDLE EXTRACTION ATTEMPT:")
    print("=" * 80)
    print()

    fields = decoded.get("fields", {})

    # Try to navigate to the GUID
    print("Step 1: Get 'operationHandle' field")
    if "operationHandle" in fields:
        op_handle_field = fields["operationHandle"]
        print(f"  ✅ Found operationHandle: type={op_handle_field.get('type')}, field_id={op_handle_field.get('field_id')}")

        print("\nStep 2: Get 'operationHandle.value' (the nested struct)")
        op_handle_value = op_handle_field.get("value", {})
        print(f"  ✅ operationHandle.value has {len(op_handle_value)} fields: {list(op_handle_value.keys())}")

        # The operationId might be under a field name or field_1
        print("\nStep 3: Look for operationId or field_1 in nested struct")
        for key in ["operationId", "field_1"]:
            if key in op_handle_value:
                op_id_field = op_handle_value[key]
                print(f"  ✅ Found {key}: type={op_id_field.get('type')}, field_id={op_id_field.get('field_id')}")

                print(f"\nStep 4: Get '{key}.value' (the THandleIdentifier)")
                op_id_value = op_id_field.get("value", {})
                print(f"  ✅ {key}.value has {len(op_id_value)} fields: {list(op_id_value.keys())}")

                print("\nStep 5: Look for 'guid' or nested 'operationHandle' (field_1) in THandleIdentifier")
                for guid_key in ["guid", "operationHandle", "field_1"]:
                    if guid_key in op_id_value:
                        guid_field = op_id_value[guid_key]
                        print(f"  ✅ Found {guid_key}: type={guid_field.get('type')}, field_id={guid_field.get('field_id')}")

                        guid_value = guid_field.get("value", "")
                        print(f"\nStep 6: Extract GUID value")
                        print(f"  ✅ GUID: {repr(guid_value)}")
                        print(f"  ✅ GUID length: {len(guid_value)} bytes")
                        if isinstance(guid_value, bytes):
                            print(f"  ✅ GUID (decoded): {guid_value.decode('utf-8', errors='ignore').strip(chr(0))}")
                        else:
                            print(f"  ✅ GUID (string): {guid_value.strip(chr(0))}")

                        print("\n" + "=" * 80)
                        print("SUCCESS: Operation handle extraction path:")
                        print(f"  fields['operationHandle'].value['{key}'].value['{guid_key}'].value")
                        print("=" * 80)
                        return

    print("❌ Could not extract operation handle - check the decoded structure above")


def test_different_operations_have_different_guids():
    """Test that different operations have different GUIDs."""
    print("\n\n")
    print("=" * 80)
    print("Test: Different Operations Have Different GUIDs")
    print("=" * 80)
    print()

    if not TEST_AVAILABLE:
        print("Cannot run test without Thrift types")
        return

    # Create two different requests with different GUIDs
    # Note: GUIDs are truncated to 16 bytes, so use short strings that differ within 16 chars
    request1 = create_fetchresults_request("operation-aaa")
    request2 = create_fetchresults_request("operation-bbb")

    decoded1 = decode_thrift_message(request1)
    decoded2 = decode_thrift_message(request2)

    # Extract GUIDs (using the discovered path)
    def extract_guid(decoded):
        fields = decoded.get("fields", {})
        if "operationHandle" in fields:
            # Path: operationHandle.value.operationHandle.value.operationHandle.value
            # This navigates nested structs that reuse parent field names
            op_handle_field = fields["operationHandle"]
            if not isinstance(op_handle_field, dict) or "value" not in op_handle_field:
                return None

            op_handle_struct = op_handle_field["value"]
            if "operationHandle" not in op_handle_struct:
                return None

            op_id_field = op_handle_struct["operationHandle"]
            if not isinstance(op_id_field, dict) or "value" not in op_id_field:
                return None

            op_id_struct = op_id_field["value"]
            if "operationHandle" not in op_id_struct:
                return None

            guid_field = op_id_struct["operationHandle"]
            if not isinstance(guid_field, dict) or "value" not in guid_field:
                return None

            guid_value = guid_field["value"]
            if isinstance(guid_value, bytes):
                return guid_value.decode('utf-8', errors='ignore').strip('\x00')
            elif isinstance(guid_value, str):
                return guid_value.strip('\x00')

        return None

    guid1 = extract_guid(decoded1)
    guid2 = extract_guid(decoded2)

    print(f"Operation 1 GUID: {repr(guid1)}")
    print(f"Operation 2 GUID: {repr(guid2)}")
    print()

    if guid1 and guid2:
        if guid1 != guid2:
            print("✅ SUCCESS: Different operations have different GUIDs")
            print(f"  GUID 1: {guid1}")
            print(f"  GUID 2: {guid2}")
        else:
            print("❌ FAILURE: Different operations have the SAME GUID (unexpected!)")
    else:
        print("❌ FAILURE: Could not extract GUIDs from both operations")
    print()


if __name__ == "__main__":
    test_fetchresults_structure()
    test_different_operations_have_different_guids()
