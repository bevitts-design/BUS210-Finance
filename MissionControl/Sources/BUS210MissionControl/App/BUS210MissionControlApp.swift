import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async { [weak self] in
            self?.bringMainWindowForward(in: NSApp)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        bringMainWindowForward(in: sender)
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func bringMainWindowForward(in application: NSApplication) {
        if let window = application.windows.first(where: { $0.canBecomeMain }) ?? application.windows.first {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
        }
        application.activate(ignoringOtherApps: true)
    }
}

@main
struct BUS210MissionControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = MissionControlStore()
    @StateObject private var publishStore = PublishStore()

    var body: some Scene {
        WindowGroup("BUS210 Mission Control", id: "main") {
            ContentView(store: store, publishStore: publishStore)
                .frame(minWidth: 1_040, minHeight: 680)
                .task { store.load() }
        }
        .defaultSize(width: 1_180, height: 760)
        .commands {
            CommandMenu("Course") {
                Button("Reload Course Map") { store.load() }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(store.isWorking || store.isDirty)
                Button("Save and Rebuild") { store.saveAndRebuild() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(store.isWorking || !store.isDirty)
                Divider()
                Button("Discard Changes") { store.discardChanges() }
                    .disabled(store.isWorking || !store.isDirty)
            }
        }
    }
}
