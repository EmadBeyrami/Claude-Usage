import SwiftUI

@main
struct ClaudeUsageApp: App {
    @StateObject private var poller = Poller()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(poller: poller)
        } label: {
            // Monospaced digits stop the menu bar shuffling as the number changes.
            MenuBarLabel(poller: poller)
        }
        .menuBarExtraStyle(.window)

        // The app's real front door — see WelcomeView for why an
        // LSUIElement app needs one at all. Opens automatically on a first
        // launch (MenuBarLabel triggers it) and stays reachable afterwards
        // from the popover's "Welcome…" link.
        Window("Welcome to Claude Usage", id: "welcome") {
            WelcomeContent(poller: poller)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView(poller: poller)
        }
    }
}

/// A separate view (not inline in the Scene builder) so it can own the
/// `openWindow` action needed to show the Welcome window automatically.
/// `MenuBarExtra`'s label renders immediately at launch to build the status
/// item — unlike its lazily-built popover content — which is what makes this
/// the right place to hook a one-time "is setup still needed?" check.
private struct MenuBarLabel: View {
    @ObservedObject var poller: Poller
    @Environment(\.openWindow) private var openWindow
    @State private var openedWelcome = false

    var body: some View {
        Text(poller.menuBarTitle)
            .monospacedDigit()
            .task { showWelcomeIfNeeded() }
            .onChange(of: poller.needsOnboarding) { _, _ in showWelcomeIfNeeded() }
    }

    private func showWelcomeIfNeeded() {
        guard !openedWelcome, poller.needsOnboarding else { return }
        openedWelcome = true
        openWindow(id: "welcome")
    }
}

private struct MenuBarContent: View {
    @ObservedObject var poller: Poller
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        MenuView(snapshot: poller.snapshot,
                 isRefreshing: poller.isRefreshing,
                 needsOnboarding: poller.needsOnboarding,
                 grantedFolders: poller.grantedFolders,
                 update: poller.update,
                 refresh: poller.refreshNow,
                 grantFolder: { FolderPicker.chooseAndGrant { poller.addFolder($0) } },
                 saveToken: { poller.saveToken($0) },
                 openWelcome: { openWindow(id: "welcome") })
    }
}

private struct WelcomeContent: View {
    @ObservedObject var poller: Poller

    var body: some View {
        WelcomeView(grantedFolders: poller.grantedFolders,
                   grantFolder: { FolderPicker.chooseAndGrant { poller.addFolder($0) } })
    }
}
