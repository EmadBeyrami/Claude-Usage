import Foundation

/// One Claude Code config directory, i.e. one logged-in account.
///
/// `CLAUDE_CONFIG_DIR` relocates the whole `~/.claude` tree, and that is the
/// only profile mechanism Claude Code has — there is no in-app switcher, and
/// `/login` overwrites whatever account a directory currently holds.
public struct Profile: Codable, Sendable, Equatable, Identifiable {
    public var configDir: URL
    public var isDefault: Bool
    /// From the global config's `oauthAccount`. Absent is normal and fine — a
    /// directory with transcripts but no global config is still usable.
    public var email: String?
    public var organization: String?
    public var plan: String?

    public var id: String { configDir.path }

    public init(configDir: URL, isDefault: Bool,
                email: String? = nil, organization: String? = nil, plan: String? = nil) {
        self.configDir = configDir
        self.isDefault = isDefault
        self.email = email
        self.organization = organization
        self.plan = plan
    }

    public var projectsDirectory: URL {
        configDir.appendingPathComponent("projects", isDirectory: true)
    }

    public var credentialsFile: URL {
        configDir.appendingPathComponent(".credentials.json")
    }

    public var displayName: String {
        let base = isDefault ? "Default" : configDir.lastPathComponent
        guard let email, !email.isEmpty else { return base }
        return "\(base) — \(email)"
    }
}

/// Turns the folders the user has granted access to (via Settings' folder
/// picker) into profiles.
///
/// Unlike an unsandboxed app, this can't go looking for `~/.claude` or its
/// siblings on its own — the sandbox makes every folder outside the app's
/// container invisible until the user picks it with an Open panel. So
/// discovery here is just validation: of the folders already granted, which
/// ones actually look like a Claude Code config directory.
public enum ProfileStore {

    /// One profile per granted folder that contains a `projects` subdirectory,
    /// in the order granted. The folder literally named `.claude` (the
    /// ordinary, unrelocated install) is the default if present; otherwise the
    /// first granted folder is.
    public static func discover(grantedFolders: [URL]) -> [Profile] {
        var seen = Set<String>()
        var profiles: [Profile] = []
        for candidate in grantedFolders {
            let dir = candidate.resolvingSymlinksInPath().standardizedFileURL
            guard seen.insert(dir.path).inserted, isProfile(dir) else { continue }
            profiles.append(profile(at: dir, isDefault: dir.lastPathComponent == ".claude"))
        }
        return profiles
    }

    /// Transcripts are the only thing that makes a directory worth reading.
    /// Deliberately not requiring `.credentials.json` — it can be moved by
    /// `CLAUDE_SECURESTORAGE_CONFIG_DIR` or `CLAUDE_CODE_HOST_CREDS_FILE`, or
    /// live in the Keychain with no file at all.
    static func isProfile(_ dir: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let projects = dir.appendingPathComponent("projects", isDirectory: true)
        return FileManager.default.fileExists(atPath: projects.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    static func profile(at dir: URL, isDefault: Bool) -> Profile {
        var profile = Profile(configDir: dir, isDefault: isDefault)
        guard let config = globalConfigURL(for: dir, isDefault: isDefault),
              let data = try? Data(contentsOf: config),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let account = root["oauthAccount"] as? [String: Any]
        else { return profile }

        profile.email = account["emailAddress"] as? String
        profile.organization = account["organizationName"] as? String
        profile.plan = planLabel(account["organizationRateLimitTier"] as? String)
        return profile
    }

    /// Where the account identity lives, which depends on the profile.
    ///
    /// A relocated profile keeps its global config *inside* the config dir; an
    /// unrelocated `.claude` keeps it as a *sibling* — `~/.claude.json`, not
    /// `~/.claude/.claude.json`. That sibling path sits outside the granted
    /// folder's own security scope, so it only resolves if the user has
    /// separately granted access to the parent too; otherwise this candidate
    /// silently fails, same as a directory with no global config at all.
    static func globalConfigURL(for dir: URL, isDefault: Bool) -> URL? {
        var candidates = [
            dir.appendingPathComponent(".config.json"),
            dir.appendingPathComponent(".claude.json"),
        ]
        if isDefault {
            candidates.append(dir.deletingLastPathComponent().appendingPathComponent(".claude.json"))
        }
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// "default_claude_max_20x" -> "Max". Anything unrecognised stays nil rather
    /// than putting a raw internal tier string in front of the user.
    static func planLabel(_ tier: String?) -> String? {
        guard let tier = tier?.lowercased() else { return nil }
        for name in ["enterprise", "team", "max", "pro", "free"] where tier.contains(name) {
            return name.capitalized
        }
        return nil
    }
}

extension ProfileStore {
    /// Blind filesystem discovery: `~/.claude`, anything beside it whose name
    /// starts with `.claude`, and `CLAUDE_CONFIG_DIR` if set.
    ///
    /// Only valid for a process with the user's own file permissions — the CLI
    /// and the test suite. The sandboxed menu bar app cannot do this; it has to
    /// go through folders the user explicitly grants, see `discover(grantedFolders:)`.
    public static func autoDiscoverCandidates(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL? = nil
    ) -> [URL] {
        let home = home ?? FileManager.default.homeDirectoryForCurrentUser
        let defaultDir = home.appendingPathComponent(".claude", isDirectory: true)

        var candidates: [URL] = []
        if let configured = environment["CLAUDE_CONFIG_DIR"], !configured.isEmpty {
            candidates.append(URL(fileURLWithPath:
                (configured as NSString).expandingTildeInPath, isDirectory: true))
        }
        candidates.append(defaultDir)
        candidates.append(contentsOf: siblings(of: home))
        return candidates
    }

    private static func siblings(of home: URL) -> [URL] {
        // No .skipsHiddenFiles: every candidate here starts with a dot.
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: home, includingPropertiesForKeys: [.isDirectoryKey], options: [])
        else { return [] }

        return entries
            .filter { $0.lastPathComponent.hasPrefix(".claude") }
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
