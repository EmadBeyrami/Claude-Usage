import SwiftUI

@main
struct ClaudeUsageApp: App {
    @StateObject private var poller = Poller()

    var body: some Scene {
        MenuBarExtra {
            MenuView(snapshot: poller.snapshot,
                     isRefreshing: poller.isRefreshing,
                     needsOnboarding: poller.needsOnboarding,
                     update: poller.update,
                     refresh: poller.refreshNow,
                     grantFolder: { poller.addFolder(FolderPicker.suggestedFolder) })
        } label: {
            // Monospaced digits stop the menu bar shuffling as the number changes.
            Text(poller.menuBarTitle).monospacedDigit()
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(poller: poller)
        }
    }
}
