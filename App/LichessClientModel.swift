import Foundation
import ChessKit

@Observable
@MainActor
final class LichessClientModel {
  var accessToken = ""
  var accountUsername = ""
  var streamState = StreamConnectionState.disconnected
  var activeGame = LichessGame.sample
  var isInGame = false
  var isSearching = false
  var isAuthenticating = false
  var authError: String?
  var challenges = LichessChallenge.samples
  var following = LichessFollowedPlayer.samples
  var onlineBots = LichessBotPlayer.samples
  var playerSearchText = ""
  var selectedSeekPreset = SeekPreset.defaults[0]
  var events = LichessEvent.samples
  var selectedRoom = ChatRoom.player
  var draftMessage = ""
  var selectedSquare: BoardSquare?
  var board = Board()
  var isSubmittingMove = false
  var isSendingChat = false
  var isSubmittingGameAction = false
  private var eventStreamTask: Task<Void, Never>?
  private var seekTask: Task<Void, Never>?
  private var gameStreamTask: Task<Void, Never>?
  private var seekTimeoutTask: Task<Void, Never>?

  init() {
    if let session = LichessAuthStore.loadSession() {
      accessToken = session.accessToken
      accountUsername = session.username
      streamState = .connected
      startEventStreamIfNeeded()
    }
  }

