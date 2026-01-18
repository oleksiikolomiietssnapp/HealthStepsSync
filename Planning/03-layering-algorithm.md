# LayeringService Implementation Plan

## Overview

LayeringService discovers date intervals containing step data by recursively dividing the date range until each chunk has ≤10,000 steps. Results are stored as `SyncInterval` records in SwiftData.

**Important**: Read this entire document before implementing. Do not improvise - follow the specifications exactly.

---

## Prerequisites

Before implementing, ensure these exist:
- `StepDataProvider` protocol in `Services/HealthKit/StepDataProvider.swift`
- `HealthKitManager` that conforms to `StepDataProvider`
- SwiftData configured in the app

---

## Task 1: Create SyncInterval Model

**File**: `ios/HealthStepsSync/Models/SyncInterval.swift`

```swift
import Foundation
import SwiftData

@Model
final class SyncInterval {
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var endDate: Date
    var stepCount: Int
    var syncedToServer: Bool
    
    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        stepCount: Int,
        syncedToServer: Bool = false
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.stepCount = stepCount
        self.syncedToServer = syncedToServer
    }
}
```

**Requirements**:
- `@Attribute(.unique)` on `id` to prevent duplicates
- `syncedToServer` defaults to `false`
- All properties must be non-optional

---

## Task 2: Create LayeringService Protocol

**File**: `ios/HealthStepsSync/Services/Layering/LayeringServiceProtocol.swift`

```swift
import Foundation

@MainActor
protocol LayeringServiceProtocol {
    /// Performs layering: discovers intervals with ≤10,000 steps each
    /// Stores results in SwiftData
    /// - Returns: Number of intervals created
    func performLayering() async throws -> Int
    
    /// Deletes all existing SyncInterval records (for restart)
    func clearAllIntervals() async throws
}
```

---

## Task 3: Create LayeringService Implementation

**File**: `ios/HealthStepsSync/Services/Layering/LayeringService.swift`

### 3.1 Class Structure

```swift
import Foundation
import SwiftData

@MainActor
final class LayeringService: LayeringServiceProtocol {
    
    // MARK: - Constants
    private let maxStepsPerInterval = 10_000
    private let maxYearsBack = 10
    
    // MARK: - Dependencies
    private let stepDataProvider: StepDataProvider
    private let modelContext: ModelContext
    
    // MARK: - Init
    init(stepDataProvider: StepDataProvider, modelContext: ModelContext) {
        self.stepDataProvider = stepDataProvider
        self.modelContext = modelContext
    }
}
```

### 3.2 Public Methods

#### performLayering()

```swift
func performLayering() async throws -> Int {
    // 1. Clear existing intervals (start fresh per v1 requirements)
    try await clearAllIntervals()
    
    // 2. Define max range: 10 years ago to now
    let endDate = Date()
    let startDate = Calendar.current.date(byAdding: .year, value: -maxYearsBack, to: endDate)!
    
    // 3. Check if any data exists in full range
    let fullInterval = DateInterval(start: startDate, end: endDate)
    let totalSteps = try await stepDataProvider.getAggregatedStepCount(for: fullInterval)
    
    if totalSteps == 0 {
        // No data at all - create single empty interval
        let interval = SyncInterval(
            startDate: startDate,
            endDate: endDate,
            stepCount: 0
        )
        modelContext.insert(interval)
        try modelContext.save()
        return 1
    }
    
    // 4. Find actual data boundaries (optimization)
    let actualStart = try await findDataStart(in: fullInterval)
    let actualEnd = try await findDataEnd(in: fullInterval)
    let actualInterval = DateInterval(start: actualStart, end: actualEnd)
    
    // 5. Perform recursive layering
    var intervals: [SyncInterval] = []
    try await divideInterval(actualInterval, into: &intervals)
    
    // 6. Save all intervals to SwiftData
    for interval in intervals {
        modelContext.insert(interval)
    }
    try modelContext.save()
    
    return intervals.count
}
```

#### clearAllIntervals()

