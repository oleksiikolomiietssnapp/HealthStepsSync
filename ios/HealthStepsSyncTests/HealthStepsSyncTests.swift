//
//  LayeringServiceTests.swift
//  HealthStepsSyncTests
//
//  Created on 1/15/26.
//

import Foundation
import Testing

@testable import HealthStepsSync

@Suite("LayeringService Tests")
struct LayeringServiceTests {
    @Test() @MainActor
    func testRegularSteps() async throws {
        let service = LayeringService(stepDataProvider: HealthKitManager.mock(), storageProvider: MockStorageProvider())

        let results = try await service.performLayering()

        #expect(
            results.allSatisfy { interval in
                interval.stepCount <= 10_000
                    && interval.syncedToServer == false
                    && interval.endDate > interval.startDate
            }
        )

        print(results.count)
        let endDates = results.map(\.endDate).dropLast()
        let startDates = results.map(\.startDate).dropFirst()
        #expect(endDates.count == startDates.count)

        for (endDate, startDate) in zip(endDates, startDates) {
            #expect(endDate == startDate, "Gap found: end \(endDate) != start \(startDate)")
        }
    }

    @Test() @MainActor
    func testRealisticSteps() async throws {
        let service = LayeringService(stepDataProvider: HealthKitManager.realisticMock(), storageProvider: MockStorageProvider())

        let results = try await service.performLayering()

        print(results.count)
        #expect(
            results.allSatisfy { interval in
                interval.stepCount <= 10_000
                    && interval.syncedToServer == false
                    && interval.endDate > interval.startDate
            }
        )

        let endDates = results.map(\.endDate).dropLast()
        let startDates = results.map(\.startDate).dropFirst()
        #expect(endDates.count == startDates.count)

        for (endDate, startDate) in zip(endDates, startDates) {
            #expect(endDate == startDate, "Gap found: end \(endDate) != start \(startDate)")
        }
    }

    @Test() @MainActor
    func testWorstCaseSteps() async throws {
        let service = LayeringService(stepDataProvider: HealthKitManager.worstCaseMock(), storageProvider: MockStorageProvider())

        let results = try await service.performLayering()

        print(results.count)
        #expect(
            results.allSatisfy { interval in
                interval.stepCount <= 10_000
                    && interval.syncedToServer == false
                    && interval.endDate > interval.startDate
            }
        )

        let endDates = results.map(\.endDate).dropLast()
        let startDates = results.map(\.startDate).dropFirst()
        #expect(endDates.count == startDates.count)

        for (endDate, startDate) in zip(endDates, startDates) {
            #expect(endDate == startDate, "Gap found: end \(endDate) != start \(startDate)")
        }
    }
}

extension HealthKitManager where T == MockStatisticsQueryProvider {
    static func realisticMock() -> Self {
        self.init(healthKitProvider: RealisticMockStatisticsQueryProvider())
    }

    static func worstCaseMock() -> Self {
        self.init(healthKitProvider: WorstCaseMockStatisticsQueryProvider())
    }
}
