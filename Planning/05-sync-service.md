# APISyncService Implementation Plan

## Overview

APISyncService syncs step data to the backend API. For each `SyncInterval` where `syncedToServer == false`, it:
1. Queries HealthKit for raw step samples (using the interval's date range)
2. POSTs the samples to the API
3. Updates `syncedToServer = true` on success

**Important**: Read this entire document before implementing. Follow the specifications exactly.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      APISyncService                              │
│  - Coordinates sync process                                      │
│  - Iterates through unsynced intervals                           │
│  - Updates interval status on success                            │
└─────────────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
┌─────────────────────┐      ┌─────────────────────────┐
│  StepDataProvider   │      │   APIClient (Protocol)  │
│  (HealthKit/Mock)   │      │   - POST /steps         │
│  - getRawStepSamples│      │   - GET /steps          │
└─────────────────────┘      └─────────────────────────┘
                                       │
                       ┌───────────────┴───────────────┐
                       ▼                               ▼
              ┌─────────────────┐            ┌─────────────────┐
              │  LiveAPIClient  │            │  MockAPIClient  │
              │  (HTTP calls)   │            │  (In-memory)    │
              └─────────────────┘            └─────────────────┘
```

---

## Task 1: Create StepSampleDTO

Data Transfer Object for API communication.

**File**: `ios/HealthStepsSync/Models/StepSampleDTO.swift`

```swift
import Foundation

/// Data Transfer Object for step samples sent to API
struct StepSampleDTO: Codable, Sendable {
    let id: String
    let startDate: String  // ISO 8601 format
    let endDate: String    // ISO 8601 format
    let count: Int
    let sourceBundleId: String
    let sourceDeviceName: String?
    
    /// Create from StepSampleData protocol
    init(from sample: StepSampleData) {
        self.id = sample.uuid.uuidString
        self.startDate = ISO8601DateFormatter().string(from: sample.startDate)
        self.endDate = ISO8601DateFormatter().string(from: sample.endDate)
        self.count = sample.count
        self.sourceBundleId = sample.sourceBundleId
        self.sourceDeviceName = sample.sourceDeviceName
    }
}

/// Request body for POST /steps
struct StepSampleRequest: Codable, Sendable {
    let samples: [StepSampleDTO]
}

/// Response from POST /steps
struct StepSampleResponse: Codable, Sendable {
    let saved: Int
    let message: String
}

/// Response from GET /steps
struct StepSampleListResponse: Codable, Sendable {
    let samples: [StepSampleDTO]
    let total: Int
}
```

---

## Task 2: Create APIClient Protocol

**File**: `ios/HealthStepsSync/Services/API/APIClient.swift`

```swift
import Foundation

/// Protocol for API communication
protocol APIClient: Sendable {
    /// POST step samples to the server
    /// - Parameter samples: Array of step sample DTOs
    /// - Returns: Response with count of saved samples
    func postSteps(_ samples: [StepSampleDTO]) async throws -> StepSampleResponse
    
    /// GET all step samples from the server (for verification)
    /// - Returns: Response with all stored samples
    func getSteps() async throws -> StepSampleListResponse
    
    /// Health check - verify server is reachable
    func healthCheck() async throws -> Bool
}
```

---

## Task 3: Create APIError Enum

**File**: `ios/HealthStepsSync/Services/API/APIError.swift`

```swift
import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case networkError(underlying: Error)
    case serverError(statusCode: Int, message: String?)
    case decodingError(underlying: Error)
    case serverUnreachable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error \(code): \(message ?? "Unknown")"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverUnreachable:
            return "Server is not reachable"
        }
    }
}
```

---

## Task 4: Create LiveAPIClient

**File**: `ios/HealthStepsSync/Services/API/LiveAPIClient.swift`

```swift
import Foundation

/// Production API client that makes real HTTP requests
final class LiveAPIClient: APIClient, Sendable {
    
    private let baseURL: URL
    private let session: URLSession
    
