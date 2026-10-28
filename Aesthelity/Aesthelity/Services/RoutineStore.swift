//
//  RoutineStore.swift
//  Aesthelity
//
//  Persistent file-backed store for user skincare routines.
//

import Combine
import Foundation

/// Root document format for stored routines with schema versioning.
public struct RoutineStorageDocument: Codable, Equatable {
    public var schemaVersion: Int
    public var routines: [RoutineRecord]

    public init(schemaVersion: Int = 1, routines: [RoutineRecord] = []) {
        self.schemaVersion = schemaVersion
        self.routines = routines
    }
}

@MainActor
public final class RoutineStore: ObservableObject {
    public nonisolated static let defaultFileURL = URL.applicationSupportDirectory
        .appendingPathComponent("Routines/routines.json")

    public static let shared = RoutineStore()

    @Published public private(set) var routines: [RoutineRecord] = []
    @Published public private(set) var loadError: String?
    public let fileURL: URL

    public enum StoreError: Error, LocalizedError, Equatable {
        case unsupportedSchemaVersion
        case corruptedData
        case routineNotFound

        public var errorDescription: String? {
            switch self {
            case .unsupportedSchemaVersion:
                return "Unsupported routine storage schema version."
            case .corruptedData:
                return "Saved routine data is corrupted or invalid."
            case .routineNotFound:
                return "The requested routine was not found."
            }
        }
    }

    public init(fileURL: URL = RoutineStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
    }

    public func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            routines = []
            loadError = nil
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            guard !data.isEmpty else {
                throw StoreError.corruptedData
            }

