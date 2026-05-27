import Foundation

@Observable
final class LichessClientModel {
  var accessToken = ""
  var streamState = StreamConnectionState.disconnected
  var activeGame = LichessGame.sample
  var challenges = LichessChallenge.samples
  var events = LichessEvent.samples
  var selectedRoom = ChatRoom.player
  var draftMessage = ""
  var selectedSquare: BoardSquare?

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
    events.insert(
      LichessEvent(
        title: "Seek prepared",
        detail: "\(preset.title), \(preset.rated ? "rated" : "casual"), \(preset.color.title.lowercased()).",
        systemImage: "scope"
      ),
      at: 0
    )
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
      selectedSquare = square
      return
    }

    defer { self.selectedSquare = nil }

    guard selectedSquare != square else {
      return
    }

    let move = "\(selectedSquare.uci)\(square.uci)"
    activeGame.lastMove = move
    activeGame.moves.append(move)
    activeGame.isMyTurn.toggle()
    events.insert(
      LichessEvent(title: "Move staged", detail: move, systemImage: "arrow.up.right.square")
      , at: 0
    )
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