    /// Initialize with base URL
    /// - Parameter baseURL: Base URL of the API (e.g., "http://localhost:8000")
    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }
    
    /// Convenience initializer with string URL
    init(baseURLString: String) throws {
        guard let url = URL(string: baseURLString) else {
            throw APIError.invalidURL
        }
        self.baseURL = url
        self.session = .shared
    }
    
    // MARK: - APIClient Protocol
    
    func postSteps(_ samples: [StepSampleDTO]) async throws -> StepSampleResponse {
        let url = baseURL.appendingPathComponent("steps")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = StepSampleRequest(samples: samples)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(underlying: URLError(.badServerResponse))
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
        
        do {
            return try JSONDecoder().decode(StepSampleResponse.self, from: data)
        } catch {
            throw APIError.decodingError(underlying: error)
        }
    }
    
    func getSteps() async throws -> StepSampleListResponse {
        let url = baseURL.appendingPathComponent("steps")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(underlying: URLError(.badServerResponse))
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
        
        do {
            return try JSONDecoder().decode(StepSampleListResponse.self, from: data)
        } catch {
            throw APIError.decodingError(underlying: error)
        }
    }
    
    func healthCheck() async throws -> Bool {
        let url = baseURL.appendingPathComponent("health")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5  // Short timeout for health check
        
        do {
            let (_, response) = try await performRequest(request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }
    
    // MARK: - Private
    
    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw APIError.networkError(underlying: error)
        }
    }
}
```

---

## Task 5: Create MockAPIClient

**File**: `ios/HealthStepsSync/Services/API/MockAPIClient.swift`

```swift
import Foundation

/// Mock API client for testing - stores data in memory
actor MockAPIClient: APIClient {
    
    private var storedSamples: [StepSampleDTO] = []
    private let simulatedDelay: UInt64
    
    /// Initialize mock client
    /// - Parameter simulatedDelay: Delay in nanoseconds to simulate network (default: 50ms)
    init(simulatedDelay: UInt64 = 50_000_000) {
        self.simulatedDelay = simulatedDelay
    }
    
    // MARK: - APIClient Protocol
    
    func postSteps(_ samples: [StepSampleDTO]) async throws -> StepSampleResponse {
        // Simulate network delay
        try await Task.sleep(nanoseconds: simulatedDelay)
        
        // Store samples (avoid duplicates by ID)
        let existingIds = Set(storedSamples.map(\.id))
        let newSamples = samples.filter { !existingIds.contains($0.id) }
        storedSamples.append(contentsOf: newSamples)
        
        return StepSampleResponse(
            saved: newSamples.count,
            message: "Success"
        )
    }
    
    func getSteps() async throws -> StepSampleListResponse {
        // Simulate network delay
        try await Task.sleep(nanoseconds: simulatedDelay)
        
        return StepSampleListResponse(
            samples: storedSamples,
            total: storedSamples.count
        )
    }
    
    func healthCheck() async throws -> Bool {
        try await Task.sleep(nanoseconds: simulatedDelay / 2)
        return true
    }
    
    // MARK: - Test Helpers
    
    /// Clear all stored samples (for testing)
    func clear() {
        storedSamples.removeAll()
    }
    
    /// Get current count of stored samples (for testing)
    func count() -> Int {
        storedSamples.count
    }
}
```

---

## Task 6: Create APISyncService Protocol

**File**: `ios/HealthStepsSync/Services/Sync/APISyncServiceProtocol.swift`

```swift
import Foundation

/// Protocol for syncing intervals to the API
@MainActor
protocol APISyncServiceProtocol {
    /// Sync all unsynced intervals to the API
    /// - Returns: Number of intervals successfully synced
    func syncAllPendingIntervals() async throws -> Int
    
    /// Sync a single interval to the API
    /// - Parameter interval: The interval to sync
    /// - Returns: Number of samples synced
    func syncInterval(_ interval: SyncInterval) async throws -> Int
    
    /// Check if API is reachable
    func isAPIReachable() async -> Bool
}
```

---

## Task 7: Create APISyncService Implementation

**File**: `ios/HealthStepsSync/Services/Sync/APISyncService.swift`

```swift
import Foundation
import SwiftData

