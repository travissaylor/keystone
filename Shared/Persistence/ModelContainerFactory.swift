import Foundation
import OSLog
import SwiftData

/// The one SwiftData store every Keystone process opens.
///
/// It lives in the App Group container so the app and the widget see the same
/// data. Only the main app process syncs it with CloudKit; extensions open the
/// same file local-only, so two processes never run CloudKit mirroring at once.
nonisolated enum KeystoneStore {
    static let appGroupID = "group.com.travissaylor.keystone"
    static let cloudKitContainerID = "iCloud.com.travissaylor.keystone"
    static let storeFileName = "Keystone.store"

    /// Every persisted model type.
    static var schema: Schema {
        Schema([
            WorkoutRecord.self,
            ManualEntryRecord.self,
            DayRecord.self,
            BreakRecord.self,
            WeekTargetRecord.self,
            MetaRecord.self
        ])
    }

    /// `Keystone.store` in the App Group container. Falls back to Application
    /// Support when the group container is unavailable (an unsigned build).
    static var storeURL: URL {
        let directory = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: storeFileName)
    }

    /// The on-disk container. Pass `syncWithCloudKit: true` only from the main
    /// app process. If the CloudKit configuration fails to load (no iCloud
    /// account, missing entitlement), it falls back to a local-only store on
    /// the same file, so the app keeps working with iCloud off.
    static func makeContainer(syncWithCloudKit: Bool) throws -> ModelContainer {
        let schema = schema
        let url = storeURL
        if syncWithCloudKit {
            let synced = ModelConfiguration(
                "Keystone",
                schema: schema,
                url: url,
                cloudKitDatabase: .private(cloudKitContainerID)
            )
            do {
                return try ModelContainer(for: schema, configurations: synced)
            } catch {
                logger.error("CloudKit store failed to load, opening local-only: \(error.localizedDescription, privacy: .public)")
            }
        }
        let local = ModelConfiguration("Keystone", schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: local)
    }

    /// An empty, memory-only container for previews and tests.
    static func makeInMemoryContainer() -> ModelContainer {
        let schema = schema
        let configuration = ModelConfiguration(
            "KeystonePreview",
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Failed to create in-memory ModelContainer: \(error)")
        }
    }

    private static let logger = Logger(subsystem: "com.travissaylor.keystone", category: "Persistence")
}
