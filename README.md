# iOS Health Steps Sync

An iOS app that reads **raw step count data** from Apple Health and syncs it to a local Python API server. The API persists all synced step data to a `.jsonl` file.

## Project Structure

```
HealthStepsSync/
├── api/                               # Python API server
│   ├── main.py
│   ├── requirements.txt
│   └── data/
│       └── steps.jsonl
├── ios/                               # iOS app (SwiftUI)
│   └── HealthStepsSync/
│       ├── App/
│       ├── Models/
│       ├── Services/
│       ├── Views/
│       └── HealthStepsSync.xcodeproj
├── Planning/                          # Architecture & design docs
├── README.md
└── Task.md
```

## Task Requirements

The assignment requires building:

1. **iOS App** (`ios/` directory)
   - Read raw step samples from Apple Health (not aggregated data)
   - Support full history sync (up to ~10 years back)
   - Implement safe, efficient syncing for large data volumes
   - Send data to the local API server

2. **Python API Server** (`api/` directory)
   - Accept step data from the iOS app
   - Persist data to a `.jsonl` file
   - Provide endpoints for storing and retrieving step data

## System Requirements

- **iOS App**: Xcode 15+, iOS 17.0+
- **API Server**: Python 3.8+

## Setup & Running

### 1. Start the API Server

```bash
cd api
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
python3 main.py
```

The API will be available at `http://localhost:8000`

See [api/README.md](api/README.md) for detailed setup and [api/SCHEMA.md](api/SCHEMA.md) for API documentation.

### 2. Run the iOS App

1. Open `ios/HealthStepsSync.xcodeproj` in Xcode
2. Select target device/simulator
3. Build and run (⌘R)
4. Grant HealthKit permissions when prompted
5. Tap "Sync" to start syncing all available step data
6. Monitor sync progress in the app UI
7. Use the nav bar button to review stored and synced data
8. Check `api/data/steps.jsonl` to verify persisted data

#### Testing on Physical Device (Same WiFi)

For physical device testing, update the Mac IP address in the endpoint configuration:

**File**: `ios/HealthStepsSync/Services/Network/Endpoint.swift` (line 24)

```swift
#else
    static var baseURL: String = "http://192.168.0.200:8000"  // Update to your Mac's IP
#endif
```

Find your Mac's IP:
```bash
ifconfig | grep -E "inet " | grep -v 127.0.0.1
```

The app automatically uses `localhost` for simulator builds and your Mac's IP for physical device builds.

## Demo Video

[Demo video - showing complete workflow]

The demo shows:
1. **Install & Setup** - Launch app, accept HealthKit sharing permissions
2. **Generate Test Data** - Add 10 years of realistic step history to simulator
3. **Layering Stage** (~2 seconds) - Discover all date intervals with step data
4. **Review Chunks** - Display stored `SyncInterval` records with sync status
5. **Sync Stage** (~5-6 seconds total) - Send raw step samples to API
6. **Pause & Resume** - Pause sync mid-process, close app, relaunch to verify state is preserved
7. **Resume Sync** - Continue syncing remaining intervals from paused state
8. **Final Verification** - Check synced data in app UI and `api/data/steps.jsonl`

## Architecture

The app follows a layered architecture with clear separation of concerns:

**Services** (business logic):
- `LayeringServiceImplementation` - discovers date intervals with step data
- `SyncServiceImplementation` - syncs individual intervals to the API
- `HealthKitStepDataSource` - HealthKit queries (aggregated buckets and raw samples)
- `NetworkService` (URLSessionNetworkService) - HTTP requests to the API
- `LocalStorageProvider` (SwiftDataStorageProvider) - persists interval state

**View Models**:
- `ContentViewModel` - orchestrates layering and sync workflows, manages UI state, handles concurrency (TaskGroup)
- `SyncedStepsViewModel` - fetches and displays synced data from the server

**Navigation**:
- `NavigationStack` for root navigation structure
- `NavigationLink` for navigating to detail views (Stored Chunks, Synced Steps)
- Each module (Main, StoredChunks, SyncedSteps, Admin) is self-contained

**Dependency Injection**:
- `@Entry` (Swift 6.2) in `EnvironmentValues+Entries.swift` provides:
  - `healthKitDataSource: HealthKitStepDataSource = .live()`
  - `networkService: NetworkService = .live`