/// Service that syncs step data to the API
@MainActor
final class APISyncService: APISyncServiceProtocol {
    
    // MARK: - Constants
    
    private let batchSize = 1000  // Samples per API request
    
    // MARK: - Dependencies
    
    private let stepDataProvider: StepDataProvider
    private let apiClient: APIClient
    private let storageProvider: LocalStorageProvider
    
    // MARK: - Init
    
    init(
        stepDataProvider: StepDataProvider,
        apiClient: APIClient,
        storageProvider: LocalStorageProvider
    ) {
        self.stepDataProvider = stepDataProvider
        self.apiClient = apiClient
        self.storageProvider = storageProvider
    }
    
    // MARK: - Public Methods
    
    func syncAllPendingIntervals() async throws -> Int {
        // Get all unsynced intervals
        let pendingIntervals = try storageProvider.fetchUnsyncedIntervals()
        
        var syncedCount = 0
        
        for interval in pendingIntervals {
            do {
                _ = try await syncInterval(interval)
                syncedCount += 1
            } catch {
                // Log error but continue with other intervals
                print("Failed to sync interval \(interval.id): \(error)")
                // Could add retry logic here in future
            }
        }
        
        return syncedCount
    }
    
    func syncInterval(_ interval: SyncInterval) async throws -> Int {
        // 1. Query raw step samples from HealthKit
        let dateInterval = DateInterval(start: interval.startDate, end: interval.endDate)
        let samples = try await stepDataProvider.getRawStepSamples(for: dateInterval)
        
        // 2. Convert to DTOs
        let dtos = samples.map { StepSampleDTO(from: $0) }
        
        // 3. Send to API in batches
        var totalSaved = 0
        
        for batch in dtos.chunked(into: batchSize) {
            let response = try await apiClient.postSteps(batch)
            totalSaved += response.saved
        }
        
        // 4. Mark interval as synced
        interval.syncedToServer = true
        try storageProvider.save()
        
        return totalSaved
    }
    
    func isAPIReachable() async -> Bool {
        do {
            return try await apiClient.healthCheck()
        } catch {
            return false
        }
    }
}

// MARK: - Array Extension for Batching

extension Array {
    /// Split array into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
```

---

## Task 8: Update LocalStorageProvider Protocol

Add method to fetch unsynced intervals.

**Update File**: `ios/HealthStepsSync/Services/Layering/LocalStorageProvider.swift`

```swift
import Foundation

protocol LocalStorageProvider {
    func insertInterval(_ interval: SyncInterval)
    func deleteIntervals() throws
    func save() throws
    
    // ADD THIS METHOD:
    func fetchUnsyncedIntervals() throws -> [SyncInterval]
}
```

---

## Task 9: Update SwiftDataStorageProvider

**Update File**: `ios/HealthStepsSync/Services/Layering/SwiftDataStorageProvider.swift`

```swift
import Foundation
import SwiftData

class SwiftDataStorageProvider: LocalStorageProvider {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func insertInterval(_ interval: SyncInterval) {
        modelContext.insert(interval)
    }
    
    func deleteIntervals() throws {
        try modelContext.delete(model: SyncInterval.self)
    }
    
    func save() throws {
        try modelContext.save()
    }
    
