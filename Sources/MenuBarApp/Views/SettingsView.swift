import AppKit
import ServiceManagement
import SwiftUI

enum SettingsKey {
    static let warn = "warnThreshold"
    static let critical = "criticalThreshold"
    static let userAgent = "userAgent"
    static let menuBarMetric = "menuBarMetric"
    static let selectedProfile = "selectedProfile"
    static let autoCheckUpdates = "autoCheckUpdates"
}

struct SettingsView: View {
    @ObservedObject var poller: Poller

    @AppStorage(SettingsKey.warn) private var warn = 50.0
    @AppStorage(SettingsKey.critical) private var critical = 80.0
    @AppStorage(SettingsKey.userAgent) private var userAgent = UsageAPI.defaultUserAgent
    @AppStorage(SettingsKey.menuBarMetric) private var menuBarMetric = "session"
    @AppStorage(SettingsKey.selectedProfile) private var selectedProfile = ""
    @AppStorage(SettingsKey.autoCheckUpdates) private var autoCheckUpdates = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?
    @State private var tokenInput = ""
    @State private var showsTokenHelp = false

    var body: some View {
        Form {
            profileSection
            tokenSection
            widgetSection
            displaySection
            updatesSection

            Section {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let launchError {
                    Text(launchError).font(.caption).foregroundStyle(.red)
                }
            }

            Section {
                TextField("User-Agent", text: $userAgent)
                Text("The usage endpoint rate-limits clients that don't identify as Claude Code. Change this only if the version string goes stale.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        // Amber above red would colour everything red; keep the bands ordered.
        .onChange(of: warn) { _, new in if new > critical { critical = new } }
        .onChange(of: critical) { _, new in if new < warn { warn = new } }
        .onChange(of: selectedProfile) { _, _ in tokenInput = "" }
        .onAppear(perform: reload)
    }

    // MARK: - Profiles

    private var profileSection: some View {
        Section {
            if poller.profiles.isEmpty {
                Text("No folders granted yet")
                    .font(.callout)
                Text("Claude Usage is sandboxed, so it can't see your Claude Code config until you point it there — usually ~/.claude. Add it below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Profile", selection: $selectedProfile) {
                    ForEach(poller.profiles) { profile in
                        Text(profile.displayName).tag(profile.id)
                    }
                }
                .onChange(of: selectedProfile) { _, id in
                    guard let picked = poller.profiles.first(where: { $0.id == id }) else { return }
                    poller.select(picked)
                }
                if let active = poller.profiles.first(where: { $0.id == selectedProfile }) {
                    LabeledContent("Folder", value: active.configDir.path)
                        .font(.caption)
                    if let organization = active.organization {
                        LabeledContent("Organization",
                                       value: [organization, active.plan].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption)
                    }
                }
            }

            ForEach(poller.grantedFolders, id: \.self) { url in
                HStack {
                    Text((url.path as NSString).abbreviatingWithTildeInPath)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Remove") { poller.removeFolder(url) }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }

            HStack {
                Button("Add Folder…", action: addFolder)
                Spacer()
                Button("Rescan") { poller.rediscover() }
            }

            if poller.profiles.count > 1 {
                Text("Each profile is a separate Claude account. Limits, tokens and history are tracked independently.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Profile")
        }
    }

    private func addFolder() {
        guard let url = FolderPicker.choose(
            message: "Choose a Claude Code config folder — the one containing a “projects” folder.",
            suggesting: FolderPicker.suggestedFolder)
        else { return }
        poller.addFolder(url)
    }

    private func reload() {
        poller.rediscover()
    }

    // MARK: - Access token

    private var tokenSection: some View {
        Section {
            if let active = poller.profiles.first(where: { $0.id == selectedProfile }) {
                if FileManager.default.fileExists(atPath: active.credentialsFile.path) {
                    Label("Found automatically in this profile's folder", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Claude Usage can't reach Claude Code's Keychain entry — macOS doesn't allow one sandboxed app to read another's. Paste the token once and it's stored in Claude Usage's own Keychain item.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    SecureField(CredentialStore.hasManualToken(for: active) ? "Token saved — paste to replace" : "Access token",
                                text: $tokenInput)

                    HStack {
                        Button("Save") { saveToken(for: active) }
                            .disabled(tokenInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        if CredentialStore.hasManualToken(for: active) {
                            Button("Clear") { clearToken(for: active) }
                        }
                        Spacer()
                        Button("How do I get this?") { showsTokenHelp = true }
                            .buttonStyle(.link)
                            .font(.caption)
                    }
                    if showsTokenHelp {
                        tokenHelp
                    }

                    Text("Session and weekly limit percentages need this. Token counts and cost never do — those come from the folder above regardless.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } header: {
            Text("Access Token")
        }
    }

    private var tokenHelp: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("In Terminal, run:")
                .font(.caption)
            HStack {
                Text(Self.tokenCommand)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(1)
                Spacer()
                Button("Copy") { SystemActions.copyToClipboard(Self.tokenCommand) }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
            Text("Paste the whole output above — it's JSON, and Claude Usage reads the token out of it. The token expires periodically; repeat this whenever Settings shows a “token expired” message.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
    }

    private static let tokenCommand = #"security find-generic-password -s "Claude Code-credentials" -w"#

    private func saveToken(for profile: Profile) {
        CredentialStore.saveManualToken(tokenInput, for: profile)
        tokenInput = ""
        showsTokenHelp = false
        poller.refreshNow()
    }

    private func clearToken(for profile: Profile) {
        CredentialStore.clearManualToken(for: profile)
        poller.refreshNow()
    }

    // MARK: - Widget

    /// The app and the widget are two separate sandboxed processes — they only
    /// ever see the same data through the App Group container. If that
    /// entitlement never got provisioned (common for a build made entirely
    /// from the command line, before Xcode's Signing & Capabilities tab has
    /// registered the group with your Apple Developer account), each process
    /// silently falls back to its own private Application Support folder and
    /// the widget never updates — no error, just nothing. This section makes
    /// that failure visible instead of leaving it to guesswork.
    private var widgetSection: some View {
        Section {
            LabeledContent("App ↔ widget sharing") {
                if appGroupContainer != nil {
                    Label("Working", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("Unavailable", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Level.warn.tint)
                }
            }
            .font(.caption)

            if appGroupContainer == nil {
                Text("The widget can't see this app's data without it. In Xcode, select the ClaudeUsage target, then the ClaudeUsageWidget target, under Signing & Capabilities — confirm App Groups lists \(Snapshot.appGroup) with no warning icon on either.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let written = lastWrittenSnapshot {
                LabeledContent("Last written", value: Self.diagnosticFormatter.string(from: written))
                    .font(.caption)
            } else {
                Text("No snapshot written yet — grant a folder above, then hit Rescan.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        } header: {
            Text("Widget")
        }
    }

    private var appGroupContainer: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Snapshot.appGroup)
    }

    private var lastWrittenSnapshot: Date? {
        SnapshotBundle.read()?.updatedAt
    }

    private static let diagnosticFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .medium
        return f
    }()

    // MARK: - Display

    private var displaySection: some View {
        Section {
            Picker("Menu bar shows", selection: $menuBarMetric) {
                Text("5-hour session").tag("session")
                Text("Weekly").tag("weekly")
            }
            Slider(value: $warn, in: 10...95, step: 5) {
                Text("Amber above")
            } minimumValueLabel: {
                Text("10%").font(.caption)
            } maximumValueLabel: {
                Text("95%").font(.caption)
            }
            LabeledContent("", value: "\(Int(warn))%")
            Slider(value: $critical, in: 10...100, step: 5) {
                Text("Red above")
            } minimumValueLabel: {
                Text("10%").font(.caption)
            } maximumValueLabel: {
                Text("100%").font(.caption)
            }
            LabeledContent("", value: "\(Int(critical))%")
        }
    }

    // MARK: - Updates

    private var updatesSection: some View {
        Section {
            LabeledContent("Version", value: AppVersion.current)
            HStack {
                // A silent success has to look like a success — without this the
                // feature is invisible until the day an update happens to exist.
                Text(updateStatus)
                    .font(.callout)
                    .foregroundStyle(poller.update == nil ? .secondary : .primary)
                Spacer()
                Button("Check Now", action: poller.checkForUpdates)
            }
            if let release = poller.update {
                Link("Open release notes", destination: release.url)
                    .font(.callout)
            }
            Toggle("Check automatically", isOn: $autoCheckUpdates)
            Text("Checks GitHub four times a day, informational only — updates themselves come through the App Store.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Updates")
        }
    }

    private var updateStatus: String {
        if let release = poller.update {
            return "Version \(release.version) available"
        }
        guard let checked = poller.lastUpdateCheck else { return "Not checked yet" }
        let age = Int(Date().timeIntervalSince(checked))
        return age < 60 ? "Up to date — checked just now" : "Up to date"
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchError = nil
        } catch {
            launchError = error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