```swift
func clearAllIntervals() async throws {
    try modelContext.delete(model: SyncInterval.self)
    try modelContext.save()
}
```

### 3.3 Private Methods

#### divideInterval() - Core Recursive Logic

```swift
private func divideInterval(
    _ interval: DateInterval,
    into results: inout [SyncInterval]
) async throws {
    
    // Query aggregated step count for this interval
    let stepCount = try await stepDataProvider.getAggregatedStepCount(for: interval)
    
    // BASE CASE: If steps ≤ threshold OR interval is very small, store it
    if stepCount <= maxStepsPerInterval {
        let syncInterval = SyncInterval(
            startDate: interval.start,
            endDate: interval.end,
            stepCount: stepCount
        )
        results.append(syncInterval)
        return
    }
    
    // RECURSIVE CASE: Divide in half
    let midPoint = Date(
        timeIntervalSince1970: (interval.start.timeIntervalSince1970 + interval.end.timeIntervalSince1970) / 2
    )
    
    let firstHalf = DateInterval(start: interval.start, end: midPoint)
    let secondHalf = DateInterval(start: midPoint, end: interval.end)
    
    // Recurse on both halves
    try await divideInterval(firstHalf, into: &results)
    try await divideInterval(secondHalf, into: &results)
}
```

#### findDataStart() - Binary Search for First Data

```swift
private func findDataStart(in interval: DateInterval) async throws -> Date {
    var low = interval.start
    var high = interval.end
    
    // Binary search to find earliest date with data
    while high.timeIntervalSince(low) > 86400 { // Stop when within 1 day
        let mid = Date(
            timeIntervalSince1970: (low.timeIntervalSince1970 + high.timeIntervalSince1970) / 2
        )
        
        let firstHalf = DateInterval(start: low, end: mid)
        let stepsInFirstHalf = try await stepDataProvider.getAggregatedStepCount(for: firstHalf)
        
        if stepsInFirstHalf > 0 {
            // Data exists in first half, search there
            high = mid
        } else {
            // No data in first half, search second half
            low = mid
        }
    }
    
    return low
}
```

#### findDataEnd() - Binary Search for Last Data

```swift
private func findDataEnd(in interval: DateInterval) async throws -> Date {
    var low = interval.start
    var high = interval.end
    
    // Binary search to find latest date with data
    while high.timeIntervalSince(low) > 86400 { // Stop when within 1 day
        let mid = Date(
            timeIntervalSince1970: (low.timeIntervalSince1970 + high.timeIntervalSince1970) / 2
        )
        
        let secondHalf = DateInterval(start: mid, end: high)
        let stepsInSecondHalf = try await stepDataProvider.getAggregatedStepCount(for: secondHalf)
        
        if stepsInSecondHalf > 0 {
            // Data exists in second half, search there
            low = mid
        } else {
            // No data in second half, search first half
            high = mid
        }
    }
    
    return high
}
```

---

## Task 4: Create LayeringError Enum

**File**: `ios/HealthStepsSync/Services/Layering/LayeringError.swift`

```swift
import Foundation

enum LayeringError: Error, LocalizedError {
    case noDataAvailable
    case healthKitError(underlying: Error)
    case persistenceError(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .noDataAvailable:
            return "No step data available in HealthKit"
        case .healthKitError(let error):
            return "HealthKit error: \(error.localizedDescription)"
        case .persistenceError(let error):
            return "Failed to save intervals: \(error.localizedDescription)"
        }
    }
}
```

---

## Task 5: Add Progress Reporting (Optional Enhancement)

If progress reporting is desired, add a callback:

```swift
@MainActor
final class LayeringService: LayeringServiceProtocol {
    
    // Add progress callback
    var onProgress: ((LayeringProgress) -> Void)?
    
    struct LayeringProgress {
        let intervalsFound: Int
        let currentDepth: Int
        let status: String
    }
    
    // Update divideInterval to report progress
    private func divideInterval(
        _ interval: DateInterval,
        into results: inout [SyncInterval],
        depth: Int = 0
    ) async throws {
        
        // Report progress
        onProgress?(LayeringProgress(
            intervalsFound: results.count,
            currentDepth: depth,
            status: "Checking interval..."
        ))
        
        // ... rest of implementation
    }
}
```

