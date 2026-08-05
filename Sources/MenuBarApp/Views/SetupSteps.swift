import SwiftUI

/// Step 1 of 2, shared between the popover's compact onboarding and the full
/// Welcome window so the copy can't drift between the two.
struct SignInStep: View {
    private static let loginCommand = "claude login"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Claude Usage has no login of its own — it reads data Claude Code already stores on this Mac. If you haven't signed in there yet, install Claude Code and run:")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text(Self.loginCommand)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Spacer()
                Button("Copy") { SystemActions.copyToClipboard(Self.loginCommand) }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
            .padding(6)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
            Button("Open Terminal", action: SystemActions.openTerminal)
                .controlSize(.small)
        }
    }
}

/// Step 2 of 2.
struct GrantAccessStep: View {
    var grantedFolders: [URL] = []
    var grantFolder: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("macOS keeps your Claude Code folder private until you pick it yourself. Nothing is sent anywhere except one request to Anthropic, using your own login.")
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

            if !grantedFolders.isEmpty {
                Text("None of the folders you picked look like a Claude Code config folder yet — expected a “projects” subfolder inside. Make sure step 1 is done, then try again.")
                    .font(.system(size: 10))
                    .foregroundStyle(Level.warn.tint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A numbered step label — the same layout in the popover and the window.
struct SetupStep<Content: View>: View {
    let number: Int
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("\(number)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(.secondary))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            content
                .padding(.leading, 22)
        }
    }
}
