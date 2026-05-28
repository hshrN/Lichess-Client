import Foundation

enum LichessPlayerParser {
  static func parseBotPlayer(from data: Data) throws -> LichessBotPlayer {
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let id = json?["id"] as? String ?? UUID().uuidString
    let username = json?["username"] as? String ?? json?["name"] as? String ?? id
    let title = json?["title"] as? String ?? "BOT"
    let perfs = json?["perfs"] as? [String: Any]
    let rapid = perfs?["rapid"] as? [String: Any]
    let rating = rapid?["rating"] as? Int
    return LichessBotPlayer(id: id, username: username, rating: rating, online: true, title: title)
  }

  static func parseFollowedPlayer(from data: Data) throws -> LichessFollowedPlayer {
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let id = json?["id"] as? String ?? UUID().uuidString
    let username = json?["name"] as? String ?? json?["username"] as? String ?? id
    let perfs = json?["perfs"] as? [String: Any]
    let rapid = perfs?["rapid"] as? [String: Any]
    let rating = rapid?["rating"] as? Int
    let online = json?["online"] as? Bool ?? false
    let url = "https://lichess.org/@/\(username)"
    return LichessFollowedPlayer(id: id, username: username, rapidRating: rating, online: online, url: url)
  }
}
