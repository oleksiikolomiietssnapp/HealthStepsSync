# iOS Health Steps Sync

A small iOS app that reads raw step count data from Apple Health and syncs it to a local mock API.

## Overview

This project demonstrates efficient syncing of potentially large HealthKit datasets (up to 10 years of history, ~10GB) using a two-stage approach:

1. **Layering Stage** - Discovers date intervals containing step data using cheap aggregated queries
2. **Storing Stage** - Fetches raw samples to SwiftData, then syncs to API

## Project Structure

```
ios-health-steps-sync/
├── README.md
├── ios/
│   └── HealthStepsSync/
│       ├── Models/
│       │   ├── StepSample.swift          # SwiftData model for step data
│       │   └── SyncInterval.swift        # Progress tracking model
│       ├── Services/
│       │   ├── HealthKitManager.swift    # HealthKit queries
│       │   ├── LayeringService.swift     # Interval discovery
│       │   ├── FetchService.swift        # HealthKit → SwiftData
│       │   └── APISyncService.swift      # SwiftData → API
│       └── Views/
│           └── ContentView.swift
└── api/
    ├── main.py                           # FastAPI server
    ├── requirements.txt
    └── data/
        └── steps.jsonl                   # Persisted step data
```

## Requirements

### iOS App
- Xcode 15+
- iOS 17.0+
- Physical device with Apple Health data (recommended)

### Mock API
- Python 3.9+
- pip

## Setup & Running

### 1. Start the Mock API

```bash
cd api

# Create virtual environment (optional but recommended)
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run the server
uvicorn main:app --host 0.0.0.0 --port 8000
```

The API will be available at `http://localhost:8000`

### 2. Configure Network Access

**For iOS Simulator:**
- Use `http://localhost:8000` directly (Simulator shares host network)

**For Physical Device:**

Option A - ngrok (recommended):
```bash
ngrok http 8000
```
Then use the ngrok URL (e.g., `https://abc123.ngrok.io`) in the app.

Option B - Local IP:
- Find your Mac's IP: `ifconfig | grep "inet " | grep -v 127.0.0.1`
- Use `http://<your-ip>:8000`
- Ensure device is on same WiFi network

### 3. Run the iOS App

1. Open `ios/HealthStepsSync.xcodeproj` in Xcode
2. Select your target device
3. Update API URL in app settings if not using localhost
4. Build and run (⌘R)
5. Grant HealthKit permissions when prompted
6. Tap "Start Sync"

## API Endpoints

### POST /steps
Receive batch of step samples.

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

### GET /health
Health check endpoint.

**Response (200):**
```json
{
  "status": "ok"
}
```

## Architecture

### Two-Stage Sync

```
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 1: LAYERING                                              │
│  - Binary subdivision of 10-year range                          │
│  - Query aggregated step counts                                 │
│  - Stop when interval ≤ 10,000 steps                            │
│  - Skip empty intervals                                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 2a: FETCH                                                │
│  - Query raw HKQuantitySamples per interval                     │
│  - Batch upsert to SwiftData (1000 at a time)                   │
│  - Mark records with synced=false                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 2b: SYNC                                                 │
│  - Query unsynced records from SwiftData                        │
│  - POST to API in batches of 1000                               │
│  - Update synced=true on success                                │
└─────────────────────────────────────────────────────────────────┘
```

### Why This Approach?

- **Memory Safe**: Never holds 10GB in memory; streams through SwiftData
- **Resumable**: Pause anytime; continue picks up where it left off
- **Efficient**: Skips empty date ranges using cheap aggregated queries
- **Idempotent**: UUID-based upsert prevents duplicates on re-run

## Testing Without HealthKit Access

### Limitation

HealthKit authorization has restrictions:
- **Simulator**: Returns denied/empty results for step data
- **Physical Device**: Requires paid Apple Developer account for HealthKit entitlement

### Mock Mode

The app includes a mock mode for testing the sync logic without real HealthKit data:

```swift
// In HealthKitManager.swift, set:
let useMockData = true
```

This generates fake step samples for testing the full pipeline:
- Layering algorithm
- SwiftData persistence
- API sync flow
- Pause/Continue functionality

### Mock Data Characteristics

| Parameter | Value |
|-----------|-------|
| Date range | 2 years of history |
| Samples per day | 50-200 (randomized) |
| Steps per sample | 10-500 (randomized) |
| Total samples | ~50,000-150,000 |

## Assumptions & Limitations

### Assumptions

1. **Single user** - No authentication required
2. **Trusted network** - API runs locally, no HTTPS
3. **Step data only** - Not syncing other HealthKit types
4. **UTC timestamps** - All dates in ISO 8601 format
5. **HealthKit UUID stability** - UUIDs don't change for existing samples

### Out of Scope

- Background sync / push notifications
- Real-time streaming updates
- User authentication
- Data encryption
- Production error handling
- Incremental sync (detecting new data since last sync)

## Data Storage

### iOS (SwiftData)

Two models:
- `StepSample` - Individual step records with `synced: Bool` flag
- `SyncInterval` - Tracks layering progress for pause/resume

### API (JSONL)

Appends to `data/steps.jsonl`:
```jsonl
{"id":"abc-123","startDate":"2024-01-15T10:30:00Z","endDate":"2024-01-15T10:31:00Z","count":45,"sourceBundleId":"com.apple.health","sourceDeviceName":"iPhone 15 Pro","receivedAt":"2024-01-20T15:00:00Z"}
```

## Troubleshooting

### "HealthKit not available"
- HealthKit requires iOS device or Simulator
- Not available on iPad (without Apple Silicon) or Mac Catalyst

### Empty results from HealthKit
- User may have denied permission (check Settings > Privacy > Health)
- No step data in requested date range
- Try mock mode to test sync logic

### API connection failed
- Verify API is running: `curl http://localhost:8000/health`
- For physical device: ensure correct URL (ngrok or local IP)
- Check firewall settings

### Sync stuck / slow
- Large datasets take time; check progress indicators
- Can pause and resume anytime
- Check Console.app for detailed logs

## License

MIT

## AI Disclosure

This project was developed with AI assistance (Claude) for planning and code generation.
