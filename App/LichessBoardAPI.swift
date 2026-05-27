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

    var items = [
      URLQueryItem(name: "rated", value: preset.rated ? "true" : "false"),
      URLQueryItem(name: "variant", value: "standard"),
      URLQueryItem(name: "color", value: preset.color.rawValue)
    ]

    if let time = preset.time, let increment = preset.increment {
      items.append(URLQueryItem(name: "time", value: "\(time)"))
      items.append(URLQueryItem(name: "increment", value: "\(increment)"))
    }

    if let days = preset.days {
      items.append(URLQueryItem(name: "days", value: "\(days)"))
    }

    var body = URLComponents()
    body.queryItems = items
    request.httpBody = body.percentEncodedQuery?.data(using: String.Encoding.utf8)
    return request
  }

  private func authenticatedRequest(path: String) -> URLRequest {
    var request = URLRequest(url: baseURL.appending(path: path))
    request.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")
    applyAuth(to: &request)
    return request
  }

  private func applyAuth(to request: inout URLRequest) {
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
  }
}