- Services are initialized in `HealthStepsSyncApp` and passed to views
- Enables easy testing by swapping implementations

## Implementation Strategy

### Layering Algorithm
The app uses a **layering algorithm** to efficiently discover date intervals containing step data. Instead of querying all raw samples at once (which could be millions of data points over 10 years), the algorithm uses aggregated queries to identify smaller time intervals with a manageable number of steps, then fetches raw samples only from those intervals.

The algorithm targets intervals with **≤10,000 steps** (configurable in `LayeringServiceImplementation`). It produces well-balanced chunks while delivering fast sync performance.

### Syncing & Batching

Once intervals are discovered, `SyncServiceImplementation` handles each interval as follows:

**Per Interval** (single `sync()` call):
1. **Fetch raw samples**: `getRawStepSamples()` retrieves all individual step samples from HealthKit for that interval
2. **Convert to API format**: Raw samples are transformed into `APIStepSample` objects (UUID, start/end dates in ISO 8601, step count, source device)
3. **Send to server**: All samples from the interval are wrapped in a `PostStepsRequest` and sent in a single POST request to `/steps`
4. **Mark as synced**: After successful API response, the interval's `syncedToServer` flag is updated in storage

**Concurrency**:
- Up to 3 intervals sync in parallel (configurable via `maxConcurrentSyncs` in ContentViewModel)
- Uses `TaskGroup` with an iterator pattern: as each interval completes, the next one starts
- Maintains responsive UI and efficient resource use without overwhelming the network

Example of a single step sample stored in `api/data/steps.jsonl`:
```json
{"sourceDeviceName": "iPhone", "uuid": "D67311EE-FACB-41AA-B202-8D266F3EDE18", "startDate": "2025-05-11T16:27:22.000Z", "endDate": "2025-05-11T16:29:03.000Z", "count": 6176, "sourceBundleId": "com.kolomiiets.HealthStepsSync"}
```

### Review Data

The app provides two screens to review progress:

**Stored Chunks** (local SwiftData):
- Displays all `SyncInterval` records discovered and stored locally
- Shows: date range, step count, and sync status for each chunk
- Includes trash button to delete all local chunks and clear server data via DELETE `/steps`

**Synced Steps** (server data):
- Fetches and displays all raw step samples successfully synced to the server (via GET `/steps`)
- Shows: start/end dates, step count, source device for each sample
- Refresh button to reload data from server
- Helpful for verifying data persistence and checking server state

### Pause & Resume
The sync operation supports pause/resume:
- **Pause**: Cancels in-flight requests; current interval sync is aborted
- **Resume**: Continues with remaining unsynchronized intervals (previous ones are marked as synced)
- **State tracking**: Each interval tracks sync status in local SwiftData storage

### Network Failure Handling
- Network errors propagate to the UI as sync failures
- User can retry manually by tapping the sync button again
- **Note**: There is no automatic retry logic or crash recovery—in-flight requests are lost if the app terminates

## Testing

Basic layering tests exist in `ios/HealthStepsSyncTests/` - verify interval continuity (no gaps/overlaps) and chunk balance.

Easy to add: unit tests for fetch and sync services (protocols already abstracted for mocking).

## Observations

### SwiftData Performance

Calling `modelContext.save()` after each update causes UI slowdown and glitches. Using SwiftData's autosave with batching is more efficient for large-scale syncs.

### Layering Algorithm

The layering algorithm efficiently discovers date intervals by balancing query performance with chunk size constraints. It handles large historical datasets effectively through aggregated queries and intelligent interval subdivision.

## Assumptions & Scope Limitations

### Key Scope Limitations

1. **Single user / No authentication** - The app and API run without user authentication. Adding "Sign in with Apple" would be straightforward on the server side, but requires proper Apple Developer Program setup on the iOS side (outside current scope due to time constraints).

2. **Local network only** - API runs on localhost without HTTPS/TLS. For physical device testing on the same WiFi, update `Endpoint.swift` line 24 with your Mac's IP (see "Testing on Physical Device" above). Not suitable for production.

3. **Memory optimization** - The app handles large data volumes efficiently with parallel API calls and optimized batch processing. Memory issues discovered during development have been fixed.

