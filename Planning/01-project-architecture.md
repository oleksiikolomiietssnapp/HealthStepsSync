# iOS Health Steps Sync - Project Plan

## Overview

Build an iOS app that reads raw step count data from Apple Health and syncs it to a locally running mock API that persists data to a JSONL file.

---

## Project Structure

```
ios-health-steps-sync/
├── README.md
├── ios/
│   ├── HealthStepsSync.xcodeproj/
│   └── HealthStepsSync/
│       ├── App/
│       │   ├── HealthStepsSyncApp.swift
│       │   └── Info.plist
│       ├── Models/
│       │   ├── StepSample.swift          ← SwiftData @Model (step data)
│       │   └── SyncInterval.swift        ← SwiftData @Model (progress tracking)
│       ├── Services/
│       │   ├── HealthKitManager.swift    ← HealthKit queries
│       │   ├── LayeringService.swift     ← Stage 1: interval discovery
│       │   ├── FetchService.swift        ← Stage 2a: raw data → SwiftData
│       │   └── APISyncService.swift      ← Stage 2b: SwiftData → API
│       ├── Views/
│       │   └── ContentView.swift
│       └── HealthStepsSync.entitlements
└── api/
    ├── main.py
    ├── requirements.txt
    └── data/
        └── steps.jsonl
```

---

## Component Breakdown

### 1. iOS App Components

#### Models/StepSample.swift (SwiftData)
```
@Model StepSample
├── id: UUID (from HealthKit sample UUID) ← PRIMARY KEY
├── startDate: Date
├── endDate: Date  
├── count: Int
├── sourceBundleId: String
├── sourceDeviceName: String?
├── synced: Bool              ← tracks API sync status
└── fetchedAt: Date           ← when we pulled from HealthKit

Index on: [synced] for efficient "get unsynced" queries
Unique constraint on: [id] for upsert behavior
```

#### Models/SyncInterval.swift (SwiftData)
```
@Model SyncInterval
├── id: UUID
├── startDate: Date
├── endDate: Date
├── status: IntervalStatus    ← enum: pending, empty, fetched
└── stepCount: Int?           ← from aggregated query (for debugging)

enum IntervalStatus: String, Codable {
    case pending   // discovered, not yet fetched
    case empty     // checked, no data
    case fetched   // raw data pulled to SwiftData
}

Purpose: Track layering progress for pause/resume
```

#### Services/HealthKitManager.swift
```
Purpose: Low-level HealthKit interactions
Responsibilities:
- Request authorization
- Execute HKStatisticsQuery (aggregated, for layering)
- Execute HKSampleQuery (raw samples, for fetching)
- Provide async/await interface
```

#### Services/LayeringService.swift (Stage 1)
```
Purpose: Discover date intervals containing step data
Responsibilities:
- Implement recursive interval subdivision
- Query aggregated data to check for presence
- Return array of DateInterval to fetch
- Handle edge cases (no data, sparse data)
```

#### Services/FetchService.swift (Stage 2a)
```
Purpose: Fetch raw samples and persist to SwiftData
Responsibilities:
- Iterate through intervals from LayeringService
- Query raw HKQuantitySamples
- Batch insert to SwiftData (synced: false)
- Report progress
```

#### Services/APISyncService.swift (Stage 2b)
```
Purpose: Sync SwiftData records to API
Responsibilities:
- Query unsynced records from SwiftData (1000 at a time)
- POST batches to API
- Update synced = true on success
- Handle retries on failure
- Report progress
```

#### Views/ContentView.swift
```
Purpose: UI for monitoring and controlling sync process
Features:
- Start/Pause/Continue button
- Current stage indicator (Layering / Fetching / Syncing)
- Stage 1 progress (intervals discovered / checked)
- Stage 2a progress (samples fetched / saved to local DB)
- Stage 2b progress (samples synced to API / total unsynced)
- Error display
```

### 2. API Components

#### main.py (Python/FastAPI)
```
Purpose: Receive and persist step data
Endpoints:
- POST /steps - Receive batch of step samples
- GET /health - Health check endpoint
Features:
- Append to JSONL file
- Thread-safe file writes
- Return success/failure status
```

---

## Key Architecture Decisions

### Two-Stage Sync Architecture

The sync process is split into two distinct stages to handle potentially 10GB+ of data efficiently:

