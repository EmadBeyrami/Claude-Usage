import Foundation
import Security

public struct Credentials: Sendable, Equatable {
    public let token: String?
    public let expired: Bool

    public static let none = Credentials(token: nil, expired: false)
}

/// Reads the OAuth access token for a profile.
///
/// The app is sandboxed, so it can reach exactly two places outside its own
/// container: files inside a folder the user has granted (Settings' folder
/// picker), and its own Keychain items. Claude Code's Keychain entry belongs
/// to a different app with a different keychain-access-group — there is no
/// entitlement that opens it, sandboxed or not. Accounts whose token lives in
/// `<config dir>/.credentials.json` still work automatically, since that file
/// is inside the granted folder. Accounts where Claude Code only ever wrote
/// the token to the Keychain (the ordinary default install) need the user to
/// paste it once in Settings; it's stored from then on in this app's own
/// Keychain item, which the sandbox permits with no extra entitlement.
public enum CredentialStore {

    public static func read(for profile: Profile) -> Credentials {
        if let fromFile = readFile(at: profile.credentialsFile), fromFile.token != nil {
            return fromFile
        }
        if let pasted = ManualTokenStore.read(for: profile) {
            return parseManualInput(pasted)
        }
        return .none
    }

    public static func hasManualToken(for profile: Profile) -> Bool {
        ManualTokenStore.read(for: profile) != nil
    }

    public static func saveManualToken(_ text: String, for profile: Profile) {
        ManualTokenStore.save(text, for: profile)
    }

    public static func clearManualToken(for profile: Profile) {
        ManualTokenStore.clear(for: profile)
    }

    static func readFile(at url: URL) -> Credentials? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return parse(data)
    }

    /// Accepts either the full `.credentials.json` shape (or its
    /// `claudeAiOauth` node, e.g. copied from Keychain Access), or a bare
    /// access token with no known expiry.
    static func parseManualInput(_ text: String) -> Credentials {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .none }
        if let data = trimmed.data(using: .utf8), let parsed = parse(data) {
            return parsed
        }
        return Credentials(token: trimmed, expired: false)
    }

    static func parse(_ data: Data) -> Credentials? {
        // A trailing newline (e.g. from `security -w`) is harmless to JSON,
        // but trimming first keeps the empty-string case obvious.
        let trimmed = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let bytes = trimmed.data(using: .utf8),
            let root = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any]
        else { return nil }

        let oauth = (root["claudeAiOauth"] as? [String: Any]) ?? root
        guard let token = oauth["accessToken"] as? String else { return nil }
        let expiresAtMs = (oauth["expiresAt"] as? NSNumber)?.doubleValue ?? 0
        let nowMs = Date().timeIntervalSince1970 * 1000
        return Credentials(token: token, expired: expiresAtMs > 0 && nowMs > expiresAtMs)
    }
}

/// This app's own Keychain item for a manually pasted token — one per
/// profile, keyed by the profile's config directory path. Ordinary
/// `SecItemAdd`/`SecItemCopyMatching` with no access-group entitlement, which
/// the sandbox allows for items the app itself created.
enum ManualTokenStore {
    private static let service = "dev.beyrami.claude-usage.manual-token"

    static func save(_ text: String, for profile: Profile) {
        clear(for: profile)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profile.id,
            kSecValueData as String: Data(trimmed.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(for profile: Profile) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profile.id,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    static func clear(for profile: Profile) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profile.id,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