  var isConfigured: Bool {
    !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var accountLabel: String {
    accountUsername.isEmpty ? "Not signed in" : accountUsername
  }

  func signIn() async {
    guard !isAuthenticating else {
      return
    }

    isAuthenticating = true
    authError = nil

    do {
      let session = try await LichessOAuth.signIn()
      accessToken = session.accessToken
      accountUsername = session.username
      LichessAuthStore.saveSession(accessToken: session.accessToken, username: session.username)
      streamState = .connected
      events.insert(
        LichessEvent(title: "Signed in", detail: session.username, systemImage: "person.crop.circle.badge.checkmark"),
        at: 0
      )
      startEventStreamIfNeeded()
    } catch {
      authError = error.localizedDescription
      events.insert(
        LichessEvent(title: "Sign-in failed", detail: error.localizedDescription, systemImage: "exclamationmark.triangle"),
        at: 0
      )
    }

    isAuthenticating = false
  }

  func signOut() async {
    authError = nil
    let token = accessToken

    do {
      if !token.isEmpty {
        try await LichessOAuth.revoke(token: token)
      }
    } catch {
      authError = error.localizedDescription
    }

    accessToken = ""
    accountUsername = ""
    LichessAuthStore.clearSession()
    seekTask?.cancel()
    seekTask = nil
    seekTimeoutTask?.cancel()
    seekTimeoutTask = nil
    eventStreamTask?.cancel()
    eventStreamTask = nil
    gameStreamTask?.cancel()
    gameStreamTask = nil
    streamState = .disconnected
    isSearching = false
    events.insert(
      LichessEvent(title: "Signed out", detail: "Lichess authorization removed.", systemImage: "person.crop.circle.badge.xmark"),
      at: 0
    )
  }

  func refreshMockStream() {
    guard isConfigured else {
      streamState = .preview
      return
    }

    startEventStreamIfNeeded(forceRestart: true)
    events.insert(
      LichessEvent(
        title: "Stream ready",
        detail: "Event and game streams can be opened.",
        systemImage: "antenna.radiowaves.left.and.right"
      ),
      at: 0
    )
  }

  func seek(_ preset: SeekPreset) async {
    guard isConfigured else {
      streamState = .disconnected
      events.insert(
        LichessEvent(title: "Sign-in required", detail: "Sign in with Lichess before searching.", systemImage: "person.crop.circle"),
        at: 0
      )
      return
    }

    selectedSeekPreset = preset
    seekTask?.cancel()
    seekTimeoutTask?.cancel()
    startEventStreamIfNeeded()
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

    let request = api.seekRequest(preset: preset)
    seekTask = Task { [weak self] in
      guard let self else { return }
      do {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { return }
        if !(200..<300).contains(http.statusCode) {
          await self.handleSeekFailure(message: "Seek failed with status \(http.statusCode).")
          return
        }

        await self.recordEvent(title: "Seek opened", detail: preset.title, icon: "scope")
        for try await _ in bytes.lines {
          guard !Task.isCancelled else { return }
        }

        guard !Task.isCancelled else { return }
        await self.handleSeekFailure(message: "Seek closed before a game started. Try another preset or challenge a player directly.")
      } catch is CancellationError {
        return
      } catch {
        let message = if let urlError = error as? URLError {
          urlError.localizedDescription
        } else {
          error.localizedDescription
        }
        await self.handleSeekFailure(message: message)
      }
    }
    seekTimeoutTask = Task { [weak self] in
      guard let self else { return }
      do {
        try await Task.sleep(for: .seconds(90))
        guard !Task.isCancelled else { return }
        await self.handleSeekFailure(message: "No match found after 90 seconds. Try again or use a direct challenge.")
      } catch is CancellationError {
        return
      } catch {
        return
      }
    }
  }

  func cancelSeek() {
    seekTask?.cancel()
    seekTask = nil
    seekTimeoutTask?.cancel()
    seekTimeoutTask = nil
    isSearching = false
    events.insert(
      LichessEvent(title: "Seek canceled", detail: selectedSeekPreset.title, systemImage: "xmark.circle"),
      at: 0
    )
  }

  func refreshFollowing() async {
    guard isConfigured else {
      events.insert(
        LichessEvent(title: "Sign-in required", detail: "Sign in with Lichess to load following.", systemImage: "person.crop.circle"),
        at: 0
      )
      return
    }

    do {
      let (bytes, response) = try await URLSession.shared.bytes(for: api.followingRequest())
      guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        events.insert(
          LichessEvent(title: "Following refresh failed", detail: "Lichess rejected the request.", systemImage: "exclamationmark.triangle"),
          at: 0
        )
        return
      }

      var loadedPlayers: [LichessFollowedPlayer] = []
      for try await line in bytes.lines {
        guard let data = line.data(using: .utf8), !line.isEmpty else { continue }
        if let player = try? parseFollowedPlayer(from: data) {
          loadedPlayers.append(player)
        }
      }

      if !loadedPlayers.isEmpty {
        following = loadedPlayers
      }
      events.insert(
        LichessEvent(title: "Following updated", detail: "\(following.count) players", systemImage: "person.2"),
        at: 0
      )
    } catch {
      events.insert(
        LichessEvent(title: "Following refresh failed", detail: error.localizedDescription, systemImage: "exclamationmark.triangle"),
        at: 0
      )
    }
  }

  func selectSeekPreset(_ preset: SeekPreset) {
    selectedSeekPreset = preset
  }

  func challenge(_ player: LichessFollowedPlayer, preset: SeekPreset = SeekPreset.defaults[0]) async {
    guard isConfigured else {
      events.insert(
        LichessEvent(title: "Sign-in required", detail: "Sign in with Lichess before challenging \(player.username).", systemImage: "person.crop.circle"),
        at: 0
      )
      return
    }

    await sendChallenge(username: player.username, rating: player.rapidRating ?? 1500, preset: preset, icon: "paperplane")
  }

