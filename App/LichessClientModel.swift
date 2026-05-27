import Foundation
import ChessKit

@Observable
final class LichessClientModel {
  var accessToken = ""
  var streamState = StreamConnectionState.disconnected
  var activeGame = LichessGame.sample
  var isInGame = false
  var isSearching = false
  var challenges = LichessChallenge.samples
  var following = LichessFollowedPlayer.samples
  var playerSearchText = ""
  var selectedSeekPreset = SeekPreset.defaults[0]
  var events = LichessEvent.samples
  var selectedRoom = ChatRoom.player
  var draftMessage = ""
  var selectedSquare: BoardSquare?
  var board = Board()

  var isConfigured: Bool {
    !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  func refreshMockStream() {
    streamState = isConfigured ? .connected : .preview
    events.insert(
      LichessEvent(
        title: "Stream ready",
        detail: isConfigured ? "Event and game streams can be opened." : "Add an API token to connect.",
        systemImage: isConfigured ? "antenna.radiowaves.left.and.right" : "eye"
      ),
      at: 0
    )
  }

  func seek(_ preset: SeekPreset) {
    guard isConfigured else {
      streamState = .disconnected
      events.insert(
        LichessEvent(title: "Token required", detail: "Add a Lichess API token before searching.", systemImage: "key")
        , at: 0
      )
      return
    }

    isSearching = true
    streamState = .connected
    events.insert(
      LichessEvent(
        title: "Searching rapid",
        detail: "\(preset.title), \(preset.rated ? "rated" : "casual").",
        systemImage: "scope"
      ),
      at: 0
    )
  }

  func refreshFollowing() {
    guard isConfigured else {
      events.insert(
        LichessEvent(title: "Token required", detail: "Add a token to load following.", systemImage: "key"),
        at: 0
      )
      return
    }

    events.insert(
      LichessEvent(title: "Following refresh queued", detail: "/api/rel/following", systemImage: "person.2"),
      at: 0
    )
  }

  func selectSeekPreset(_ preset: SeekPreset) {
    selectedSeekPreset = preset
  }

  func challenge(_ player: LichessFollowedPlayer, preset: SeekPreset = SeekPreset.defaults[0]) {
    guard isConfigured else {
      events.insert(
        LichessEvent(title: "Token required", detail: "Add a token before challenging \(player.username).", systemImage: "key"),
        at: 0
      )
      return
    }

    challenges.insert(
      LichessChallenge(
        id: UUID().uuidString,
        opponent: player.username,
        rating: player.rapidRating ?? 1500,
        control: preset.title,
        rated: preset.rated,
        status: .pending
      ),
      at: 0
    )
    events.insert(
      LichessEvent(title: "Challenge queued", detail: "\(player.username), \(preset.title)", systemImage: "paperplane"),
      at: 0
    )
  }

  func openPreviewGame() {
    isSearching = false
    isInGame = true
    activeGame.status = "started"
  }

  func returnHome() {
    isInGame = false
    isSearching = false
    selectedSquare = nil
  }

  func accept(_ challenge: LichessChallenge) {
    updateChallenge(challenge, status: .accepted)
    events.insert(
      LichessEvent(title: "Challenge accepted", detail: challenge.opponent, systemImage: "checkmark.circle")
      , at: 0
    )
  }

  func decline(_ challenge: LichessChallenge) {
    updateChallenge(challenge, status: .declined)
    events.insert(
      LichessEvent(title: "Challenge declined", detail: challenge.opponent, systemImage: "xmark.circle")
      , at: 0
    )
  }

  func playMove(to square: BoardSquare) {
    guard let selectedSquare else {
      if pieceSymbol(at: square) != nil {
        self.selectedSquare = square
      }
      return
    }

    defer { self.selectedSquare = nil }

    guard selectedSquare != square else {
      return
    }

    let start = Square(selectedSquare.uci)
    let end = Square(square.uci)
    guard board.canMove(pieceAt: start, to: end) else {
      events.insert(
        LichessEvent(title: "Illegal move", detail: "\(selectedSquare.uci)\(square.uci)", systemImage: "exclamationmark.triangle"),
        at: 0
      )
      return
    }

    board.move(pieceAt: start, to: end)
    let move = "\(selectedSquare.uci)\(square.uci)"
    activeGame.lastMove = move
    activeGame.moves.append(move)
    activeGame.isMyTurn.toggle()
    events.insert(
      LichessEvent(title: "Move staged", detail: move, systemImage: "arrow.up.right.square")
      , at: 0
    )
  }

  func legalDestinations(for square: BoardSquare) -> Set<BoardSquare> {
    Set(
      board.legalMoves(forPieceAt: Square(square.uci)).map {
        BoardSquare(file: $0.file.number - 1, rank: $0.rank.value - 1)
      }
    )
  }

  func pieceSymbol(at square: BoardSquare) -> String? {
    guard let piece = board.position.piece(at: Square(square.uci)) else {
      return nil
    }

    return switch (piece.color, piece.kind) {
    case (.white, .king): "♔"
    case (.white, .queen): "♕"
    case (.white, .rook): "♖"
    case (.white, .bishop): "♗"
    case (.white, .knight): "♘"
    case (.white, .pawn): "♙"
    case (.black, .king): "♚"
    case (.black, .queen): "♛"
    case (.black, .rook): "♜"
    case (.black, .bishop): "♝"
    case (.black, .knight): "♞"
    case (.black, .pawn): "♟"
    }
  }

  func sendChat() {
    let text = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else {
      return
    }

    activeGame.chat.insert(
      ChatLine(user: "You", text: text, room: selectedRoom),
      at: 0
    )
    draftMessage = ""
  }

  func resign() {
    activeGame.status = "resigning"
    events.insert(
      LichessEvent(title: "Resign action queued", detail: activeGame.id, systemImage: "flag")
      , at: 0
    )
  }

  func abort() {
    activeGame.status = "aborting"
    events.insert(
      LichessEvent(title: "Abort action queued", detail: activeGame.id, systemImage: "stop.circle")
      , at: 0
    )
  }

  private func updateChallenge(_ challenge: LichessChallenge, status: ChallengeStatus) {
    guard let index = challenges.firstIndex(where: { $0.id == challenge.id }) else {
      return
    }

    challenges[index].status = status
  }
}
