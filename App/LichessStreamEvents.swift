import Foundation

struct EventEnvelope: Decodable {
  var type: String
}

struct GameStartEvent: Decodable {
  var game: StartedGame
}

struct GameFinishEvent: Decodable {
  var game: FinishedGame
}

struct StartedGame: Decodable {
  var gameId: String
  var color: String
  var lastMove: String?
  var speed: String
  var status: Status?
  var opponent: Opponent
  var isMyTurn: Bool
  var secondsLeft: Int?
}

struct FinishedGame: Decodable {
  var gameId: String
}

struct GameFullEvent: Decodable {
  var id: String
  var initialFen: String
  var speed: String
  var white: GamePlayer
  var black: GamePlayer
  var clock: GameClock?
  var daysPerTurn: Int?
  var state: GameStateEvent
}

struct GamePlayer: Decodable {
  var name: String
  var rating: Int?
}

struct GameClock: Decodable {
  var initial: Int
  var increment: Int
}

struct GameStateEvent: Decodable {
  var type: String?
  var moves: String
  var wtime: Int?
  var btime: Int?
  var status: String
}

struct ChatLineEvent: Decodable {
  var username: String
  var text: String
  var room: String

  enum CodingKeys: String, CodingKey {
    case username = "username"
    case text
    case room
  }
}

struct OpponentGoneEvent: Decodable {
  var gone: Bool
}

struct Status: Decodable {
  var name: String
}

struct Opponent: Decodable {
  var id: String?
  var username: String?
  var rating: Int?
}

struct ChallengeEvent: Decodable {
  var challenge: IncomingChallenge
}

struct IncomingChallenge: Decodable {
  var id: String
  var rated: Bool
  var challenger: ChallengeUser
  var destUser: ChallengeUser?
  var timeControl: ChallengeTimeControl?
}

struct ChallengeUser: Decodable {
  var name: String
  var rating: Int?
}

struct ChallengeTimeControl: Decodable {
  var show: String
}

struct ChallengeCreateResponse: Decodable {
  var challenge: CreatedChallenge
}

struct CreatedChallenge: Decodable {
  var id: String
}