            if let doc = try? JSONDecoder().decode(RoutineStorageDocument.self, from: data) {
                guard doc.schemaVersion == 1 else {
                    throw StoreError.unsupportedSchemaVersion
                }
                routines = doc.routines
                loadError = nil
            } else if let legacyList = try? JSONDecoder().decode([RoutineRecord].self, from: data) {
                routines = legacyList
                loadError = nil
            } else {
                throw StoreError.corruptedData
            }
        } catch let error as StoreError {
            routines = []
            loadError = error.errorDescription
        } catch {
            routines = []
            loadError = "Your saved routines could not be loaded."
        }
    }

    /// Saves a new routine, or updates an existing routine if one with the same ID already exists.
    public func save(_ routine: RoutineRecord) throws {
        var updatedRoutines = routines
        if let index = updatedRoutines.firstIndex(where: { $0.id == routine.id }) {
            updatedRoutines[index] = routine
        } else {
            updatedRoutines.append(routine)
        }
        try persist(routines: updatedRoutines)
    }

    /// Explicitly updates an existing routine, throwing if the routine ID is not found.
    public func update(_ routine: RoutineRecord) throws {
        var updatedRoutines = routines
        guard let index = updatedRoutines.firstIndex(where: { $0.id == routine.id }) else {
            throw StoreError.routineNotFound
        }
        updatedRoutines[index] = routine
        try persist(routines: updatedRoutines)
    }

    /// Saves the given list of routines to disk atomically.
    public func saveAll(_ newRoutines: [RoutineRecord]) throws {
        try persist(routines: newRoutines)
    }

    /// Deletes a routine by its UUID.
    public func delete(id: UUID) throws {
        var updatedRoutines = routines
        guard let index = updatedRoutines.firstIndex(where: { $0.id == id }) else {
            throw StoreError.routineNotFound
        }
        updatedRoutines.remove(at: index)
        try persist(routines: updatedRoutines)
    }

    /// Resets routines to empty and updates the persisted file.
    public func resetToEmpty() throws {
        try persist(routines: [])
    }

    /// Seeds sample default routines and persists them.
    public func seedDefaults() throws {
        try persist(routines: RoutineStore.defaultSampleRoutines)
    }

    /// Internal persistence helper using atomic write.
    private func persist(routines: [RoutineRecord]) throws {
        let doc = RoutineStorageDocument(schemaVersion: 1, routines: routines)
        let data = try JSONEncoder().encode(doc)
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        self.routines = routines
        self.loadError = nil
    }

    public static let defaultSampleRoutines: [RoutineRecord] = [
        RoutineRecord(
            name: "AM Glow",
            period: .am,
            status: .paused,
            frequency: .everyDay,
            reminderTime: "7:00 AM",
            steps: [
                RoutineStepItem(stepNumber: 1, title: "Gentle Cleanser", subtitle: "Purifying · Step 1", state: .active),
                RoutineStepItem(stepNumber: 2, title: "Vitamin C Serum", subtitle: "Brightening · Step 2", state: .incomplete),
                RoutineStepItem(stepNumber: 3, title: "Daily Moisturizer", subtitle: "Hydration · Step 3", state: .incomplete),
                RoutineStepItem(stepNumber: 4, title: "SPF 46", subtitle: "Protection · Step 4", state: .incomplete)
            ]
        ),
        RoutineRecord(
            name: "PM Repair",
            period: .pm,
            status: .paused,
            frequency: .everyOtherDay,
            reminderTime: "9:00 PM",
            steps: [
                RoutineStepItem(stepNumber: 1, title: "Micellar Pre-Cleanse", subtitle: "Dissolve makeup · Step 1", state: .active),
                RoutineStepItem(stepNumber: 2, title: "Gentle Foaming Wash", subtitle: "Deep cleanse · Step 2", state: .incomplete),
                RoutineStepItem(stepNumber: 3, title: "Hyaluronic Acid", subtitle: "Hydrate · Step 3", state: .incomplete),
                RoutineStepItem(stepNumber: 4, title: "Barrier Night Cream", subtitle: "Barrier seal · Step 4", state: .incomplete),
                RoutineStepItem(stepNumber: 5, title: "Lip Sleep Mask", subtitle: "Nourish · Step 5", state: .incomplete)
            ]
        ),
        RoutineRecord(
            name: "Weekly Exfoliate",
            period: .pm,
            status: .active,
            frequency: .twoTimesAWeek,
            reminderTime: "8:30 PM",
            activeDays: [.tue, .fri],
            steps: [
                RoutineStepItem(stepNumber: 1, title: "Gentle Cleanser", subtitle: "Prep surface · Step 1", state: .active),
                RoutineStepItem(stepNumber: 2, title: "AHA/BHA Solution", subtitle: "Chemical exfoliation · Step 2", state: .incomplete),
                RoutineStepItem(stepNumber: 3, title: "Cica Soothing Gel", subtitle: "Calm and hydrate · Step 3", state: .incomplete)
            ]
        )
    ]
}

public typealias RoutineRepository = RoutineStore
public typealias RoutinePersistenceModel = RoutineStorageDocument

// MARK: - Routine Database Service Protocol

/// Abstract database service protocol for routine persistence operations.
/// Conforming types support local disk database storage or remote databases (such as Firebase Firestore).
public protocol RoutineDatabaseService: AnyObject {
    func fetchRoutines() throws -> [RoutineRecord]
    func saveRoutine(_ routine: RoutineRecord) throws
    func updateRoutine(_ routine: RoutineRecord) throws
    func deleteRoutine(id: UUID) throws
    func resetRoutines() throws
}

extension RoutineStore: RoutineDatabaseService {
    public func fetchRoutines() throws -> [RoutineRecord] {
        load()
        if let error = loadError {
            throw StoreError.corruptedData
        }
        return routines
    }

    public func saveRoutine(_ routine: RoutineRecord) throws {
        try save(routine)
    }

    public func updateRoutine(_ routine: RoutineRecord) throws {
        try update(routine)
    }

    public func deleteRoutine(id: UUID) throws {
        try delete(id: id)
    }

    public func resetRoutines() throws {
        try resetToEmpty()
    }
}

