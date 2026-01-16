# iOS Health Steps Sync

A prototype iOS app demonstrating an efficient layering algorithm for discovering step count data from Apple Health, with a complementary Python API server for syncing step data. Currently implements Stage 1: the layering algorithm discovers date intervals with step data using aggregated queries and stores them to SwiftData. (Stage 2 fetching/API sync is planned but not yet implemented in the UI.)

## Requirements

- **iOS App**: Xcode 15+, iOS 17.0+

## Current Implementation Status

✅ **Implemented:**
- Stage 1: Layering algorithm (discovers date intervals with ≤10,000 steps)
- Mock HealthKit data generation (2+ years of realistic step data)
- SwiftData storage of discovered intervals
- Basic UI showing layering results
- Python API server with step data storage and retrieval endpoints

🚧 **Planned (not yet implemented):**
- Stage 2a: Fetching raw step samples from discovered intervals
- Stage 2b: API synchronization from iOS app
- Settings UI for API configuration
- Complete end-to-end sync workflow

## Setup & Running

1. Open `ios/HealthStepsSync.xcodeproj` in Xcode
2. Select your target device or simulator
3. Build and run (⌘R)
4. Tap "Chunk" to run the layering algorithm
5. View discovered intervals and timing results

## API Server

A Python Flask API server is available in the `api/` folder for storing and retrieving step data.

See [api/README.md](api/README.md) for setup instructions and [api/SCHEMA.md](api/SCHEMA.md) for detailed API documentation.

## What to Expect

When you run the app, you'll see:
1. A "Chunk" button to start the layering algorithm
2. Processing time display showing how long layering takes
3. Count of discovered intervals (chunks) with ≤10,000 steps each
4. Intervals are stored to SwiftData for future use

The app currently demonstrates the layering discovery algorithm. Raw sample fetching and API sync are planned for future implementation.

## Assumptions & Limitations

### Assumptions

1. **Single user** - No authentication required
2. **Trusted network** - API runs locally, no HTTPS
3. **Step data only** - Not syncing other HealthKit types
4. **UTC timestamps** - All dates in ISO 8601 format
5. **HealthKit UUID stability** - UUIDs don't change for existing samples

### HealthKit Data Source

**Currently using MOCK data** - The app is configured to use generated mock HealthKit data by default.

**Why?** Testing with real HealthKit data on a physical device requires:
- Paid Apple Developer Program membership (~$99/year)
- Proper HealthKit entitlements provisioning
- Physical iOS device (Simulator has HealthKit API limitations)

**Mock data characteristics:**
- 2+ years of step count history
- 50-200 samples per day with realistic variation
- 3,000-30,000 daily steps
- Tests the complete sync pipeline without real Health data
- No permission prompts (permissions are auto-approved in mock mode)

**To use real HealthKit data:**
If you have an Apple Developer Program account, switch to real data by changing line 47 in `ios/HealthStepsSync/App/HealthStepsSyncApp.swift`:
```swift
@Entry var healthKitManager: HealthKitManager = .live()  // Change from .mock()
```

### Out of Scope

- Background sync / push notifications
- Real-time streaming updates
- User authentication
- Data encryption
- Production error handling
- Incremental sync (detecting new data since last sync)

## Troubleshooting

**No data showing after tapping "Chunk"**: The app uses mock data by default. Check Xcode console for errors.

**HealthKit permissions**: Only needed when using `.live()` mode (not the default mock). Go to Settings > Privacy > Health and enable step data access. Note: Live mode also requires Apple Developer Program membership for proper provisioning.

## AI Disclosure

This project was developed with AI assistance (Claude) for planning and code generation.