```
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 1: LAYERING (Discovery)                                  │
│  - Query AGGREGATED data (fast, lightweight)                    │
│  - Binary subdivision to find intervals with data               │
│  - Stop when interval ≤ 10,000 steps                            │
│  - Output: SyncInterval records in SwiftData                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 2a: FETCH (HealthKit → SwiftData)                        │
│  - Query RAW samples for each pending interval                  │
│  - Batch upsert to SwiftData (1000 at a time)                   │
│  - Mark interval as "fetched"                                   │
│  - All records saved with synced=false                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 2b: SYNC (SwiftData → API)                               │
│  - Query unsynced records (1000 at a time)                      │
│  - POST to API                                                   │
│  - On success: set synced=true                                  │
│  - Repeat until no unsynced remain                              │
└─────────────────────────────────────────────────────────────────┘
```

---

### Decision 1: Layering Algorithm (Stage 1)

**Concept:** Instead of blindly querying 10 years of data, first discover WHERE data exists using cheap aggregated queries.

**Algorithm (Finalized):**
- Start with max range (10 years)
- Binary division (divide by 2)
- Query aggregated step count for each subdivision
- If count > 10,000: subdivide further
- If count ≤ 10,000 and > 0: mark as "ready to fetch"
- If count == 0: mark as "empty" (skip, but track for resume)

**Output:** `[SyncInterval]` stored in SwiftData with status: pending/empty/fetched

---

### Decision 2: SwiftData as Intermediate Storage (Stage 2)

**Why SwiftData instead of direct API upload:**
- **Memory safety**: Can't hold 10GB in memory
- **Resumability**: App crash/kill doesn't lose progress
- **Decoupled concerns**: Fetching and syncing are separate operations
- **Progress tracking**: `synced: Bool` flag = simple state management

**Duplicate Handling (Upsert Strategy):**
- Use HealthKit's `sample.uuid` as `@Attribute(.unique)` primary key
- On insert: check if exists → update if found, insert if not
- Re-running sync won't create duplicates
- If HealthKit data changes, record gets re-synced

---

### Decision 3: Sequential Execution Strategy

**Approach:** Fetch all → then Sync all (sequential, not parallel)

```
Timeline:
───────────────────────────────────────────────────────────────►
│ Stage 2a: Fetch all intervals to SwiftData                    │
│                                                                │
│                              │ Stage 2b: Sync all to API      │
```

**Rationale:**
- Simpler to implement and debug
- No concurrent SwiftData access concerns
- Easy to parallelize later (just change when Stage 2b starts)
- Pause/Continue naturally works with `synced: Bool` flag

---

### Decision 4: API Technology Choice

**Options:**
| Technology | Pros | Cons |
|------------|------|------|
| Python/FastAPI | Quick to write, good async | Requires Python environment |
| Node/Express | Universal, easy setup | Callback-heavy without TypeScript |
| Go/net/http | Fast, single binary | More verbose |

**Recommendation:** Python/FastAPI
- Fastest to implement
- Built-in async support
- Easy JSONL file handling

---

### Decision 5: Network Configuration

**Options for local development:**
| Method | Use Case |
|--------|----------|
| Simulator + localhost | Simplest - iOS Simulator can hit localhost |
| Physical device + ngrok | Required for real device testing |
| Physical device + local IP | Works on same WiFi, but requires config |

**Recommendation:** Support both
- Default to localhost for simulator
- Allow configurable API URL for ngrok/local IP

---

## Data Flow

### Stage 1: Layering (Discovery)

```
┌─────────────────────────────────────────────────────────────────┐
│  Input: Max range (10 years back from today)                    │
│                                                                  │
│  1. Query aggregated step count for range                       │
│  2. If count == 0:                                              │
│     - Mark as "checked, empty" → skip                           │
│  3. If count > 0 AND count > 10,000:                            │
│     - Divide into 2 sub-intervals (binary)                      │
│     - Recursively check each sub-interval                       │
│  4. If count > 0 AND count <= 10,000:                           │
│     - Add interval to "ready to fetch" list                     │
│                                                                  │
│  Output: [DateInterval] - intervals to fetch (each ≤10k steps)  │
│          + tracked empty intervals (for resume)                 │
└─────────────────────────────────────────────────────────────────┘
```

**Visualization (binary tree, 10k threshold):**
```
                    [10 years: 2M steps]
                   /                    \
          [5 years: 800k]          [5 years: 1.2M]
           /          \                /        \
      [2.5y: 300k]  [2.5y: 500k]   [2.5y: 0]  [2.5y: 1.2M]
         ...          ...          (empty)       ...
                                   skip!
                      │
              ... continue until ≤10k ...
                      │
              [intervals ≤10k steps each]
```

