import Foundation
import HabitCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The one screen: next session, this week, last four weeks. A card on top
/// only when something went wrong, someone came back, or a break is on.
/// Re-evaluated every minute so the day rolls over on its own.
struct RootView: View {
    @Environment(HabitStore.self) private var store
    @State private var router = AppRouter.shared
    @State private var showImporter = false
    @State private var importNote: String?

    var body: some View {
        @Bindable var router = router
        NavigationStack {
            TimelineView(.everyMinute) { _ in
                HomeContent(now: store.now(), importNote: importNote)
            }
            .navigationTitle("Keystone")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HomeMenu(showImporter: $showImporter)
                }
            }
        }
        .sheet(item: $router.hardDay) { request in
            HardDayView(request: request)
        }
        .sheet(isPresented: $router.showBreakSheet) {
            BreakSheet()
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            let note = store.importExport(from: result)
            importNote = note.isEmpty ? nil : note
        }
    }
}

/// The list itself, for one moment.
private struct HomeContent: View {
    let now: LocalMoment
    let importNote: String?
    @Environment(HabitStore.self) private var store

    var body: some View {
        List {
            switch store.log.standing(at: now) {
            case .missed(let inARow):
                MorningAfterCard(now: now, missedInARow: inARow)
            case .comeback:
                ComebackCard()
            case .onBreak(let plannedBreak):
                OnBreakCard(plannedBreak: plannedBreak, now: now)
            case .onPlan:
                EmptyView()
            }
            NextSessionSection(now: now)
            TodaySection(now: now)
            CountsSection(now: now)
            if let importNote {
                Section {
                    Text(importNote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private extension HabitStore {
    /// Reads an exported file and merges it in. Returns a quiet one-line note
    /// for the home screen, empty when there is nothing to say.
    func importExport(from result: Result<URL, any Error>) -> String {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let envelope = try Export.decode(Data(contentsOf: url))
            importLog(envelope.log)
            return "Imported."
        } catch ExportError.unsupportedVersion {
            return "That file is from a newer version of Keystone."
        } catch let error as CocoaError where error.code == .userCancelled {
            return ""
        } catch {
            return "That file couldn't be read."
        }
    }
}

#Preview("Empty") {
    RootView()
        .environment(HabitStore(context: KeystoneStore.makeInMemoryContainer().mainContext))
}

#Preview("Morning after") {
    let store = HabitStore(context: KeystoneStore.makeInMemoryContainer().mainContext)
    let today = store.today()
    store.logVisit(on: today.adding(days: -10))
    store.importLog(HabitLog(firstDay: today.adding(days: -14)))
    return RootView()
        .environment(store)
}

#Preview("On break") {
    let store = HabitStore(context: KeystoneStore.makeInMemoryContainer().mainContext)
    let today = store.today()
    store.declareBreak(PlannedBreak(
        kind: .travel,
        firstDay: today,
        lastDay: today.adding(days: 4),
        reentryPlan: defaultReentryPlan(returning: today.adding(days: 7).weekday)
    ))
    return RootView()
        .environment(store)
}