  func refreshOnlineBots() async {
    guard isConfigured else {
      events.insert(
        LichessEvent(title: "Sign-in required", detail: "Sign in with Lichess to load online bots.", systemImage: "person.crop.circle"),
        at: 0
      )
      return
    }

    do {
      let (bytes, response) = try await URLSession.shared.bytes(for: api.onlineBotsRequest())
      guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        events.insert(
          LichessEvent(title: "Bot list refresh failed", detail: "Lichess rejected the request.", systemImage: "exclamationmark.triangle"),
          at: 0
        )
        return
      }

      var loadedBots: [LichessBotPlayer] = []
      for try await line in bytes.lines {
        guard let data = line.data(using: .utf8), !line.isEmpty else { continue }
        if let bot = try? parseBotPlayer(from: data) {
          loadedBots.append(bot)
        }
      }

      if !loadedBots.isEmpty {
        onlineBots = loadedBots
      }
      events.insert(
        LichessEvent(title: "Online bots updated", detail: "\(onlineBots.count) bots", systemImage: "cpu"),
        at: 0
      )
    } catch {
      events.insert(
        LichessEvent(title: "Bot list refresh failed", detail: error.localizedDescription, systemImage: "exclamationmark.triangle"),
        at: 0
      )
    }
  }

  func challengeBot(_ bot: LichessBotPlayer, preset: SeekPreset? = nil) async {
    guard isConfigured else {
      events.insert(
        LichessEvent(title: "Sign-in required", detail: "Sign in with Lichess before challenging \(bot.username).", systemImage: "person.crop.circle"),
        at: 0
      )
      return
    }

    let chosenPreset = preset ?? selectedSeekPreset
    await sendChallenge(username: bot.username, rating: bot.rating ?? 1500, preset: chosenPreset, icon: "cpu")
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

    guard !isSubmittingMove else {
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

    guard !activeGame.id.isEmpty else {
      events.insert(
        LichessEvent(title: "Move blocked", detail: "No live game is connected.", systemImage: "exclamationmark.triangle"),
        at: 0
      )
      return
    }

    let move = outgoingMove(from: selectedSquare, to: square)
    isSubmittingMove = true
    events.insert(
      LichessEvent(title: "Sending move", detail: move, systemImage: "arrow.up.right.square"),
      at: 0
    )

    Task { [weak self] in
      guard let self else { return }
      do {
        let (_, response) = try await URLSession.shared.data(for: self.api.moveRequest(gameId: self.activeGame.id, move: move))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
          await self.recordEvent(title: "Move failed", detail: move, icon: "exclamationmark.triangle")
          await MainActor.run {
            self.isSubmittingMove = false
          }
          return
        }
        await MainActor.run {
          self.isSubmittingMove = false
        }
      } catch {
        await self.recordEvent(title: "Move failed", detail: error.localizedDescription, icon: "exclamationmark.triangle")
        await MainActor.run {
          self.isSubmittingMove = false
        }
      }
    }
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

    guard !activeGame.id.isEmpty, !isSendingChat else {
      return
    }

    isSendingChat = true
    let room = selectedRoom
    draftMessage = ""
    Task { [weak self] in
      guard let self else { return }
      do {
        let (_, response) = try await URLSession.shared.data(for: self.api.chatRequest(gameId: self.activeGame.id, room: room, text: text))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
          await self.recordEvent(title: "Chat failed", detail: text, icon: "exclamationmark.triangle")
          await MainActor.run {
            self.draftMessage = text
            self.isSendingChat = false
          }
          return
        }
        await self.recordEvent(title: "Chat sent", detail: text, icon: "paperplane")
        await MainActor.run {
          self.isSendingChat = false
        }
      } catch {
        await self.recordEvent(title: "Chat failed", detail: error.localizedDescription, icon: "exclamationmark.triangle")
        await MainActor.run {
          self.draftMessage = text
          self.isSendingChat = false
        }
      }
    }
  }

  func resign() {
    submitGameAction(title: "Resign", icon: "flag", request: api.resignRequest(gameId: activeGame.id))
  }

  func abort() {
    submitGameAction(title: "Abort", icon: "stop.circle", request: api.abortRequest(gameId: activeGame.id))
  }

  private func updateChallenge(_ challenge: LichessChallenge, status: ChallengeStatus) {
    guard let index = challenges.firstIndex(where: { $0.id == challenge.id }) else {
      return
    }

    challenges[index].status = status
  }

  private var api: LichessBoardAPI {
    LichessBoardAPI(accessToken: accessToken)
  }

  private func startEventStreamIfNeeded(forceRestart: Bool = false) {
    guard isConfigured else { return }
    if forceRestart {
      eventStreamTask?.cancel()
      eventStreamTask = nil
    }
    guard eventStreamTask == nil else { return }

    let request = api.eventStreamRequest()
    eventStreamTask = Task { [weak self] in
      guard let self else { return }
      do {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
          await self.recordEvent(title: "Event stream failed", detail: "Lichess rejected the event stream.", icon: "exclamationmark.triangle")
          return
        }

        for try await line in bytes.lines {
          guard !Task.isCancelled else { return }
          guard let data = line.data(using: .utf8), !line.isEmpty else { continue }
          await self.handleEventStreamLine(data)
        }
      } catch is CancellationError {
        return
      } catch {
        await self.recordEvent(title: "Event stream disconnected", detail: error.localizedDescription, icon: "exclamationmark.triangle")
      }
    }
  }

  private func handleEventStreamLine(_ data: Data) {
    guard let envelope = try? JSONDecoder().decode(EventEnvelope.self, from: data) else { return }
    switch envelope.type {
    case "gameStart":
      guard let event = try? JSONDecoder().decode(GameStartEvent.self, from: data) else { return }
      isSearching = false
      seekTask?.cancel()
      seekTask = nil
      seekTimeoutTask?.cancel()
      seekTimeoutTask = nil
      streamState = .connected
      activeGame = LichessGame(
        id: event.game.gameId,
        opponent: event.game.opponent.username,
        opponentRating: event.game.opponent.rating,
        myColor: event.game.color.capitalized,
        speed: event.game.speed.capitalized,
        status: event.game.status.name,
        whiteTime: formatSeconds(event.game.secondsLeft),
        blackTime: formatSeconds(event.game.secondsLeft),
        isMyTurn: event.game.isMyTurn,
        lastMove: event.game.lastMove,
        moves: event.game.lastMove.isEmpty ? [] : [event.game.lastMove],
        chat: []
      )
      isInGame = true
      startGameStream(gameID: event.game.gameId)
      events.insert(
        LichessEvent(title: "Game started", detail: "\(event.game.opponent.username) • \(event.game.speed.capitalized)", systemImage: "play.circle"),
        at: 0
      )
    case "challenge":
      guard let event = try? JSONDecoder().decode(ChallengeEvent.self, from: data) else { return }
      let newChallenge = LichessChallenge(
        id: event.challenge.id,
        opponent: event.challenge.destUser?.name ?? event.challenge.challenger.name,
        rating: event.challenge.challenger.rating ?? 1500,
        control: event.challenge.timeControl?.show ?? "Challenge",
        rated: event.challenge.rated,
        status: .pending
      )
      challenges.removeAll { $0.id == newChallenge.id }
      challenges.insert(newChallenge, at: 0)
      events.insert(
        LichessEvent(title: "Challenge received", detail: newChallenge.opponent, systemImage: "tray"),
        at: 0
      )
    case "challengeDeclined":
      guard let event = try? JSONDecoder().decode(ChallengeEvent.self, from: data) else { return }
      updateChallengeStatus(id: event.challenge.id, status: .declined)
      events.insert(
        LichessEvent(title: "Challenge declined", detail: event.challenge.destUser?.name ?? event.challenge.challenger.name, systemImage: "xmark.circle"),
        at: 0
      )
    case "challengeCanceled":
      guard let event = try? JSONDecoder().decode(ChallengeEvent.self, from: data) else { return }
      updateChallengeStatus(id: event.challenge.id, status: .canceled)
      events.insert(
        LichessEvent(title: "Challenge canceled", detail: event.challenge.destUser?.name ?? event.challenge.challenger.name, systemImage: "xmark.circle"),
        at: 0
      )
    case "gameFinish":
      guard let event = try? JSONDecoder().decode(GameFinishEvent.self, from: data) else { return }
      events.insert(
        LichessEvent(title: "Game finished", detail: event.game.gameId, systemImage: "flag.checkered"),
        at: 0
      )
    default:
      break
    }
  }

  private func sendChallenge(username: String, rating: Int, preset: SeekPreset, icon: String) async {
    do {
      let (data, response) = try await URLSession.shared.data(for: api.challengeRequest(username: username, preset: preset))
      guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        let message = String(data: data, encoding: .utf8) ?? "Challenge failed."
        events.insert(
          LichessEvent(title: "Challenge failed", detail: message, systemImage: "exclamationmark.triangle"),
          at: 0
        )
        return
      }

      let challengeID = (try? JSONDecoder().decode(ChallengeCreateResponse.self, from: data).challenge.id) ?? UUID().uuidString
      challenges.removeAll { $0.id == challengeID }
      challenges.insert(
        LichessChallenge(
          id: challengeID,
          opponent: username,
          rating: rating,
          control: preset.title,
          rated: preset.rated,
          status: .pending
        ),
        at: 0
      )
      events.insert(
        LichessEvent(title: "Challenge sent", detail: "\(username) • \(preset.title)", systemImage: icon),
        at: 0
      )
    } catch {
      events.insert(
        LichessEvent(title: "Challenge failed", detail: error.localizedDescription, systemImage: "exclamationmark.triangle"),
        at: 0
      )
    }
  }

  private func handleSeekFailure(message: String) {
    isSearching = false
    seekTask = nil
    seekTimeoutTask?.cancel()
    seekTimeoutTask = nil
    events.insert(
      LichessEvent(title: "Seek ended", detail: message, systemImage: "exclamationmark.triangle"),
      at: 0
    )
  }

  private func recordEvent(title: String, detail: String, icon: String) {
    events.insert(
      LichessEvent(title: title, detail: detail, systemImage: icon),
      at: 0
    )
  }

  private func parseBotPlayer(from data: Data) throws -> LichessBotPlayer {
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let id = json?["id"] as? String ?? UUID().uuidString
    let username = json?["username"] as? String ?? json?["name"] as? String ?? id
    let title = json?["title"] as? String ?? "BOT"
    let perfs = json?["perfs"] as? [String: Any]
    let rapid = perfs?["rapid"] as? [String: Any]
    let rating = rapid?["rating"] as? Int
    return LichessBotPlayer(id: id, username: username, rating: rating, online: true, title: title)
  }

  private func parseFollowedPlayer(from data: Data) throws -> LichessFollowedPlayer {
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

  private func formatSeconds(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let remainder = seconds % 60
    return String(format: "%02d:%02d", minutes, remainder)
  }

  private func startGameStream(gameID: String) {
    gameStreamTask?.cancel()
    let request = api.gameStreamRequest(gameId: gameID)
    gameStreamTask = Task { [weak self] in
      guard let self else { return }
      do {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
          await self.recordEvent(title: "Game stream failed", detail: "Lichess rejected the game stream.", icon: "exclamationmark.triangle")
          return
        }

        for try await line in bytes.lines {
          guard !Task.isCancelled else { return }
          guard let data = line.data(using: .utf8), !line.isEmpty else { continue }
          await self.handleGameStreamLine(data)
        }
      } catch is CancellationError {
        return
      } catch {
        await self.recordEvent(title: "Game stream disconnected", detail: error.localizedDescription, icon: "exclamationmark.triangle")
      }
    }
  }

  private func handleGameStreamLine(_ data: Data) {
    guard let envelope = try? JSONDecoder().decode(EventEnvelope.self, from: data) else { return }

    switch envelope.type {
    case "gameFull":
      guard let event = try? JSONDecoder().decode(GameFullEvent.self, from: data) else { return }
      let myColor = activeGame.myColor.lowercased() == "white" ? "white" : "black"
      let meIsWhite = myColor == "white"
      let opponentPlayer = meIsWhite ? event.black : event.white

      activeGame.id = event.id
      activeGame.opponent = opponentPlayer.name
      activeGame.opponentRating = opponentPlayer.rating ?? activeGame.opponentRating
      activeGame.speed = gameSpeedLabel(speed: event.speed, clock: event.clock, daysPerTurn: event.daysPerTurn)
      activeGame.status = event.state.status
      updateBoardState(initialFEN: event.initialFen, movesString: event.state.moves)
      updateClockState(
        state: event.state,
        meIsWhite: meIsWhite,
        fallbackInitial: event.clock?.initial ?? 0
      )
    case "gameState":
      guard let event = try? JSONDecoder().decode(GameStateEvent.self, from: data) else { return }
      let meIsWhite = activeGame.myColor.lowercased() == "white"
      activeGame.status = event.status
      updateBoardState(initialFEN: nil, movesString: event.moves)
      updateClockState(state: event, meIsWhite: meIsWhite, fallbackInitial: 0)
    case "chatLine":
      guard let line = try? JSONDecoder().decode(ChatLineEvent.self, from: data) else { return }
      let room = line.room == "spectator" ? ChatRoom.spectator : .player
      activeGame.chat.insert(ChatLine(user: line.username, text: line.text, room: room), at: 0)
    case "opponentGone":
      guard let event = try? JSONDecoder().decode(OpponentGoneEvent.self, from: data) else { return }
      let detail = event.gone ? "Opponent left the game." : "Opponent returned."
      events.insert(
        LichessEvent(title: "Presence update", detail: detail, systemImage: "person.crop.circle.badge.exclamationmark"),
        at: 0
      )
    default:
      break
    }
  }

  private func updateBoardState(initialFEN: String?, movesString: String) {
    let startingPosition: Position
    if let initialFEN, initialFEN != "startpos", let position = Position(fen: initialFEN) {
      startingPosition = position
    } else {
      startingPosition = .standard
    }

    var liveBoard = Board(position: startingPosition)
    let moves = movesString.split(separator: " ").map(String.init)
    for move in moves {
      apply(uciMove: move, to: &liveBoard)
    }

    board = liveBoard
    activeGame.moves = moves
    activeGame.lastMove = moves.last ?? ""
    activeGame.isMyTurn = board.position.sideToMove == (activeGame.myColor.lowercased() == "white" ? .white : .black)
  }

  private func apply(uciMove: String, to board: inout Board) {
    guard uciMove.count >= 4 else { return }
    let start = String(uciMove.prefix(2))
    let end = String(uciMove.dropFirst(2).prefix(2))
    let move = board.move(pieceAt: Square(start), to: Square(end))
    guard
      uciMove.count == 5,
      let move,
      case .promotion = board.state
    else {
      return
    }

    let promotionCode = uciMove.suffix(1)
    let kind: Piece.Kind
    switch promotionCode {
    case "q": kind = .queen
    case "r": kind = .rook
    case "b": kind = .bishop
    case "n": kind = .knight
    default: kind = .queen
    }
    board.completePromotion(of: move, to: kind)
  }

  private func updateClockState(state: GameStateEvent, meIsWhite: Bool, fallbackInitial: Int) {
    let whiteMillis = state.wtime ?? fallbackInitial
    let blackMillis = state.btime ?? fallbackInitial
    activeGame.whiteTime = formatMilliseconds(whiteMillis)
    activeGame.blackTime = formatMilliseconds(blackMillis)
    activeGame.isMyTurn = board.position.sideToMove == (meIsWhite ? .white : .black)
  }

  private func gameSpeedLabel(speed: String, clock: GameClock?, daysPerTurn: Int?) -> String {
    if let daysPerTurn {
      return "Correspondence \(daysPerTurn)d"
    }
    if let clock {
      let minutes = clock.initial / 60000
      return "\(speed.capitalized) \(minutes)+\(clock.increment)"
    }
    return speed.capitalized
  }

  private func formatMilliseconds(_ milliseconds: Int) -> String {
    formatSeconds(max(milliseconds / 1000, 0))
  }

  private func outgoingMove(from start: BoardSquare, to end: BoardSquare) -> String {
    let base = "\(start.uci)\(end.uci)"
    guard
      let piece = board.position.piece(at: Square(start.uci)),
      piece.kind == .pawn,
      (piece.color == .white && end.rank == 7) || (piece.color == .black && end.rank == 0)
    else {
      return base
    }
    return "\(base)q"
  }

  private func submitGameAction(title: String, icon: String, request: URLRequest) {
    guard !activeGame.id.isEmpty, !isSubmittingGameAction else {
      return
    }

    isSubmittingGameAction = true
    events.insert(
      LichessEvent(title: "\(title) requested", detail: activeGame.id, systemImage: icon),
      at: 0
    )

    Task { [weak self] in
      guard let self else { return }
      defer {
        Task { @MainActor in
          self.isSubmittingGameAction = false
        }
      }

      do {
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
          await self.recordEvent(title: "\(title) failed", detail: "Lichess rejected the request.", icon: "exclamationmark.triangle")
          return
        }
        await self.recordEvent(title: "\(title) sent", detail: activeGame.id, icon: icon)
      } catch {
        await self.recordEvent(title: "\(title) failed", detail: error.localizedDescription, icon: "exclamationmark.triangle")
      }
    }
  }

  private func updateChallengeStatus(id: String, status: ChallengeStatus) {
    guard let index = challenges.firstIndex(where: { $0.id == id }) else {
      return
    }
    challenges[index].status = status
  }
}

