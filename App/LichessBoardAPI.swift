import Foundation

struct LichessBoardAPI {
  var baseURL = URL(string: "https://lichess.org")!
  var accessToken: String

  func eventStreamRequest() -> URLRequest {
    authenticatedRequest(path: "/api/stream/event")
  }

  func gameStreamRequest(gameId: String) -> URLRequest {
    authenticatedRequest(path: "/api/board/game/stream/\(gameId)")
  }

  func moveRequest(gameId: String, move: String, offeringDraw: Bool = false) -> URLRequest {
    var components = URLComponents(url: baseURL.appending(path: "/api/board/game/\(gameId)/move/\(move)"), resolvingAgainstBaseURL: false)!
    components.queryItems = [URLQueryItem(name: "offeringDraw", value: offeringDraw ? "true" : "false")]
    var request = URLRequest(url: components.url!)
    request.httpMethod = "POST"
    applyAuth(to: &request)
    return request
  }

  func seekRequest(preset: SeekPreset) -> URLRequest {
    var request = authenticatedRequest(path: "/api/board/seek")
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = formBody(for: seekItems(preset: preset))
    return request
  }

  func followingRequest() -> URLRequest {
    authenticatedRequest(path: "/api/rel/following")
  }

  func challengesRequest() -> URLRequest {
    var request = authenticatedRequest(path: "/api/challenge")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    return request
  }

  func challengeRequest(username: String, preset: SeekPreset) -> URLRequest {
    var request = authenticatedRequest(path: "/api/challenge/\(username)")
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.httpBody = formBody(for: challengeItems(preset: preset))
    return request
  }

  func onlineBotsRequest(limit: Int = 20) -> URLRequest {
    var components = URLComponents(url: baseURL.appending(path: "/api/bot/online"), resolvingAgainstBaseURL: false)!
    components.queryItems = [URLQueryItem(name: "nb", value: "\(limit)")]
    var request = URLRequest(url: components.url!)
    request.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")
    applyAuth(to: &request)
    return request
  }

  func acceptChallengeRequest(challengeId: String) -> URLRequest {
    postRequest(path: "/api/challenge/\(challengeId)/accept")
  }

  func declineChallengeRequest(challengeId: String, reason: ChallengeDeclineReason = .generic) -> URLRequest {
    var request = postRequest(path: "/api/challenge/\(challengeId)/decline")
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = formBody(for: [URLQueryItem(name: "reason", value: reason.rawValue)])
    return request
  }

  private func authenticatedRequest(path: String) -> URLRequest {
    var request = URLRequest(url: baseURL.appending(path: path))
    request.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")
    applyAuth(to: &request)
    return request
  }

  private func postRequest(path: String) -> URLRequest {
    var request = authenticatedRequest(path: path)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    return request
  }

  private func applyAuth(to request: inout URLRequest) {
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
  }

  private func seekItems(preset: SeekPreset) -> [URLQueryItem] {
    var items = commonChallengeItems(preset: preset)

    if let time = preset.time, let increment = preset.increment {
      items.append(URLQueryItem(name: "time", value: "\(time)"))
      items.append(URLQueryItem(name: "increment", value: "\(increment)"))
    }

    if let days = preset.days {
      items.append(URLQueryItem(name: "days", value: "\(days)"))
    }

    return items
  }

  private func challengeItems(preset: SeekPreset) -> [URLQueryItem] {
    var items = commonChallengeItems(preset: preset)

    if let time = preset.time, let increment = preset.increment {
      items.append(URLQueryItem(name: "clock.limit", value: "\(time * 60)"))
      items.append(URLQueryItem(name: "clock.increment", value: "\(increment)"))
    }

    if let days = preset.days {
      items.append(URLQueryItem(name: "days", value: "\(days)"))
    }

    return items
  }

  private func commonChallengeItems(preset: SeekPreset) -> [URLQueryItem] {
    [
      URLQueryItem(name: "rated", value: preset.rated ? "true" : "false"),
      URLQueryItem(name: "variant", value: "standard"),
      URLQueryItem(name: "color", value: preset.color.rawValue)
    ]
  }

  private func formBody(for items: [URLQueryItem]) -> Data? {
    var body = URLComponents()
    body.queryItems = items
    return body.percentEncodedQuery?.data(using: String.Encoding.utf8)
  }
}