// MARK: - Database / Document Mapping

extension RoutineStepItem {
    /// Serializes routine step item to database/document dictionary (Firestore-compatible).
    public func toDatabaseDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "stepNumber": stepNumber,
            "title": title,
            "subtitle": subtitle,
            "state": state.rawValue,
            "hasClash": hasClash
        ]
        if let productId = productId {
            dict["productId"] = productId.uuidString
        }
        return dict
    }

    /// Deserializes routine step item from database/document dictionary.
    public init?(fromDatabaseDictionary dict: [String: Any]) {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let stepNumber = dict["stepNumber"] as? Int,
              let title = dict["title"] as? String,
              let subtitle = dict["subtitle"] as? String,
              let stateString = dict["state"] as? String,
              let state = StepState(rawValue: stateString) else {
            return nil
        }
        let hasClash = dict["hasClash"] as? Bool ?? false
        var productId: UUID? = nil
        if let prodString = dict["productId"] as? String {
            productId = UUID(uuidString: prodString)
        }
        self.init(
            id: id,
            stepNumber: stepNumber,
            title: title,
            subtitle: subtitle,
            state: state,
            hasClash: hasClash,
            productId: productId
        )
    }
}

extension RoutineRecord {
    /// Serializes routine record to database/document dictionary (Firestore-compatible).
    public func toDatabaseDictionary() -> [String: Any] {
        [
            "id": id.uuidString,
            "name": name,
            "period": period.rawValue,
            "status": status.rawValue,
            "frequency": frequency.rawValue,
            "reminderTime": reminderTime,
            "activeDays": Array(activeDays.map { $0.rawValue }),
            "steps": steps.map { $0.toDatabaseDictionary() },
            "pushRemindersEnabled": pushRemindersEnabled,
            "leadTime": leadTime.rawValue,
            "quietHoursEnabled": quietHoursEnabled
        ]
    }

    /// Deserializes routine record from database/document dictionary.
    public init?(fromDatabaseDictionary dict: [String: Any]) {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = dict["name"] as? String else {
            return nil
        }
        let periodString = dict["period"] as? String ?? RoutinePeriod.am.rawValue
        let period = RoutinePeriod(rawValue: periodString) ?? .am
        
        let statusString = dict["status"] as? String ?? RoutineStatus.active.rawValue
        let status = RoutineStatus(rawValue: statusString) ?? .active
        
        let freqString = dict["frequency"] as? String ?? RoutineFrequency.everyDay.rawValue
        let frequency = RoutineFrequency(rawValue: freqString) ?? .everyDay
        
        let reminderTime = dict["reminderTime"] as? String ?? "7:00 AM"
        
        let daysStrings = dict["activeDays"] as? [String] ?? []
        let activeDays = Set(daysStrings.compactMap { RoutineWeekday(rawValue: $0) })
        
        let stepDicts = dict["steps"] as? [[String: Any]] ?? []
        let steps = stepDicts.compactMap { RoutineStepItem(fromDatabaseDictionary: $0) }
            .sorted { $0.stepNumber < $1.stepNumber }
        
        let pushRemindersEnabled = dict["pushRemindersEnabled"] as? Bool ?? true
        let leadTimeString = dict["leadTime"] as? String ?? NotificationLeadTime.atTime.rawValue
        let leadTime = NotificationLeadTime(rawValue: leadTimeString) ?? .atTime
        let quietHoursEnabled = dict["quietHoursEnabled"] as? Bool ?? true

        self.init(
            id: id,
            name: name,
            period: period,
            status: status,
            frequency: frequency,
            reminderTime: reminderTime,
            activeDays: activeDays.isEmpty ? [.mon, .tue, .wed, .thu, .fri, .sat, .sun] : activeDays,
            steps: steps,
            pushRemindersEnabled: pushRemindersEnabled,
            leadTime: leadTime,
            quietHoursEnabled: quietHoursEnabled
        )
    }
}