    // ADD THIS METHOD:
    func fetchUnsyncedIntervals() throws -> [SyncInterval] {
        let descriptor = FetchDescriptor<SyncInterval>(
            predicate: #Predicate { $0.syncedToServer == false },
            sortBy: [SortDescriptor(\.startDate)]
        )
        return try modelContext.fetch(descriptor)
    }
}
```

---

## Task 10: Create Mock API Server (Python/FastAPI)

**File**: `api/main.py`

```python
"""
Mock API Server for iOS Health Steps Sync

Run with: uvicorn main:app --host 0.0.0.0 --port 8000
"""

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional
import json
from pathlib import Path
from datetime import datetime
import threading

app = FastAPI(title="Health Steps Sync API")

# File path for JSONL storage
DATA_FILE = Path("data/steps.jsonl")
DATA_FILE.parent.mkdir(exist_ok=True)

# Thread lock for file writes
file_lock = threading.Lock()


# --- Models ---

class StepSample(BaseModel):
    id: str
    startDate: str
    endDate: str
    count: int
    sourceBundleId: str
    sourceDeviceName: Optional[str] = None


class StepSampleRequest(BaseModel):
    samples: list[StepSample]


class StepSampleResponse(BaseModel):
    saved: int
    message: str


class StepSampleListResponse(BaseModel):
    samples: list[StepSample]
    total: int


class HealthResponse(BaseModel):
    status: str


# --- Endpoints ---

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    return HealthResponse(status="ok")


@app.post("/steps", response_model=StepSampleResponse)
async def post_steps(request: StepSampleRequest):
    """
    Receive and persist step samples.
    Appends to JSONL file (one JSON object per line).
    """
    if not request.samples:
        return StepSampleResponse(saved=0, message="No samples provided")
    
    received_at = datetime.utcnow().isoformat() + "Z"
    saved_count = 0
    
    with file_lock:
        with open(DATA_FILE, "a") as f:
            for sample in request.samples:
                record = {
                    "id": sample.id,
                    "startDate": sample.startDate,
                    "endDate": sample.endDate,
                    "count": sample.count,
                    "sourceBundleId": sample.sourceBundleId,
                    "sourceDeviceName": sample.sourceDeviceName,
                    "receivedAt": received_at
                }
                f.write(json.dumps(record) + "\n")
                saved_count += 1
    
    return StepSampleResponse(saved=saved_count, message="Success")


@app.get("/steps", response_model=StepSampleListResponse)
async def get_steps():
    """
    Retrieve all stored step samples.
    Reads from JSONL file.
    """
    samples = []
    
    if DATA_FILE.exists():
        with file_lock:
            with open(DATA_FILE, "r") as f:
                for line in f:
                    line = line.strip()
                    if line:
                        record = json.loads(line)
                        samples.append(StepSample(
                            id=record["id"],
                            startDate=record["startDate"],
                            endDate=record["endDate"],
                            count=record["count"],
                            sourceBundleId=record["sourceBundleId"],
                            sourceDeviceName=record.get("sourceDeviceName")
                        ))
    
    return StepSampleListResponse(samples=samples, total=len(samples))


@app.delete("/steps")
async def delete_steps():
    """
    Delete all stored step samples (for testing).
    """
    with file_lock:
        if DATA_FILE.exists():
            DATA_FILE.unlink()
    