4. **Initial full sync only** - First sync fetches all available history; incremental/delta sync (detecting new data since last sync) is not implemented.

5. **No automatic retry or crash recovery** - Network failures surface to the UI; user can retry manually. If app crashes mid-sync, in-flight requests are lost.

6. **No deduplication** - API appends all samples without checking for duplicates. Syncing the same interval multiple times will store duplicate samples.

### HealthKit Data Source

The app uses `HealthKitStepDataSource` to interact with HealthKit through the `StepDataSource` protocol:

**Layering Stage** (discovering intervals):
- Uses `fetchStepBuckets()` - performs aggregated queries with `HKStatisticsCollectionQuery`
- Returns bucketed step counts (e.g., 15-minute intervals) to identify dense date ranges
- Efficient for scanning large historical periods without fetching individual samples

**Sync Stage** (fetching raw samples):
- Uses `getRawStepSamples()` - performs raw sample queries with `HKSampleQuery`
- Returns individual step samples from pre-identified intervals
- Fetches only from intervals discovered during layering (avoids querying all 10 years of raw data at once)

**Testing on Simulator**: The app includes debug functions to populate the simulator with realistic test data. Run `addRealisticStepDataForPast10Years()` to generate 10 years of step history directly in the simulator's HealthKit store. See `HealthKitStepStatisticsQuery.swift` for debug helper methods.

**Testing on Physical Device**: Requires Apple Developer Program membership for proper HealthKit entitlements provisioning.

### Storage & State Tracking

The app uses SwiftData to persist `SyncInterval` records locally, tracking which date intervals have been synced to the server:

**Layering Phase** (Stage 1):
- `LocalStorageProvider.insertInterval()` creates new `SyncInterval` records with `syncedToServer = false`
- Each interval stores: start date, end date, step count, and sync status
- After all intervals are discovered, they're persisted to SwiftData

**Sync Phase** (Stage 2):
- `LocalStorageProvider.updateSyncedToServer()` marks intervals as `syncedToServer = true` after their raw step samples are successfully sent to the API
- Updates are batched for efficiency: flushes after 42 synced intervals, plus a delayed flush with 1-second timeout
- Uses background context to avoid blocking the main thread during bulk updates
- Resume functionality: only remaining unsynchronized intervals are re-fetched on app restart

This two-phase approach allows the app to discover all intervals first, then progressively sync them without re-querying HealthKit for already-discovered data.

## Future Improvements

These features would enhance the app but are not currently implemented:

- **Background sync** - Sync step data automatically when the app is closed or in the background. Would require background task framework and push notifications to notify users of sync completion.

- **Real-time streaming updates** - Currently syncs periodically, but updates should be more user-friendly. Could use live progress indicators, live activities (lock screen/Dynamic Island), or notification-based feedback as data arrives.

- **Data encryption** - Since step count data is considered health information, it should be encrypted in transit (HTTPS) and optionally at rest on both client and server. Currently unencrypted for local development.

- **Incremental sync** - Detect and sync only new step data added since the last sync, rather than re-syncing the entire history each time. This is the natural next step for improving efficiency.

- **Duplicate and conflict handling** - Currently the server appends all received samples. Should implement logic to detect duplicate samples (same source, same timestamp, same step count) and handle conflicts when the same interval is synced multiple times. Server-side deduplication would be the simplest approach.

## Troubleshooting

**API connection issues**:
- Ensure API server is running on localhost:8000
- Check app logs in Xcode console for connection errors
- Verify firewall isn't blocking port 8000

## Planning & Architecture

Detailed planning documents are in the `Planning/` folder:

- **[01-project-architecture.md](Planning/01-project-architecture.md)** - Overall system design and data flow
- **[02-healthkit-service.md](Planning/02-healthkit-service.md)** - HealthKit integration architecture
- **[03-layering-algorithm.md](Planning/03-layering-algorithm.md)** - Layering algorithm specification
- **[04-layering-implementation.md](Planning/04-layering-implementation.md)** - Implementation notes and verification
- **[04-layering-implementation-summary.md](Planning/04-layering-implementation-summary.md)** - Summary of completed tasks
- **[05-sync-service.md](Planning/05-sync-service.md)** - API sync service design

## AI Disclosure

This project was developed with AI assistance (Claude) for planning, architecture design, and code generation.
