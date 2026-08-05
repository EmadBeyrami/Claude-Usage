import SwiftUI

/// Shown in place of the ordinary popover before any folder has been granted.
/// The app is sandboxed, so this isn't an edge case — it's the very first
/// thing every install sees.
struct OnboardingView: View {
    var grantFolder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "folder.badge.questionmark")
                    .foregroundStyle(.secondary)
                Text("Grant access to get started")
                    .font(.system(size: 12, weight: .semibold))
            }
            Text("Claude Usage reads usage data straight from your Claude Code config folder — nothing is sent anywhere except a single request to Anthropic, using your own login. macOS requires you to pick that folder yourself once.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                grantFolder()
            } label: {
                Text("Choose “.claude” Folder…")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            Text("Usually **~/.claude** in your home folder. Already on a relocated `CLAUDE_CONFIG_DIR`? It's pre-selected.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

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