private struct EventEnvelope: Decodable {
  var type: String
}

private struct GameStartEvent: Decodable {
  var game: StartedGame
}

private struct GameFinishEvent: Decodable {
  var game: FinishedGame
}

private struct StartedGame: Decodable {
  var gameId: String
  var color: String
  var lastMove: String
  var speed: String
  var status: Status
  var opponent: Opponent
  var isMyTurn: Bool
  var secondsLeft: Int
}

private struct FinishedGame: Decodable {
  var gameId: String
}

private struct GameFullEvent: Decodable {
  var id: String
  var initialFen: String
  var speed: String
  var white: GamePlayer
  var black: GamePlayer
  var clock: GameClock?
  var daysPerTurn: Int?
  var state: GameStateEvent
}

private struct GamePlayer: Decodable {
  var name: String
  var rating: Int?
}

private struct GameClock: Decodable {
  var initial: Int
  var increment: Int
}

private struct GameStateEvent: Decodable {
  var type: String?
  var moves: String
  var wtime: Int?
  var btime: Int?
  var status: String
}

private struct ChatLineEvent: Decodable {
  var username: String
  var text: String
  var room: String

  enum CodingKeys: String, CodingKey {
    case username = "username"
    case text
    case room
  }
}

private struct OpponentGoneEvent: Decodable {
  var gone: Bool
}

private struct Status: Decodable {
  var name: String
}

private struct Opponent: Decodable {
  var username: String
  var rating: Int
}

private struct ChallengeEvent: Decodable {
  var challenge: IncomingChallenge
}

private struct IncomingChallenge: Decodable {
  var id: String
  var rated: Bool
  var challenger: ChallengeUser
  var destUser: ChallengeUser?
  var timeControl: ChallengeTimeControl?
}

private struct ChallengeUser: Decodable {
  var name: String
  var rating: Int?
}

private struct ChallengeTimeControl: Decodable {
  var show: String
}

private struct ChallengeCreateResponse: Decodable {
  var challenge: CreatedChallenge
}

private struct CreatedChallenge: Decodable {
  var id: String
}
