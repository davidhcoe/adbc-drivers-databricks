/*
* Copyright (c) 2025 ADBC Drivers Contributors
*
* Licensed to the Apache Software Foundation (ASF) under one
* or more contributor license agreements.  See the NOTICE file
* distributed with this work for additional information
* regarding copyright ownership.  The ASF licenses this file
* to you under the Apache License, Version 2.0 (the
* "License"); you may not use this file except in compliance
* with the License.  You may obtain a copy of the License at
*
*    http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using ProxyControlApi.Api;
using ProxyControlApi.Client;

namespace AdbcDrivers.Databricks.Tests.ThriftProtocol
{
    /// <summary>
    /// Simplified wrapper around the OpenAPI-generated ProxyControlApi client.
    /// Provides a clean interface for test code without requiring full DI setup.
    ///
    /// This wrapper manually instantiates the generated client dependencies to avoid
    /// requiring Microsoft.Extensions.Hosting setup in test code.
    /// </summary>
    public class ProxyControlClient : IDisposable
    {
        private readonly DefaultApi _api;
        private readonly HttpClient _httpClient;
        private readonly ILoggerFactory _loggerFactory;
        private bool _disposed;

        public ProxyControlClient(int apiPort = 18081)
        {
            _httpClient = new HttpClient
            {
                BaseAddress = new Uri($"http://localhost:{apiPort}"),
                Timeout = TimeSpan.FromSeconds(5)
            };

            // Create minimal dependencies for the generated client
            _loggerFactory = NullLoggerFactory.Instance;
            var logger = _loggerFactory.CreateLogger<DefaultApi>();
            var jsonOptions = new System.Text.Json.JsonSerializerOptions();
            var jsonProvider = new JsonSerializerOptionsProvider(jsonOptions);
            var events = new DefaultApiEvents();

            _api = new DefaultApi(logger, _loggerFactory, _httpClient, jsonProvider, events);
        }

        /// <summary>
        /// Lists all available failure scenarios and their current status.
        /// </summary>
        public async Task<List<FailureScenarioStatus>> ListScenariosAsync(CancellationToken cancellationToken = default)
        {
            var response = await _api.ListScenariosAsync(cancellationToken);

            if (!response.IsOk)
            {
                throw new InvalidOperationException($"Failed to list scenarios. Status: {response.StatusCode}");
            }

            var scenarioList = response.Ok();
            if (scenarioList?.Scenarios == null)
            {
                return new List<FailureScenarioStatus>();
            }

            return scenarioList.Scenarios.Select(s => new FailureScenarioStatus
            {
                Name = s.Name ?? string.Empty,
                Description = s.Description ?? string.Empty,
                Enabled = s.Enabled
            }).ToList();
        }

        /// <summary>
        /// Enables a failure scenario by name.
        /// </summary>
        public async Task<bool> EnableScenarioAsync(string scenarioName, CancellationToken cancellationToken = default)
        {
            var response = await _api.EnableScenarioAsync(scenarioName, cancellationToken);

            if (!response.IsOk)
            {
                throw new InvalidOperationException($"Failed to enable scenario '{scenarioName}'. Status: {response.StatusCode}");
            }

            var status = response.Ok();
            return status?.Enabled ?? false;
        }

        /// <summary>
        /// Disables a failure scenario by name.
        /// </summary>
        public async Task<bool> DisableScenarioAsync(string scenarioName, CancellationToken cancellationToken = default)
        {
            var response = await _api.DisableScenarioAsync(scenarioName, cancellationToken);

            if (!response.IsOk)
            {
                throw new InvalidOperationException($"Failed to disable scenario '{scenarioName}'. Status: {response.StatusCode}");
            }

            var status = response.Ok();
            return status?.Enabled ?? false;
        }

        /// <summary>
        /// Gets the status of a specific scenario by name.
        /// </summary>
        public async Task<FailureScenarioStatus?> GetScenarioStatusAsync(string scenarioName, CancellationToken cancellationToken = default)
        {
            var scenarios = await ListScenariosAsync(cancellationToken);
            return scenarios.Find(s => s.Name == scenarioName);
        }

        /// <summary>
        /// Disables all currently enabled scenarios.
        /// Useful for test cleanup.
        /// </summary>
        public async Task DisableAllScenariosAsync(CancellationToken cancellationToken = default)
        {
            var scenarios = await ListScenariosAsync(cancellationToken);
            foreach (var scenario in scenarios)
            {
                if (scenario.Enabled)
                {
                    await DisableScenarioAsync(scenario.Name, cancellationToken);
                }
            }
        }

        /// <summary>
        /// Gets the history of Thrift method calls recorded by the proxy.
        /// Call history is automatically reset when a scenario is enabled.
        /// </summary>
        public async Task<ThriftCallHistory> GetThriftCallsAsync(CancellationToken cancellationToken = default)
        {
            var response = await _httpClient.GetAsync("/thrift/calls", cancellationToken);
            response.EnsureSuccessStatusCode();

            var json = await response.Content.ReadAsStringAsync();
            var options = new System.Text.Json.JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            };
            var history = System.Text.Json.JsonSerializer.Deserialize<ThriftCallHistory>(json, options);
            return history ?? new ThriftCallHistory();
        }

        /// <summary>
        /// Counts how many times a specific Thrift method was called.
        /// </summary>
        public async Task<int> CountThriftMethodCallsAsync(string methodName, CancellationToken cancellationToken = default)
        {
            var history = await GetThriftCallsAsync(cancellationToken);
            return history.Calls?.Count(c => c.Type == "thrift" && c.Method == methodName) ?? 0;
        }

        /// <summary>
        /// Counts how many cloud download requests were made.
        /// </summary>
        public async Task<int> CountCloudDownloadsAsync(CancellationToken cancellationToken = default)
        {
            var history = await GetThriftCallsAsync(cancellationToken);
            return history.Calls?.Count(c => c.Type == "cloud_download") ?? 0;
        }

        /// <summary>
        /// Verifies that a Thrift method was called at least the specified number of times.
        /// </summary>
        public async Task AssertThriftMethodCalledAsync(string methodName, int minCalls, CancellationToken cancellationToken = default)
        {
            var actualCalls = await CountThriftMethodCallsAsync(methodName, cancellationToken);
            if (actualCalls < minCalls)
            {
                throw new Xunit.Sdk.XunitException(
                    $"Expected {methodName} to be called at least {minCalls} time(s), but was called {actualCalls} time(s)");
            }
        }

        /// <summary>
        /// Gets all Thrift calls for a specific method name.
        /// Returns the calls with decoded field information.
        /// </summary>
        public async Task<List<ThriftCall>> GetThriftMethodCallsAsync(string methodName, CancellationToken cancellationToken = default)
        {
            var history = await GetThriftCallsAsync(cancellationToken);
            return history.Calls?
                .Where(c => c.Type == "thrift" && c.Method == methodName)
                .ToList() ?? new List<ThriftCall>();
        }

        /// <summary>
        /// Verifies that a specific Thrift method was called exactly the expected number of times.
        /// Provides detailed diagnostics showing the actual calls with decoded field information.
        /// </summary>
        public async Task AssertThriftMethodCallCountAsync(
            string methodName,
            int expectedCalls,
            CancellationToken cancellationToken = default)
        {
            var calls = await GetThriftMethodCallsAsync(methodName, cancellationToken);
            var actualCalls = calls.Count;

            if (actualCalls != expectedCalls)
            {
                var diagnostics = $"Expected {methodName} to be called exactly {expectedCalls} time(s), but was called {actualCalls} time(s)\n\n";
                diagnostics += "Actual calls:\n";

                for (int i = 0; i < calls.Count; i++)
                {
                    var call = calls[i];
                    diagnostics += $"\nCall {i + 1}:\n";
                    diagnostics += $"  Timestamp: {call.Timestamp}\n";
                    diagnostics += $"  Message Type: {call.MessageType}\n";
                    diagnostics += $"  Sequence ID: {call.SequenceId}\n";

                    if (call.Fields != null)
                    {
                        diagnostics += "  Decoded Fields:\n";
                        foreach (var prop in call.Fields.Value.EnumerateObject())
                        {
                            diagnostics += $"    {prop.Name}: {prop.Value}\n";
                        }
                    }
                }

                throw new Xunit.Sdk.XunitException(diagnostics);
            }
        }

        /// <summary>
        /// Verifies that FetchResults was called exactly twice after URL expiry,
        /// with the second call having the same operation handle (proving it's a retry for fresh URL).
        /// Also ensures that operation handles are non-empty (valid).
        /// </summary>
        public async Task AssertFetchResultsCalledTwiceWithSameOperationAsync(
            CancellationToken cancellationToken = default)
        {
            var fetchResultsCalls = await GetThriftMethodCallsAsync("FetchResults", cancellationToken);

            if (fetchResultsCalls.Count < 2)
            {
                throw new Xunit.Sdk.XunitException(
                    $"Expected at least 2 FetchResults calls, but found {fetchResultsCalls.Count}");
            }

            // Get the last two FetchResults calls (most recent retry scenario)
            var firstCall = fetchResultsCalls[fetchResultsCalls.Count - 2];
            var secondCall = fetchResultsCalls[fetchResultsCalls.Count - 1];

            // Extract operation handles from decoded fields
            string firstOperationHandle = ExtractOperationHandle(firstCall);
            string secondOperationHandle = ExtractOperationHandle(secondCall);

            // Build detailed diagnostics
            var diagnostics = new System.Text.StringBuilder();
            diagnostics.AppendLine("FetchResults Call Analysis:");
            diagnostics.AppendLine($"\nFirst Call (index {fetchResultsCalls.Count - 2}):");
            diagnostics.AppendLine($"  Timestamp: {firstCall.Timestamp}");
            diagnostics.AppendLine($"  Extracted operation handle: '{firstOperationHandle}'");
            diagnostics.AppendLine($"  Handle length: {firstOperationHandle.Length} chars");
            diagnostics.AppendLine($"  Handle is empty: {string.IsNullOrEmpty(firstOperationHandle)}");

            diagnostics.AppendLine($"\nSecond Call (index {fetchResultsCalls.Count - 1}):");
            diagnostics.AppendLine($"  Timestamp: {secondCall.Timestamp}");
            diagnostics.AppendLine($"  Extracted operation handle: '{secondOperationHandle}'");
            diagnostics.AppendLine($"  Handle length: {secondOperationHandle.Length} chars");
            diagnostics.AppendLine($"  Handle is empty: {string.IsNullOrEmpty(secondOperationHandle)}");

            // Validate that operation handles are non-empty
            if (string.IsNullOrEmpty(firstOperationHandle))
            {
                throw new Xunit.Sdk.XunitException(
                    $"First FetchResults call has EMPTY operation handle.\n\n{diagnostics}\n\n" +
                    "This indicates either:\n" +
                    "  1. Thrift decoding failed\n" +
                    "  2. The decoded structure changed\n" +
                    "  3. The operation handle was not properly set by the driver");
            }

            if (string.IsNullOrEmpty(secondOperationHandle))
            {
                throw new Xunit.Sdk.XunitException(
                    $"Second FetchResults call has EMPTY operation handle.\n\n{diagnostics}\n\n" +
                    "This indicates either:\n" +
                    "  1. Thrift decoding failed\n" +
                    "  2. The decoded structure changed\n" +
                    "  3. The operation handle was not properly set by the driver");
            }

            // Check for extraction errors
            if (firstOperationHandle.StartsWith("<error:") || secondOperationHandle.StartsWith("<error:"))
            {
                throw new Xunit.Sdk.XunitException(
                    $"Error extracting operation handles:\n\n{diagnostics}");
            }

            // Verify they match (proving it's a retry for the same operation)
            if (firstOperationHandle != secondOperationHandle)
            {
                throw new Xunit.Sdk.XunitException(
                    $"FetchResults calls have DIFFERENT operation handles:\n\n{diagnostics}\n\n" +
                    "Expected them to be identical (retry with same operation after URL expiry).\n" +
                    "Having different handles means the driver created a NEW operation instead of retrying the existing one.");
            }

            // Success - operation handles are non-empty and identical
        }

        /// <summary>
        /// Extracts the operation handle GUID from a FetchResults call's decoded fields.
        ///
        /// Note: Due to how the Thrift decoder works, nested structs reuse parent field names.
        /// So the path is: operationHandle.value.operationHandle.value.operationHandle.value
        /// This navigates: TFetchResultsReq → TOperationHandle → THandleIdentifier → guid
        /// </summary>
        private string ExtractOperationHandle(ThriftCall call)
        {
            if (call.Fields == null)
                return string.Empty;

            try
            {
                // Navigate: FetchResultsReq.operationHandle → value (TOperationHandle struct)
                if (!call.Fields.Value.TryGetProperty("operationHandle", out var opHandleField))
                    return string.Empty;

                if (!opHandleField.TryGetProperty("value", out var opHandleStruct))
                    return string.Empty;

                // Navigate: TOperationHandle.operationId → value (THandleIdentifier struct)
                // Note: Due to decoder behavior, this is also named "operationHandle" (field id 1)
                if (!opHandleStruct.TryGetProperty("operationHandle", out var opIdField))
                    return string.Empty;

                if (!opIdField.TryGetProperty("value", out var opIdStruct))
                    return string.Empty;

                // Navigate: THandleIdentifier.guid → value (bytes/string)
                // Note: Due to decoder behavior, this is also named "operationHandle" (field id 1)
                if (!opIdStruct.TryGetProperty("operationHandle", out var guidField))
                    return string.Empty;

                if (!guidField.TryGetProperty("value", out var guidValue))
                    return string.Empty;

                // The GUID is stored as a byte string, decode it
                string guidString = guidValue.GetString() ?? string.Empty;

                // Remove null padding if present
                guidString = guidString.TrimEnd('\0');

                return guidString;
            }
            catch (Exception ex)
            {
                // Return empty with error indication
                return $"<error: {ex.Message}>";
            }
        }

        public void Dispose()
        {
            if (!_disposed)
            {
                _httpClient?.Dispose();
                _loggerFactory?.Dispose();
                _disposed = true;
            }
        }
    }

    /// <summary>
    /// Represents the status of a failure scenario.
    /// </summary>
    public class FailureScenarioStatus
    {
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public bool Enabled { get; set; }
    }

    /// <summary>
    /// Represents the history of Thrift method calls recorded by the proxy.
    /// </summary>
    public class ThriftCallHistory
    {
        public List<ThriftCall> Calls { get; set; } = new List<ThriftCall>();
        public int Count { get; set; }
        public int MaxHistory { get; set; }
    }

    /// <summary>
    /// Represents a single tracked call (Thrift method or cloud download).
    /// </summary>
    public class ThriftCall
    {
        public double Timestamp { get; set; }
        public string Type { get; set; } = string.Empty; // "thrift" or "cloud_download"
        public string Method { get; set; } = string.Empty; // For Thrift calls
        public string MessageType { get; set; } = string.Empty; // For Thrift calls
        public int SequenceId { get; set; } // For Thrift calls
        public System.Text.Json.JsonElement? Fields { get; set; } // For Thrift calls
        public string Url { get; set; } = string.Empty; // For cloud downloads
    }
}
