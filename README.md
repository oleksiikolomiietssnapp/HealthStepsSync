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

## Implementation Strategy

The app uses a **layering algorithm** to efficiently discover date intervals containing step data. Instead of querying all raw samples at once (which could be millions of data points over 10 years), the algorithm uses aggregated queries to identify smaller time intervals with a manageable number of steps, then fetches raw samples only from those intervals.

The algorithm targets intervals with **≤10,000 steps** (configurable in `LayeringServiceImplementation`). While not perfectly balanced, the approach is effective—occasionally some intervals may exceed the limit by a small percentage, but this is acceptable given the efficiency gains.

Once intervals are discovered, raw step samples are fetched from each interval and sent to the API server in batches. This strategy handles large historical datasets efficiently without overwhelming the device or the API.

## Testing

Basic layering tests exist in `ios/HealthStepsSyncTests/` - verify interval continuity (no gaps/overlaps). Chunk step count validation is not included, as occasional overages (>10K steps) are expected given the current algorithm's approach.

Easy to add: unit tests for fetch and sync services (protocols already abstracted for mocking).

## Observations

### SwiftData Performance

Calling `modelContext.save()` after each update causes UI slowdown and glitches. Using SwiftData's autosave with batching is more efficient for large-scale syncs.

### Layering Algorithm Complexity

The layering algorithm for discovering date intervals is not perfectly balanced. The task turned out more complex than initially expected, particularly in handling edge cases and optimizing query performance. However, the approach is effective and demonstrates the core concept of efficiently chunking large historical datasets.

## Assumptions & Scope Limitations

### Key Scope Limitations

1. **Single user / No authentication** - The app and API run without user authentication. Adding "Sign in with Apple" would be straightforward on the server side, but requires proper Apple Developer Program setup on the iOS side (outside current scope due to time constraints).

2. **Local network only** - API runs on localhost without HTTPS/TLS. This is fine for development/testing but not for production.

3. **Memory optimization** - The app handles large data volumes efficiently with parallel API calls and optimized batch processing. Memory issues discovered during development have been fixed.

4. **Initial full sync only** - First sync fetches all available history; incremental/delta sync (detecting new data since last sync) is not implemented.

### HealthKit Data Source

**Testing on Simulator**: The app includes debug functions to populate the simulator with realistic test data. Run `addRealisticStepDataForPast10Years()` to generate 10 years of step history directly in the simulator's HealthKit store. See `HealthKitStepStatisticsQuery.swift` for debug helper methods.

**Testing on Physical Device**: Requires Apple Developer Program membership (~$99/year) for proper HealthKit entitlements provisioning.

**Mock Data Mode**: An alternative testing mode that generates synthetic step data without accessing HealthKit (useful for development without any device setup).

To switch data sources, modify `ios/HealthStepsSync/App/HealthStepsSyncApp.swift`:
```swift
@Entry var healthKitManager: HealthKitManager = .live()
```

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
