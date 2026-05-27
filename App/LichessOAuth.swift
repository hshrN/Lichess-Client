import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

struct LichessOAuthSession {
  var accessToken: String
  var username: String
}

enum LichessOAuthError: LocalizedError {
  case invalidAuthorizationCallback
  case missingAuthorizationCode
  case invalidState
  case tokenExchangeFailed
  case profileFetchFailed

  var errorDescription: String? {
    switch self {
    case .invalidAuthorizationCallback:
      return "Lichess returned an invalid authorization callback."
    case .missingAuthorizationCode:
      return "Lichess did not return an authorization code."
    case .invalidState:
      return "The Lichess authorization state did not match."
    case .tokenExchangeFailed:
      return "The Lichess token exchange failed."
    case .profileFetchFailed:
      return "The signed-in Lichess profile could not be loaded."
    }
  }
}

enum LichessOAuth {
  static let host = URL(string: "https://lichess.org")!
  static let clientID = Bundle.main.bundleIdentifier ?? "app.bitrig.lichess-board"
  static let callbackScheme = Bundle.main.bundleIdentifier ?? "app.bitrig.lichess-board"
  static let redirectURI = "\(callbackScheme)://oauth-callback"
  static let scopes = ["board:play", "challenge:read", "challenge:write"]

  static func signIn() async throws -> LichessOAuthSession {
    let verifier = PKCE.codeVerifier()
    let challenge = PKCE.codeChallenge(for: verifier)
    let state = PKCE.state()
    let authURL = try authorizeURL(codeChallenge: challenge, state: state)
    let callbackURL = try await OAuthSessionRunner().authorize(with: authURL, callbackScheme: callbackScheme)

    let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
    let code = components?.queryItems?.first(where: { $0.name == "code" })?.value
    let returnedState = components?.queryItems?.first(where: { $0.name == "state" })?.value

    guard returnedState == state else {
      throw LichessOAuthError.invalidState
    }
    guard let code else {
      throw LichessOAuthError.missingAuthorizationCode
    }

    let token = try await exchangeCode(code: code, verifier: verifier)
    let username = try await fetchUsername(token: token)
    return LichessOAuthSession(accessToken: token, username: username)
  }

  static func revoke(token: String) async throws {
    var request = URLRequest(url: host.appending(path: "/api/token"))
    request.httpMethod = "DELETE"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    let (_, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
      throw LichessOAuthError.tokenExchangeFailed
    }
  }

  private static func authorizeURL(codeChallenge: String, state: String) throws -> URL {
    var components = URLComponents(url: host.appending(path: "/oauth"), resolvingAgainstBaseURL: false)
    components?.queryItems = [
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "client_id", value: clientID),
      URLQueryItem(name: "redirect_uri", value: redirectURI),
      URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
      URLQueryItem(name: "code_challenge", value: codeChallenge),
      URLQueryItem(name: "code_challenge_method", value: "S256"),
      URLQueryItem(name: "state", value: state)
    ]

    guard let url = components?.url else {
      throw LichessOAuthError.invalidAuthorizationCallback
    }
    return url
  }

  private static func exchangeCode(code: String, verifier: String) async throws -> String {
    var request = URLRequest(url: host.appending(path: "/api/token"))
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

    request.httpBody = formEncodedBody([
      URLQueryItem(name: "grant_type", value: "authorization_code"),
      URLQueryItem(name: "code", value: code),
      URLQueryItem(name: "redirect_uri", value: redirectURI),
      URLQueryItem(name: "client_id", value: clientID),
      URLQueryItem(name: "code_verifier", value: verifier)
    ])

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
      throw LichessOAuthError.tokenExchangeFailed
    }

    let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
    return tokenResponse.accessToken
  }

  private static func fetchUsername(token: String) async throws -> String {
    var request = URLRequest(url: host.appending(path: "/api/account"))
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
      throw LichessOAuthError.profileFetchFailed
    }

    let profile = try JSONDecoder().decode(AccountProfile.self, from: data)
    return profile.username
  }

  private static func formEncodedBody(_ items: [URLQueryItem]) -> Data? {
    var components = URLComponents()
    components.queryItems = items
    return components.percentEncodedQuery?.data(using: .utf8)
  }
}

private final class OAuthSessionRunner: NSObject, ASWebAuthenticationPresentationContextProviding {
  func authorize(with url: URL, callbackScheme: String) async throws -> URL {
    try await withCheckedThrowingContinuation { continuation in
      let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
        if let callbackURL {
          continuation.resume(returning: callbackURL)
        } else {
          continuation.resume(throwing: error ?? LichessOAuthError.invalidAuthorizationCallback)
        }
      }
      session.presentationContextProvider = self
      session.prefersEphemeralWebBrowserSession = false
      session.start()
      SessionHolder.shared.session = session
    }
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
  }
}

private final class SessionHolder {
  static let shared = SessionHolder()
  var session: ASWebAuthenticationSession?
}

private struct TokenResponse: Decodable {
  var accessToken: String

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
  }
}

private struct AccountProfile: Decodable {
  var username: String
}

private enum PKCE {
  static func codeVerifier() -> String {
    randomURLSafeString(length: 64)
  }

  static func state() -> String {
    randomURLSafeString(length: 32)
  }

  static func codeChallenge(for verifier: String) -> String {
    let digest = SHA256.hash(data: Data(verifier.utf8))
    return Data(digest).base64URLEncodedString()
  }

  private static func randomURLSafeString(length: Int) -> String {
    let allowed = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
    return String((0..<length).map { _ in allowed.randomElement() ?? "a" })
  }
}

private extension Data {
  func base64URLEncodedString() -> String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