### Stage 2: Storing (Fetch → SwiftData → API)

**Stage 2a: Fetch to SwiftData**
```
┌─────────────────────────────────────────────────────────────────┐
│  For each interval from Stage 1 (sequentially):                 │
│                                                                  │
│  1. Query RAW HKQuantitySamples for interval                    │
│  2. Transform to StepSample models                              │
│  3. Batch upsert to SwiftData (1000 at a time, synced=false)    │
│     - Upsert: if UUID exists, update; else insert               │
│  4. Mark interval as "fetched"                                  │
│  5. Continue to next interval                                   │
│                                                                  │
│  User can PAUSE here → resume continues from unfetched intervals│
└─────────────────────────────────────────────────────────────────┘
```

**Stage 2b: Sync to API (runs AFTER 2a completes)**
```
┌─────────────────────────────────────────────────────────────────┐
│  Loop until all synced:                                         │
│                                                                  │
│  1. Query SwiftData: WHERE synced == false LIMIT 1000           │
│  2. POST batch to API                                           │
│  3. On success: UPDATE synced = true for those records          │
│  4. On failure: log error, continue (will retry next loop)      │
│  5. Repeat until no unsynced records remain                     │
│                                                                  │
│  User can PAUSE here → resume queries unsynced and continues    │
└─────────────────────────────────────────────────────────────────┘
```

**Memory flow:**
```
HealthKit ──► [1000 samples] ──► SwiftData (disk)
                                     │
                    (after all fetched)
                                     │
                                     ▼
                          [Query 1000 unsynced]
                                     │
                                     ▼
                            API POST /steps
                                     │
                                     ▼
                          UPDATE synced=true
                                     │
                                     ▼
                          [Repeat until done]
```

---

## API Specification

### POST /steps

**Request:**
```json
{
  "samples": [
    {
      "id": "uuid-string",
      "startDate": "2024-01-15T10:30:00Z",
      "endDate": "2024-01-15T10:31:00Z",
      "count": 45,
      "sourceBundleId": "com.apple.health",
      "sourceDeviceName": "iPhone 15 Pro"
    }
  ]
}
```

**Response (200):**
```json
{
  "saved": 1,
  "message": "Success"
}
```

**Response (400):**
```json
{
  "error": "Invalid request body"
}
```

### GET /health

**Response (200):**
```json
{
  "status": "ok"
}
```

---

## JSONL File Format

Each line is a complete JSON object:

```jsonl
{"id":"abc-123","startDate":"2024-01-15T10:30:00Z","endDate":"2024-01-15T10:31:00Z","count":45,"sourceBundleId":"com.apple.health","sourceDeviceName":"iPhone 15 Pro","receivedAt":"2024-01-20T15:00:00Z"}
{"id":"def-456","startDate":"2024-01-15T10:31:00Z","endDate":"2024-01-15T10:32:00Z","count":52,"sourceBundleId":"com.apple.health","sourceDeviceName":"iPhone 15 Pro","receivedAt":"2024-01-20T15:00:00Z"}
```

---

## Assumptions & Scope Limitations

### Documented Assumptions:

1. **Single user**: No authentication/multi-user support needed
2. **Trusted network**: API runs locally, no HTTPS required for mock
3. **SwiftData handles 10GB+**: Assumption that SwiftData can handle large datasets efficiently with proper batching
4. **HealthKit aggregated queries are fast**: Layering depends on cheap aggregate queries
5. **No real-time sync**: Focus on historical bulk upload, not continuous sync
6. **Step data only**: Not syncing other HealthKit data types
7. **No data deletion**: API only appends, never deletes
8. **UTC timestamps**: All dates stored in ISO 8601 UTC format
9. **UUID uniqueness**: HealthKit sample UUIDs are globally unique and stable

### Risks & Concerns:

| Risk | Mitigation |
|------|------------|
| SwiftData performance at 10GB | Need to test batch sizes, may need SQLite directly |
| Layering queries still too many | May need caching or adjust division factor |
| Memory pressure during fetch | Strict batch limits, autoreleasepool usage |
| API bottleneck during parallel sync | Rate limiting, batch size tuning |

### Out of Scope:

- Background sync / push notifications
- Real-time streaming updates
- User authentication
- Data encryption at rest
- Production-grade error handling
- Unit/integration tests (for this MVP)
- Incremental sync (detecting new data since last sync)
- Conflict resolution (same record modified in HealthKit)

---

## Development Phases