---

## File Structure

After implementation, you should have:

```
ios/HealthStepsSync/
├── Models/
│   └── SyncInterval.swift                    # NEW
├── Services/
│   ├── HealthKit/
│   │   ├── StepDataProvider.swift            # EXISTS
│   │   ├── HealthKitManager.swift            # EXISTS
│   │   └── ...
│   └── Layering/
│       ├── LayeringServiceProtocol.swift     # NEW
│       ├── LayeringService.swift             # NEW
│       └── LayeringError.swift               # NEW
```

---

## Task 6: Register SyncInterval in SwiftData Container

**Update**: `ios/HealthStepsSync/App/HealthStepsSyncApp.swift`

Ensure `SyncInterval` is registered in the model container:

```swift
import SwiftUI
import SwiftData

@main
struct HealthStepsSyncApp: App {
    let modelContainer: ModelContainer
    
    init() {
        do {
            let schema = Schema([
                SyncInterval.self
                // Add other models here
            ])
            let modelConfiguration = ModelConfiguration(schema: schema)
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
```

---

## Task 7: Usage Example

For reference, here's how LayeringService will be used:

```swift
// In a ViewModel or View
@MainActor
class SyncViewModel: ObservableObject {
    @Published var intervalCount: Int = 0
    @Published var isLayering: Bool = false
    @Published var error: String?
    
    private var layeringService: LayeringService?
    
    func startLayering(
        stepDataProvider: StepDataProvider,
        modelContext: ModelContext
    ) async {
        isLayering = true
        error = nil
        
        let service = LayeringService(
            stepDataProvider: stepDataProvider,
            modelContext: modelContext
        )
        
        do {
            let count = try await service.performLayering()
            intervalCount = count
        } catch {
            self.error = error.localizedDescription
        }
        
        isLayering = false
    }
}
```

---

## Algorithm Visualization

```
Input: 10 years, 500,000 total steps

                    [10 years: 500,000 steps]
                    (> 10,000, divide)
                   /                        \
        [5 years: 200,000]            [5 years: 300,000]
        (> 10,000, divide)            (> 10,000, divide)
           /        \                    /          \
    [2.5y: 80,000] [2.5y: 120,000]  [2.5y: 150,000] [2.5y: 150,000]
         ...           ...              ...             ...
                       │
           (continue until ≤ 10,000)
                       │
                       ▼
    Final: Array of ~50-100 SyncInterval records
           Each with stepCount ≤ 10,000
           Covering entire data range
           Empty periods stored with stepCount = 0
```

---

## Testing Checklist

After implementation, verify:

- [ ] `SyncInterval` model compiles and is registered in SwiftData
- [ ] `LayeringService` can be instantiated with mock provider
- [ ] Empty data range creates single interval with `stepCount = 0`
- [ ] Data range with < 10,000 steps creates single interval
- [ ] Data range with > 10,000 steps creates multiple intervals
- [ ] All intervals have `syncedToServer = false`
- [ ] No gaps between intervals (complete coverage)
- [ ] `clearAllIntervals()` removes all records

---

## Important Notes for Implementation

1. **Do not modify** existing HealthKit files
2. **Use exact method signatures** as specified
3. **Binary division**: Always split at midpoint by time, not by step count
4. **Empty intervals**: Store them (stepCount = 0), don't skip
5. **@MainActor**: Required on LayeringService for SwiftData access
6. **Error handling**: Wrap HealthKit errors in LayeringError
7. **No improvisation**: Follow this plan exactly

---

## Definition of Done

- [ ] All 4 new files created in correct locations
- [ ] SyncInterval registered in ModelContainer
- [ ] LayeringService compiles without errors
- [ ] Can run `performLayering()` with mock HealthKit provider
- [ ] Intervals saved to SwiftData with correct data
