#!/usr/bin/env python3
# Copyright (c) 2025 ADBC Drivers Contributors
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Generic Thrift Binary Protocol Decoder with Field Name Resolution.

This module provides utilities to decode Thrift Binary Protocol messages
and resolve field IDs to semantic field names using generated Thrift code.

Features:
- Generic binary protocol decoding (works without IDL files)
- Field name resolution using thrift_spec from generated code
- Support for HiveServer2, Databricks extensions, and custom protocols
- Protocol-agnostic logging and inspection
"""

import struct
import sys
from io import BytesIO
from typing import Any, Dict, List, Optional, Tuple

# Import generated Thrift types to get field name mappings from thrift_spec
# This uses the databricks-sql-python generated code
try:
    # Add databricks-sql-python to path if available locally
    sys.path.insert(0, '/Users/e.wang/Documents/dev/databricks-sql-python/src')
    from databricks.sql.thrift_api.TCLIService import ttypes as thrift_types
    THRIFT_TYPES_AVAILABLE = True
except ImportError:
    THRIFT_TYPES_AVAILABLE = False
    thrift_types = None


class ThriftDecoder:
    """
    Generic decoder for Thrift Binary Protocol messages.

    This decoder parses the wire format directly without needing IDL definitions.
    It's forward-compatible with protocol extensions and custom fields.
    """

    # Thrift type constants (from Thrift specification)
    T_STOP = 0
    T_VOID = 1
    T_BOOL = 2
    T_BYTE = 3
    T_I08 = 3
    T_DOUBLE = 4
    T_I16 = 6
    T_I32 = 8
    T_I64 = 10
    T_STRING = 11
    T_UTF7 = 11
    T_STRUCT = 12
    T_MAP = 13
    T_SET = 14
    T_LIST = 15
    T_UTF8 = 16
    T_UTF16 = 17

    TYPE_NAMES = {
        0: "STOP",
        1: "VOID",
        2: "BOOL",
        3: "BYTE",
        4: "DOUBLE",
        6: "I16",
        8: "I32",
        10: "I64",
        11: "STRING",
        12: "STRUCT",
        13: "MAP",
        14: "SET",
        15: "LIST",
        16: "UTF8",
        17: "UTF16",
    }

    # Message types
    MESSAGE_TYPE_CALL = 1
    MESSAGE_TYPE_REPLY = 2
    MESSAGE_TYPE_EXCEPTION = 3
    MESSAGE_TYPE_ONEWAY = 4

    MESSAGE_TYPE_NAMES = {
        1: "CALL",
        2: "REPLY",
        3: "EXCEPTION",
        4: "ONEWAY",
    }

    # Common HiveServer2/Databricks method names (for better logging)
    KNOWN_METHODS = {
        "OpenSession",
        "CloseSession",
        "ExecuteStatement",
        "GetOperationStatus",
        "FetchResults",
        "CloseOperation",
        "CancelOperation",
        "GetResultSetMetadata",
        "GetSchemas",
        "GetTables",
        "GetColumns",
        "GetCatalogs",
        "GetTableTypes",
        "GetTypeInfo",
    }

    # Map method names to their request struct types for field name resolution
    METHOD_TO_REQUEST_TYPE = {
        "OpenSession": "TOpenSessionReq",
        "CloseSession": "TCloseSessionReq",
        "ExecuteStatement": "TExecuteStatementReq",
        "GetOperationStatus": "TGetOperationStatusReq",
        "FetchResults": "TFetchResultsReq",
        "CloseOperation": "TCloseOperationReq",
        "CancelOperation": "TCancelOperationReq",
        "GetResultSetMetadata": "TGetResultSetMetadataReq",
        "GetSchemas": "TGetSchemasReq",
        "GetTables": "TGetTablesReq",
        "GetColumns": "TGetColumnsReq",
        "GetCatalogs": "TGetCatalogsReq",
        "GetTableTypes": "TGetTableTypesReq",
        "GetTypeInfo": "TGetTypeInfoReq",
    }

    # Map method names to their response struct types for field name resolution
    METHOD_TO_RESPONSE_TYPE = {
        "OpenSession": "TOpenSessionResp",
        "CloseSession": "TCloseSessionResp",
        "ExecuteStatement": "TExecuteStatementResp",
        "GetOperationStatus": "TGetOperationStatusResp",
        "FetchResults": "TFetchResultsResp",
        "CloseOperation": "TCloseOperationResp",
        "CancelOperation": "TCancelOperationResp",
        "GetResultSetMetadata": "TGetResultSetMetadataResp",
        "GetSchemas": "TGetSchemasResp",
        "GetTables": "TGetTablesResp",
        "GetColumns": "TGetColumnsResp",
        "GetCatalogs": "TGetCatalogsResp",
        "GetTableTypes": "TGetTableTypesResp",
        "GetTypeInfo": "TGetTypeInfoResp",
    }

    def __init__(self, data: bytes, method_name: Optional[str] = None):
        """
        Initialize decoder with Thrift message bytes.

        Args:
            data: Raw Thrift message bytes
            method_name: Optional method name for field name resolution
        """
        self.stream = BytesIO(data)
        self.pos = 0
        self.data_len = len(data)
        self.method_name = method_name
        self.message_type = None
        # Field name map will be built after we know the message type
        self.field_name_map = {}

    def _build_field_name_map(
        self, method_name: Optional[str], message_type: Optional[int]
    ) -> Dict[int, str]:
        """
        Build field ID to field name mapping from thrift_spec.

        Args:
            method_name: Thrift method name (e.g., "ExecuteStatement")
            message_type: Message type (1=CALL/request, 2=REPLY/response)

        Returns:
            Dictionary mapping field_id to field_name
        """
        if not THRIFT_TYPES_AVAILABLE or not method_name or message_type is None:
            return {}

        # Choose the appropriate type mapping based on message type
        if message_type == self.MESSAGE_TYPE_CALL:
            # This is a request (CALL)
            struct_type_name = self.METHOD_TO_REQUEST_TYPE.get(method_name)
        elif message_type == self.MESSAGE_TYPE_REPLY:
            # This is a response (REPLY)
            struct_type_name = self.METHOD_TO_RESPONSE_TYPE.get(method_name)
        else:
            # EXCEPTION or ONEWAY - no field mapping needed
            return {}

        if not struct_type_name:
            return {}

        # Get the struct class from thrift_types module
        try:
            struct_class = getattr(thrift_types, struct_type_name, None)
            if not struct_class:
                return {}

            # Extract field names from thrift_spec
            # thrift_spec format: (field_id, TType, 'field_name', ...)
            thrift_spec = getattr(struct_class, 'thrift_spec', None)
            if not thrift_spec:
                return {}

            field_map = {}
            for field_id, field_spec in enumerate(thrift_spec):
                if field_spec is not None:
                    # field_spec is a tuple: (field_id, type, name, ...)
                    if len(field_spec) >= 3:
                        actual_field_id = field_spec[0]
                        field_name = field_spec[2]
                        field_map[actual_field_id] = field_name

            return field_map
        except Exception:
            return {}

    def read_byte(self) -> int:
        """Read a single byte."""
        b = self.stream.read(1)
        if len(b) == 0:
            raise EOFError(f"Unexpected end of stream at position {self.pos}")
        self.pos += 1
        return struct.unpack("!b", b)[0]

    def read_i16(self) -> int:
        """Read a 16-bit signed integer."""
        data = self.stream.read(2)
        if len(data) < 2:
            raise EOFError(f"Unexpected end of stream at position {self.pos}")
        self.pos += 2
        return struct.unpack("!h", data)[0]

    def read_i32(self) -> int:
        """Read a 32-bit signed integer."""
        data = self.stream.read(4)
        if len(data) < 4:
            raise EOFError(f"Unexpected end of stream at position {self.pos}")
        self.pos += 4
        return struct.unpack("!i", data)[0]

    def read_i64(self) -> int:
        """Read a 64-bit signed integer."""
        data = self.stream.read(8)
        if len(data) < 8:
            raise EOFError(f"Unexpected end of stream at position {self.pos}")
        self.pos += 8
        return struct.unpack("!q", data)[0]

    def read_double(self) -> float:
        """Read a double-precision float."""
        data = self.stream.read(8)
        if len(data) < 8:
            raise EOFError(f"Unexpected end of stream at position {self.pos}")
        self.pos += 8
        return struct.unpack("!d", data)[0]

    def read_string(self) -> str:
        """Read a length-prefixed string."""
        length = self.read_i32()
        if length < 0:
            raise ValueError(f"Invalid string length: {length}")
        if length > 10 * 1024 * 1024:  # 10MB sanity check
            raise ValueError(f"String length too large: {length}")

        data = self.stream.read(length)
        if len(data) < length:
            raise EOFError(
                f"Unexpected end of stream while reading string at position {self.pos}"
            )
        self.pos += length

        try:
            return data.decode("utf-8")
        except UnicodeDecodeError:
            # Return hex representation if not valid UTF-8
            preview = data[:50].hex()
            if len(data) > 50:
                preview += "..."
            return f"<binary:{preview}>"

    def read_message_begin(self) -> Tuple[str, int, int]:
        """
        Read Thrift message header.

        Returns:
            Tuple of (method_name, message_type, sequence_id)
        """
        size = self.read_i32()

        if size < 0:
            # Strict mode (version prefix)
            version = size & 0xFFFF0000
            if version != 0x80010000:  # VERSION_1
                raise ValueError(f"Unsupported Thrift version: {hex(version)}")
            message_type = size & 0x000000FF
            method_name = self.read_string()
        else:
            # Non-strict mode (old style)
            method_name_bytes = self.stream.read(size)
            if len(method_name_bytes) < size:
                raise EOFError("Unexpected end of stream while reading method name")
            self.pos += size
            method_name = method_name_bytes.decode("utf-8")
            message_type = self.read_byte()

        sequence_id = self.read_i32()
        return method_name, message_type, sequence_id

    def skip_field(self, field_type: int, max_depth: int = 32) -> None:
        """Skip a field of given type without parsing its value."""
        if max_depth <= 0:
            raise ValueError("Maximum recursion depth exceeded while skipping field")

        if field_type == self.T_BOOL or field_type == self.T_BYTE:
            self.read_byte()
        elif field_type == self.T_I16:
            self.read_i16()
        elif field_type == self.T_I32:
            self.read_i32()
        elif field_type == self.T_I64:
            self.read_i64()
        elif field_type == self.T_DOUBLE:
            self.read_double()
        elif field_type == self.T_STRING:
            self.read_string()
        elif field_type == self.T_STRUCT:
            self._skip_struct(max_depth - 1)
        elif field_type == self.T_MAP:
            key_type = self.read_byte()
            val_type = self.read_byte()
            size = self.read_i32()
            for _ in range(size):
                self.skip_field(key_type, max_depth - 1)
                self.skip_field(val_type, max_depth - 1)
        elif field_type in (self.T_SET, self.T_LIST):
            elem_type = self.read_byte()
            size = self.read_i32()
            for _ in range(size):
                self.skip_field(elem_type, max_depth - 1)

    def _skip_struct(self, max_depth: int) -> None:
        """Skip an entire struct."""
        while True:
            field_type = self.read_byte()
            if field_type == self.T_STOP:
                break
            self.read_i16()  # field_id
            self.skip_field(field_type, max_depth)

    def read_field_value(self, field_type: int, max_depth: int = 32) -> Any:
        """Read and return a field value based on its type."""
        if max_depth <= 0:
            return "<max_depth_exceeded>"

        if field_type == self.T_BOOL:
            return bool(self.read_byte())
        elif field_type == self.T_BYTE:
            return self.read_byte()
        elif field_type == self.T_I16:
            return self.read_i16()
        elif field_type == self.T_I32:
            return self.read_i32()
        elif field_type == self.T_I64:
            return self.read_i64()
        elif field_type == self.T_DOUBLE:
            return self.read_double()
        elif field_type == self.T_STRING:
            return self.read_string()
        elif field_type == self.T_STRUCT:
            return self.read_struct(max_depth - 1)
        elif field_type == self.T_MAP:
            return self._read_map(max_depth - 1)
        elif field_type == self.T_SET:
            return self._read_set(max_depth - 1)
        elif field_type == self.T_LIST:
            return self._read_list(max_depth - 1)
        else:
            return f"<unknown_type:{field_type}>"

    def _read_map(self, max_depth: int) -> Dict[Any, Any]:
        """Read a Thrift map."""
        key_type = self.read_byte()
        val_type = self.read_byte()
        size = self.read_i32()

        if size > 10000:  # Sanity check
            return {"<large_map>": f"{size} entries"}

        result = {}
        for _ in range(size):
            key = self.read_field_value(key_type, max_depth)
            value = self.read_field_value(val_type, max_depth)
            result[key] = value
        return result

    def _read_set(self, max_depth: int) -> List[Any]:
        """Read a Thrift set (returned as list)."""
        elem_type = self.read_byte()
        size = self.read_i32()

        if size > 10000:  # Sanity check
            return [f"<large_set: {size} entries>"]

        result = []
        for _ in range(size):
            result.append(self.read_field_value(elem_type, max_depth))
        return result

    def _read_list(self, max_depth: int) -> List[Any]:
        """Read a Thrift list."""
        elem_type = self.read_byte()
        size = self.read_i32()

        if size > 10000:  # Sanity check
            return [f"<large_list: {size} entries>"]

        result = []
        for _ in range(size):
            result.append(self.read_field_value(elem_type, max_depth))
        return result

    def read_struct(self, max_depth: int = 32) -> Dict[str, Any]:
        """
        Read a Thrift struct and return field map with resolved field names.

        Returns:
            Dictionary mapping field name (or field_id if unknown) to {type, value}
        """
        if max_depth <= 0:
            return {"error": "max_depth_exceeded"}

        fields = {}
        while True:
            try:
                field_type = self.read_byte()
                if field_type == self.T_STOP:
                    break

                field_id = self.read_i16()
                type_name = self.TYPE_NAMES.get(field_type, f"type_{field_type}")

                # Resolve field name from field ID using thrift_spec
                field_name = self.field_name_map.get(field_id)
                if field_name:
                    field_key = field_name
                else:
                    field_key = f"field_{field_id}"

                try:
                    value = self.read_field_value(field_type, max_depth)
                    fields[field_key] = {"type": type_name, "value": value, "field_id": field_id}
                except Exception as e:
                    fields[field_key] = {"type": type_name, "error": str(e), "field_id": field_id}
                    # Try to skip and continue
                    try:
                        self.skip_field(field_type, max_depth)
                    except Exception:
                        break

            except EOFError:
                break
            except Exception as e:
                fields["_parse_error"] = str(e)
                break

        return fields

    def decode_message(self) -> Optional[Dict[str, Any]]:
        """
        Decode a complete Thrift message with field name resolution.

        Returns:
            Dictionary with message information and decoded fields
        """
        try:
            method_name, message_type, sequence_id = self.read_message_begin()

            message_type_str = self.MESSAGE_TYPE_NAMES.get(
                message_type, f"UNKNOWN({message_type})"
            )

            # Build field name map now that we know both method name and message type
            if not self.method_name:
                self.method_name = method_name
            self.message_type = message_type
            self.field_name_map = self._build_field_name_map(method_name, message_type)

            # Read the struct (request/response body)
            struct_fields = self.read_struct()

            result = {
                "method": method_name,
                "message_type": message_type_str,
                "sequence_id": sequence_id,
                "fields": struct_fields,
                "bytes_decoded": self.pos,
                "total_bytes": self.data_len,
            }

            # Add metadata
            if method_name in self.KNOWN_METHODS:
                result["protocol"] = "HiveServer2/Databricks"

            # Add field resolution status
            if THRIFT_TYPES_AVAILABLE and self.field_name_map:
                result["field_names_resolved"] = True
                result["resolved_fields_count"] = len(self.field_name_map)
                # Add info about whether this is a request or response
                if message_type == self.MESSAGE_TYPE_CALL:
                    result["struct_type"] = "Request"
                elif message_type == self.MESSAGE_TYPE_REPLY:
                    result["struct_type"] = "Response"
            else:
                result["field_names_resolved"] = False

            return result

        except Exception as e:
            return {
                "error": str(e),
                "error_type": type(e).__name__,
                "bytes_decoded": self.pos,
                "total_bytes": self.data_len,
            }


def decode_thrift_message(data: bytes) -> Optional[Dict[str, Any]]:
    """
    Decode a Thrift Binary Protocol message.

    Args:
        data: Raw Thrift message bytes

    Returns:
        Dictionary with decoded message info, or None if data is invalid
    """
    if not data or len(data) < 4:
        return None

    try:
        decoder = ThriftDecoder(data)
        return decoder.decode_message()
    except Exception as e:
        return {"error": str(e), "error_type": type(e).__name__}


def format_thrift_message(
    decoded: Dict[str, Any], max_field_length: int = 200, indent: int = 0
) -> str:
    """
    Format a decoded Thrift message for human-readable logging.

    Args:
        decoded: Decoded message dictionary from decode_thrift_message()
        max_field_length: Maximum length for field values in output
        indent: Indentation level for nested structures

    Returns:
        Formatted string representation
    """
    if not decoded:
        return "<empty message>"

    if "error" in decoded:
        return f"<decode error: {decoded['error']}>"

    prefix = "  " * indent
    lines = []

    # Header info
    lines.append(f"{prefix}Method: {decoded.get('method', 'unknown')}")
    lines.append(f"{prefix}Type: {decoded.get('message_type', 'unknown')}")
    lines.append(
        f"{prefix}Bytes: {decoded.get('bytes_decoded', 0)}/{decoded.get('total_bytes', 0)}"
    )

    if "protocol" in decoded:
        lines.append(f"{prefix}Protocol: {decoded['protocol']}")

    # Field resolution status
    if decoded.get("field_names_resolved"):
        lines.append(
            f"{prefix}Field Names: Resolved ({decoded.get('resolved_fields_count', 0)} mappings)"
        )
    else:
        if not THRIFT_TYPES_AVAILABLE:
            lines.append(f"{prefix}Field Names: Generic (thrift types not available)")
        else:
            lines.append(f"{prefix}Field Names: Generic (no mapping for this method)")

    # Fields
    fields = decoded.get("fields", {})
    if fields:
        lines.append(f"{prefix}Fields ({len(fields)}):")
        for field_name, field_data in sorted(fields.items()):
            if isinstance(field_data, dict) and "type" in field_data:
                field_type = field_data["type"]
                field_id = field_data.get("field_id", "")
                field_value = field_data.get(
                    "value", field_data.get("error", "<no value>")
                )

                value_str = str(field_value)
                if len(value_str) > max_field_length:
                    value_str = value_str[:max_field_length] + "..."

                # Show field ID if available (helps with debugging)
                id_suffix = f" [id={field_id}]" if field_id else ""
                lines.append(f"{prefix}  {field_name}{id_suffix} ({field_type}): {value_str}")
            else:
                value_str = str(field_data)
                if len(value_str) > max_field_length:
                    value_str = value_str[:max_field_length] + "..."
                lines.append(f"{prefix}  {field_name}: {value_str}")

    return "\n".join(lines)
