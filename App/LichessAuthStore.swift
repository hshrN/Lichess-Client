import Foundation
import Security

struct LichessAccountSession {
  var accessToken: String
  var username: String
}

enum LichessAuthStore {
  private static let service = "app.bitrig.lichess-board.auth"
  private static let accessTokenKey = "access-token"
  private static let usernameKey = "username"
  private static let legacyTokenKey = "lichessAccessToken"
  private static let legacyUsernameKey = "lichessUsername"

  static func loadSession() -> LichessAccountSession? {
    migrateLegacySessionIfNeeded()

    guard
      let accessToken = read(account: accessTokenKey),
      let username = read(account: usernameKey),
      !accessToken.isEmpty,
      !username.isEmpty
    else {
      return nil
    }

    return LichessAccountSession(accessToken: accessToken, username: username)
  }

  static func saveSession(accessToken: String, username: String) {
    write(accessToken, account: accessTokenKey)
    write(username, account: usernameKey)
  }

  static func clearSession() {
    delete(account: accessTokenKey)
    delete(account: usernameKey)
  }

  private static func migrateLegacySessionIfNeeded() {
    guard read(account: accessTokenKey) == nil || read(account: usernameKey) == nil else {
      clearLegacySession()
      return
    }

    let defaults = UserDefaults.standard
    guard
      let token = defaults.string(forKey: legacyTokenKey),
      let username = defaults.string(forKey: legacyUsernameKey),
      !token.isEmpty,
      !username.isEmpty
    else {
      clearLegacySession()
      return
    }

    saveSession(accessToken: token, username: username)
    clearLegacySession()
  }

  private static func clearLegacySession() {
    let defaults = UserDefaults.standard
    defaults.removeObject(forKey: legacyTokenKey)
    defaults.removeObject(forKey: legacyUsernameKey)
  }

  private static func read(account: String) -> String? {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: account,
      kSecReturnData: true,
      kSecMatchLimit: kSecMatchLimitOne
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data else {
      return nil
    }

    return String(data: data, encoding: .utf8)
  }

  private static func write(_ value: String, account: String) {
    let data = Data(value.utf8)
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: account
    ]

    let attributes: [CFString: Any] = [
      kSecValueData: data,
      kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ]

    let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      var createQuery = query
      createQuery[kSecValueData] = data
      createQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      SecItemAdd(createQuery as CFDictionary, nil)
    }
  }

  private static func delete(account: String) {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: account
    ]

    SecItemDelete(query as CFDictionary)
  }
}