### Phase 1: Project Setup
- Create Xcode project with HealthKit capability
- Set up SwiftData container with StepSample + SyncInterval models
- Set up FastAPI server with /health endpoint
- Verify connectivity (simulator → localhost)

### Phase 2: Stage 1 - Layering Service
- Implement HealthKitManager (aggregated queries)
- Implement LayeringService binary subdivision algorithm
- Save SyncInterval records to SwiftData
- Test with real HealthKit data
- Output: working interval discovery with pause/resume

### Phase 3: Stage 2a - Fetch Service
- Implement raw sample queries in HealthKitManager
- Implement FetchService (pending intervals → raw samples → SwiftData)
- Batch upsert with 1000 samples at a time
- Update interval status to "fetched"
- Test batch insert performance

### Phase 4: Stage 2b - API Sync Service
- Implement POST /steps endpoint with JSONL persistence
- Implement APISyncService (query unsynced → POST → mark synced)
- Test sync flow end-to-end

### Phase 5: Integration & UI
- Wire up all stages sequentially
- Add progress reporting to UI (intervals found, samples fetched, samples synced)
- Implement Pause/Continue functionality
- Handle errors gracefully

### Phase 6: Polish
- Clean up UI
- Write README with setup instructions
- Test on physical device (if available)
- Document final assumptions

---

## Required iOS Permissions

### Info.plist keys:
```xml
<key>NSHealthShareUsageDescription</key>
<string>This app reads your step count data to sync it with your personal server.</string>
```

### Entitlements:
```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.background-delivery</key>
<false/>
```

---

## Next Steps

After this plan is approved, we will:
1. Implement the iOS app structure
2. Implement the Python/FastAPI mock server
3. Connect the components
4. Test and refine

---

## Finalized Decisions

### Layering Algorithm (Stage 1)

| Decision | Value | Notes |
|----------|-------|-------|
| Division factor | **Binary (2)** | Deeper tree but simpler logic |
| Stop threshold | **≤10,000 steps** | Based on aggregated count, not time |
| Slow layering | Solve if/when encountered | Don't over-optimize prematurely |
| Empty gaps | **Track "checked but empty"** | Enables resumability |

### SwiftData (Stage 2a)

| Decision | Value | Notes |
|----------|-------|-------|
| Batch insert size | **1,000 samples** | Balance memory vs performance |
| Duplicate handling | **UUID as unique key + upsert** | HealthKit UUID is stable; on re-run, update existing record instead of failing |
| Storage | **SwiftData** | Trust it; pivot to SQLite only if problems arise |
| Concurrent access | **Sequential (fetch all → then sync)** | Simpler; can parallelize later if needed |

### API Sync (Stage 2b)

| Decision | Value | Notes |
|----------|-------|-------|
| When to start | **After all fetched** | Sequential for simplicity first |
| Batch size | **1,000 samples** | Match SwiftData batch size |
| Failure handling | **Query unsynced, retry those** | `synced: Bool` flag handles this naturally |
| Rate limiting | **None initially** | Add if API struggles |

### General

| Decision | Value | Notes |
|----------|-------|-------|
| Progress persistence | **SwiftData `synced` flag** | No separate state needed; unsynced records = remaining work |
| Cancellation | **Pause/Continue support** | User can stop; resume picks up unsynced records |
| Memory profiling | **Yes, during development** | Instrument to validate 10GB works |

### Sequential Flow (Simplified)

```
User taps "Sync"
       │
       ▼
┌──────────────────┐
│ Stage 1: Layer   │ ──► Discover intervals with data
└──────────────────┘
       │
       ▼
┌──────────────────┐
│ Stage 2a: Fetch  │ ──► For each interval: fetch raw → SwiftData (synced=false)
└──────────────────┘
       │
       ▼
┌──────────────────┐
│ Stage 2b: Sync   │ ──► Query unsynced → POST to API → set synced=true
└──────────────────┘
       │
       ▼
     Done (or Paused)
```

**Pause/Continue behavior:**
- User taps "Pause" → stop current operation gracefully
- User taps "Continue" → 
  - If Stage 1 incomplete: resume layering (need to track checked intervals)
  - If Stage 2a incomplete: resume fetching remaining intervals
  - If Stage 2b incomplete: query `synced=false`, continue syncing

### Future Parallelization Path

Current: `Fetch all → Sync all` (sequential)

Later (if needed): 
- Start APISyncService after first N batches saved to SwiftData
- Run fetch and sync on separate queues
- **No architectural changes needed** - just change when APISyncService starts

This confirms: starting sequential does NOT block future parallelization.
