//
//  LayeringServiceTests.swift
//  HealthStepsSyncTests
//
//  Created on 1/15/26.
//

import Foundation
import Testing

@testable import HealthStepsSync

@MainActor
@Suite("LayeringService Tests")
struct LayeringServiceTests {
    @Test()
    func testRegularSteps() async throws {
        let storage = MockStorageProvider()
        let service = LayeringServiceImplementation(stepDataSource: HealthKitStepDataSource.mock(), storageProvider: storage)

        try await service.performLayering()
        let results = storage.source

        #expect(
            results.allSatisfy { interval in
                interval.value.syncedToServer == false &&
                interval.value.endDate > interval.value.startDate
            }
        )

        print(results.count)
        let endDates = results.map(\.value.endDate).dropLast()
        let startDates = results.map(\.value.startDate).dropFirst()
        #expect(endDates.count == startDates.count)

        for (endDate, startDate) in zip(endDates, startDates) {
            #expect(endDate == startDate, "Gap found: end \(endDate) != start \(startDate)")
        }
    }

    @Test() @MainActor
    func testRealisticSteps() async throws {
        let storage = MockStorageProvider()
        let service = LayeringServiceImplementation(
            stepDataSource: HealthKitStepDataSource.realisticMock(),
            storageProvider: storage
        )

        try await service.performLayering()
        let results = storage.source

        print(results.count)
        #expect(
            results.allSatisfy { interval in
                interval.value.syncedToServer == false &&
                interval.value.endDate > interval.value.startDate
            }
        )

        let endDates = results.map(\.value.endDate).dropLast()
        let startDates = results.map(\.value.startDate).dropFirst()
        #expect(endDates.count == startDates.count)

        for (endDate, startDate) in zip(endDates, startDates) {
            #expect(endDate == startDate, "Gap found: end \(endDate) != start \(startDate)")
        }
    }

    @Test() @MainActor
    func testWorstCaseSteps() async throws {
        let storage = MockStorageProvider()
        let service = LayeringServiceImplementation(
            stepDataSource: HealthKitStepDataSource.worstCaseMock(),
            storageProvider: storage
        )

        try await service.performLayering()
        let results = storage.source

        print(results.count)
        #expect(
            results.allSatisfy { interval in
                interval.value.syncedToServer == false &&
                interval.value.endDate > interval.value.startDate
            }
        )

        let endDates = results.map(\.value.endDate).dropLast()
        let startDates = results.map(\.value.startDate).dropFirst()
        #expect(endDates.count == startDates.count)

        for (endDate, startDate) in zip(endDates, startDates) {
            #expect(endDate == startDate, "Gap found: end \(endDate) != start \(startDate)")
        }
    }
}

extension HealthKitStepDataSource where T == MockStatisticsQueryProvider {
    static func realisticMock() -> Self {
        self.init(stepQuery: RealisticMockStatisticsQueryProvider())
    }

    static func worstCaseMock() -> Self {
        self.init(stepQuery: WorstCaseMockStatisticsQueryProvider())
    }
}