    return {"deleted": True, "message": "All samples deleted"}


# --- Main ---

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

---

## Task 11: Create API Requirements File

**File**: `api/requirements.txt`

```
fastapi==0.109.0
uvicorn==0.27.0
pydantic==2.5.3
```

---

## File Structure After Implementation

```
ios/HealthStepsSync/
├── Models/
│   ├── SyncInterval.swift              # EXISTS
│   └── StepSampleDTO.swift             # NEW
├── Services/
│   ├── HealthKit/
│   │   └── ... (existing files)
│   ├── Layering/
│   │   ├── ... (existing files)
│   │   ├── LocalStorageProvider.swift  # UPDATE (add fetchUnsyncedIntervals)
│   │   └── SwiftDataStorageProvider.swift # UPDATE
│   ├── API/
│   │   ├── APIClient.swift             # NEW
│   │   ├── APIError.swift              # NEW
│   │   ├── LiveAPIClient.swift         # NEW
│   │   └── MockAPIClient.swift         # NEW
│   └── Sync/
│       ├── APISyncServiceProtocol.swift # NEW
│       └── APISyncService.swift         # NEW

api/
├── main.py                             # NEW
├── requirements.txt                    # NEW
└── data/
    └── steps.jsonl                     # Created at runtime
```

---

## Usage Examples

### iOS App - Production

```swift
// Create dependencies
let healthKitProvider = HealthKitStatisticsQueryProvider()
let healthKitManager = HealthKitManager(healthKitProvider: healthKitProvider)

let apiClient = try LiveAPIClient(baseURLString: "http://localhost:8000")
let storageProvider = SwiftDataStorageProvider(modelContext: modelContext)

// Create sync service
let syncService = APISyncService(
    stepDataProvider: healthKitManager,
    apiClient: apiClient,
    storageProvider: storageProvider
)

// Check API is reachable
guard await syncService.isAPIReachable() else {
    print("API not reachable")
    return
}

// Sync all pending intervals
let syncedCount = try await syncService.syncAllPendingIntervals()
print("Synced \(syncedCount) intervals")
```

### iOS App - Testing

```swift
// Use mocks for testing
let mockHealthKit = MockStatisticsQueryProvider(seed: 42)
let healthKitManager = HealthKitManager(healthKitProvider: mockHealthKit)

let mockAPI = MockAPIClient()
let mockStorage = MockStorageProvider()

let syncService = APISyncService(
    stepDataProvider: healthKitManager,
    apiClient: mockAPI,
    storageProvider: mockStorage
)

// Test sync
let syncedCount = try await syncService.syncAllPendingIntervals()
```

### Running the API Server

```bash
cd api

# Create virtual environment (optional)
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run server
uvicorn main:app --host 0.0.0.0 --port 8000

# Or with auto-reload for development
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### Testing the API

```bash
# Health check
curl http://localhost:8000/health

# Post samples
curl -X POST http://localhost:8000/steps \
  -H "Content-Type: application/json" \
  -d '{"samples": [{"id": "test-1", "startDate": "2024-01-15T10:00:00Z", "endDate": "2024-01-15T10:05:00Z", "count": 500, "sourceBundleId": "com.test", "sourceDeviceName": "iPhone"}]}'

# Get all samples
curl http://localhost:8000/steps

# Delete all (for testing)
curl -X DELETE http://localhost:8000/steps
```

---

## Testing Checklist

### API Server
- [ ] `GET /health` returns `{"status": "ok"}`
- [ ] `POST /steps` saves samples to JSONL file
- [ ] `GET /steps` returns all stored samples
- [ ] `DELETE /steps` clears the file
- [ ] JSONL file contains one JSON object per line
- [ ] Thread-safe file writes (concurrent requests don't corrupt)

### iOS APISyncService
- [ ] `isAPIReachable()` returns true when server running
- [ ] `syncInterval()` fetches samples and posts to API
- [ ] `syncInterval()` marks interval as `syncedToServer = true`
- [ ] `syncAllPendingIntervals()` processes all unsynced intervals
- [ ] Batching works (1000 samples per request)
- [ ] Works with MockAPIClient (no server needed)

### Integration
- [ ] Full flow: LayeringService → APISyncService → API → JSONL
- [ ] Can sync with mock HealthKit + real API
- [ ] Can sync with mock HealthKit + mock API (for unit tests)

---

## Important Notes for Implementation

1. **Do not modify** existing HealthKit files
2. **Use exact method signatures** as specified
3. **Batch size**: 1000 samples per API request
4. **Error handling**: Log errors but continue with other intervals
5. **Thread safety**: API uses file lock for JSONL writes
6. **ISO 8601 dates**: All dates in UTC with Z suffix
7. **JSONL format**: One JSON object per line, no array wrapper

---

## Definition of Done

### iOS
- [ ] All 7 new files created in correct locations
- [ ] LocalStorageProvider updated with fetchUnsyncedIntervals
- [ ] SwiftDataStorageProvider updated
- [ ] APISyncService compiles without errors
- [ ] Works with MockAPIClient (no server needed)

### API Server
- [ ] main.py and requirements.txt created
- [ ] Server starts with `uvicorn main:app`
- [ ] All endpoints work (health, post, get, delete)
- [ ] JSONL file created in `data/` directory

### Integration
- [ ] iOS app can connect to running server
- [ ] Full sync flow works end-to-end
