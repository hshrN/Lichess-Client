import Foundation

enum ClientSection: String, CaseIterable, Identifiable {
  case game
  case settings

  var id: String { rawValue }

  var title: String {
    switch self {
    case .game: "Game"
    case .settings: "Token"
    }
  }

  var systemImage: String {
    switch self {
    case .game: "checkerboard.rectangle"
    case .settings: "key"
    }
  }
}

enum StreamConnectionState: String {
  case disconnected
  case preview
  case connected

  var title: String {
    switch self {
    case .disconnected: "Disconnected"
    case .preview: "Preview"
    case .connected: "Connected"
    }
  }
}

enum ChatRoom: String, CaseIterable, Identifiable {
  case player
  case spectator

  var id: String { rawValue }

  var title: String {
    switch self {
    case .player: "Player"
    case .spectator: "Spectator"
    }
  }
}

enum ChallengeStatus: String {
  case pending
  case accepted
  case declined

  var title: String {
    switch self {
    case .pending: "Pending"
    case .accepted: "Accepted"
    case .declined: "Declined"
    }
  }
}

enum SeekColor: String, CaseIterable, Identifiable {
  case random
  case white
  case black

  var id: String { rawValue }

  var title: String {
    switch self {
    case .random: "Random"
    case .white: "White"
    case .black: "Black"
    }
  }
}

struct LichessGame {
  var id: String
  var opponent: String
  var opponentRating: Int
  var myColor: String
  var speed: String
  var status: String
  var whiteTime: String
  var blackTime: String
  var isMyTurn: Bool
  var lastMove: String
  var moves: [String]
  var chat: [ChatLine]

  static var sample: LichessGame {
    LichessGame(
      id: "BEOucQJo",
      opponent: "mary",
      opponentRating: 1021,
      myColor: "White",
      speed: "Rapid 15+0",
      status: "started",
      whiteTime: "15:00",
      blackTime: "15:00",
      isMyTurn: true,
      lastMove: "d2d3",
      moves: ["d2d3"],
      chat: [
        ChatLine(user: "lichess", text: "Good luck, have fun.", room: .player),
        ChatLine(user: "mary", text: "Hi!", room: .player)
      ]
    )
  }
}

struct LichessChallenge: Identifiable {
  var id: String
  var opponent: String
  var rating: Int
  var control: String
  var rated: Bool
  var status: ChallengeStatus

  static var samples: [LichessChallenge] {
    [
      LichessChallenge(id: "c1", opponent: "bobby", rating: 1751, control: "15+10 Rapid", rated: false, status: .pending),
      LichessChallenge(id: "c2", opponent: "aaron", rating: 797, control: "3 days", rated: true, status: .pending)
    ]
  }
}

struct LichessEvent: Identifiable {
  var id = UUID()
  var title: String
  var detail: String
  var systemImage: String

  static var samples: [LichessEvent] {
    [
      LichessEvent(title: "Game stream", detail: "Waiting for gameFull event.", systemImage: "dot.radiowaves.left.and.right"),
      LichessEvent(title: "Board API", detail: "Rapid, Classical, and Correspondence are ready.", systemImage: "checkerboard.shield")
    ]
  }
}

struct ChatLine: Identifiable {
  var id = UUID()
  var user: String
  var text: String
  var room: ChatRoom
}

struct SeekPreset: Identifiable {
  var id = UUID()
  var title: String
  var time: Int?
  var increment: Int?
  var days: Int?
  var rated: Bool
  var color: SeekColor

  static var defaults: [SeekPreset] {
    [
      SeekPreset(title: "Rapid 10+5", time: 10, increment: 5, days: nil, rated: false, color: .random),
      SeekPreset(title: "Rapid 15+10", time: 15, increment: 10, days: nil, rated: false, color: .random),
      SeekPreset(title: "Rapid 25+10", time: 25, increment: 10, days: nil, rated: true, color: .random)
    ]
  }
}

struct BoardSquare: Hashable {
  var file: Int
  var rank: Int

  var id: String { uci }

  var uci: String {
    let fileName = String(UnicodeScalar(97 + file) ?? "a")
    return "\(fileName)\(rank + 1)"
  }
}
