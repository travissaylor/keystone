import CoreTransferable
import Foundation
import HabitCore
import SwiftUI
import UniformTypeIdentifiers

/// The trailing toolbar menu: break, export, import. Not a settings screen.
struct HomeMenu: View {
    @Binding var showImporter: Bool
    @Environment(HabitStore.self) private var store

    var body: some View {
        Menu {
            Button {
                AppRouter.shared.showBreakSheet = true
            } label: {
                Label("Take a break", systemImage: "calendar")
            }
            ShareLink(
                item: ExportFile(log: store.log, timeZone: store.timeZone),
                preview: SharePreview("Keystone data")
            ) {
                Label("Export data", systemImage: "square.and.arrow.up")
            }
            Button {
                showImporter = true
            } label: {
                Label("Import data", systemImage: "square.and.arrow.down")
            }
        } label: {
            Label("More", systemImage: "ellipsis")
        }
    }
}

/// The whole log as a JSON file in the temporary directory, written only when
/// the share sheet asks for it.
nonisolated struct ExportFile: Transferable, Sendable {
    let log: HabitLog
    let timeZone: TimeZone

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { file in
            let exportedAt = Date()
            let url = FileManager.default.temporaryDirectory
                .appending(path: Export.fileName(exportedAt: exportedAt, in: file.timeZone))
            try Export.encode(file.log, exportedAt: exportedAt).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
