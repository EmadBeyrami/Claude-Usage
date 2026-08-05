import SwiftUI

/// Shown in place of the ordinary popover before any folder has been granted.
/// The compact counterpart to `WelcomeView`, which covers the same two steps
/// at full size and opens automatically on first launch — this is what's
/// left in the popover for anyone who dismissed that window, or is
/// revisiting setup after removing a folder.
struct OnboardingView: View {
    var grantedFolders: [URL] = []
    var grantFolder: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "folder.badge.questionmark")
                    .foregroundStyle(.secondary)
                Text("Get started")
                    .font(.system(size: 12, weight: .semibold))
            }

            SetupStep(number: 1, title: "Sign in to Claude Code") { SignInStep() }
            SetupStep(number: 2, title: "Grant this app access") {
                GrantAccessStep(grantedFolders: grantedFolders, grantFolder: grantFolder)
            }

            Divider().padding(.vertical, 2)

            HStack {
                SettingsLink { Text("Settings…") }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(.link)
            .font(.system(size: 11))
        }
    }
}
