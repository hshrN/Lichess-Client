import Foundation
import ChessKit

@Observable
@MainActor
final class LichessClientModel {
  enum PendingDirectChallengeKind {
    case player
    case bot
  }

  var accessToken = ""
  var accountUsername = ""
  var streamState = StreamConnectionState.disconnected
  var activeGame = LichessGame.sample
  var isInGame = false
  var hasLoadedGameState = false
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
  var isBoardFlipped = false
  var board = Board()
  var isSubmittingMove = false
  var isSendingChat = false
  var isSubmittingGameAction = false
  var isSubmittingChallengeAction = false
  var isSendingDirectChallenge = false
  var pendingDirectChallengeOpponent: String?
  var pendingDirectChallengeLabel: String?
  var pendingDirectChallengeKind: PendingDirectChallengeKind?
  var opponentPresenceMessage: String?
  var canClaimVictory = false
  var canClaimDraw = false
  private var activeInitialFEN: String?
  private var pendingSubmittedMove: String?
  private var eventStreamTask: Task<Void, Never>?
  private var seekTask: Task<Void, Never>?
  private var gameStreamTask: Task<Void, Never>?
  private var seekTimeoutTask: Task<Void, Never>?
  private var eventStreamRunID = UUID()

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

  var chessBoardState: ChessBoardState {
    ChessBoardState(
      board: board,
      selectedSquare: selectedSquare.map(chessSquare),
      legalTargets: selectedSquare.map { Set(board.legalMoves(forPieceAt: chessSquare($0))) } ?? [],
      lastMove: activeGame.lastMove.count >= 4 ? ChessBoardMoveHighlight(
        start: Square(String(activeGame.lastMove.prefix(2))),
        end: Square(String(activeGame.lastMove.dropFirst(2).prefix(2)))
      ) : nil,
      checkedKingSquare: checkedKingSquare,
      isFlipped: isBoardFlipped
    )
  }

  var checkedKingSquare: Square? {
    switch board.state {
    case .check(let color), .checkmate(let color):
      board.position.pieces.first { $0.kind == .king && $0.color == color }?.square
    case .active, .draw, .promotion:
      nil
    }
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
    isSendingDirectChallenge = false
    pendingDirectChallengeOpponent = nil
    pendingDirectChallengeLabel = nil
    pendingDirectChallengeKind = nil
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

    guard !isSendingDirectChallenge else {
      events.insert(
        LichessEvent(title: "Challenge pending", detail: pendingDirectChallengeLabel ?? "Wait for the current challenge to resolve.", systemImage: "clock"),
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
        await self.handleSeekClosure()
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
        if let player = try? LichessPlayerParser.parseFollowedPlayer(from: data) {
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

    await sendChallenge(username: player.username, rating: player.rapidRating ?? 1500, preset: preset, icon: "paperplane", kind: .player)
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
        if let bot = try? LichessPlayerParser.parseBotPlayer(from: data) {
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
    await sendChallenge(username: bot.username, rating: bot.rating ?? 1500, preset: chosenPreset, icon: "cpu", kind: .bot)
  }

  func openPreviewGame() {
    isSearching = false
    isInGame = true
    hasLoadedGameState = true
    activeGame.status = "started"
  }

  func returnHome() {
    isInGame = false
    hasLoadedGameState = false
    isSearching = false
    isSendingDirectChallenge = false
    pendingDirectChallengeOpponent = nil
    pendingDirectChallengeLabel = nil
    pendingDirectChallengeKind = nil
    selectedSquare = nil
    activeInitialFEN = nil
    opponentPresenceMessage = nil
    canClaimVictory = false
    canClaimDraw = false
  }

  func flipBoard() {
    isBoardFlipped.toggle()
  }

  func accept(_ challenge: LichessChallenge) {
    submitChallengeDecision(
      challenge,
      title: "Challenge accepted",
      status: .accepted,
      icon: "checkmark.circle",
      request: api.acceptChallengeRequest(challengeId: challenge.id)
    )
  }

  func decline(_ challenge: LichessChallenge) {
    submitChallengeDecision(
      challenge,
      title: "Challenge declined",
      status: .declined,
      icon: "xmark.circle",
      request: api.declineChallengeRequest(challengeId: challenge.id)
    )
  }

  func playMove(to square: BoardSquare) {
    guard hasLoadedGameState else {
      events.insert(
        LichessEvent(title: "Board syncing", detail: "Wait for the live game state before making a move.", systemImage: "hourglass"),
        at: 0
      )
      return
    }

    guard activeGame.status == "started" else {
      events.insert(
        LichessEvent(title: "Move blocked", detail: "This game is not currently active.", systemImage: "exclamationmark.triangle"),
        at: 0
      )
      return
    }

    guard activeGame.isMyTurn else {
      events.insert(
        LichessEvent(title: "Move blocked", detail: "It is not your turn.", systemImage: "hand.raised"),
        at: 0
      )
      return
    }

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
    guard let move = LichessBoardPositionBuilder.outgoingMoveUCI(from: start, to: end, on: board) else {
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
          self.applyConfirmedLocalMove(move)
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

  func selectBoardSquare(_ square: Square) {
    playMove(to: boardSquare(square))
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

  func offerDraw() {
    submitGameAction(title: "Draw offer", icon: "equal.circle", request: api.drawRequest(gameId: activeGame.id, accept: true))
  }

  func requestTakeback() {
    submitGameAction(title: "Takeback", icon: "arrow.uturn.backward.circle", request: api.takebackRequest(gameId: activeGame.id, accept: true))
  }

  func claimVictory() {
    submitGameAction(title: "Claim victory", icon: "crown", request: api.claimVictoryRequest(gameId: activeGame.id))
  }

  func claimDraw() {
    submitGameAction(title: "Claim draw", icon: "equal.square", request: api.claimDrawRequest(gameId: activeGame.id))
  }

  func berserk() {
    submitGameAction(title: "Berserk", icon: "bolt", request: api.berserkRequest(gameId: activeGame.id))
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
    let runID = UUID()
    eventStreamRunID = runID
    eventStreamTask = Task { [weak self] in
      guard let self else { return }
      defer {
        Task { @MainActor in
          if self.eventStreamRunID == runID {
            self.eventStreamTask = nil
          }
        }
      }

      do {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
          await self.recordEvent(title: "Event stream failed", detail: "Lichess rejected the event stream.", icon: "exclamationmark.triangle")
          return
        }
        await MainActor.run {
          self.streamState = .connected
        }
        await self.recordEvent(title: "Event stream open", detail: "Waiting for game and challenge events.", icon: "antenna.radiowaves.left.and.right")

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
      let startedOpponent = event.game.opponent.username ?? event.game.opponent.id
      if pendingDirectChallengeKind == .bot, pendingDirectChallengeOpponent == startedOpponent {
        isSendingDirectChallenge = false
        pendingDirectChallengeOpponent = nil
        pendingDirectChallengeLabel = nil
        pendingDirectChallengeKind = nil
        events.insert(
          LichessEvent(title: "Bot challenge ignored", detail: startedOpponent ?? "Bot", systemImage: "cpu"),
          at: 0
        )
        return
      }
      isSearching = false
      isSendingDirectChallenge = false
      pendingDirectChallengeOpponent = nil
      pendingDirectChallengeLabel = nil
      pendingDirectChallengeKind = nil
      seekTask?.cancel()
      seekTask = nil
      seekTimeoutTask?.cancel()
      seekTimeoutTask = nil
      streamState = .connected
      activeGame = LichessGame(
        id: event.game.gameId,
        opponent: event.game.opponent.username ?? event.game.opponent.id ?? "Opponent",
        opponentRating: event.game.opponent.rating ?? 1500,
        myColor: event.game.color.capitalized,
        speed: event.game.speed.capitalized,
        status: event.game.status?.name ?? "started",
        whiteTime: formatSeconds(event.game.secondsLeft ?? 0),
        blackTime: formatSeconds(event.game.secondsLeft ?? 0),
        isMyTurn: event.game.isMyTurn,
        lastMove: event.game.lastMove ?? "",
        moves: event.game.lastMove.map { $0.isEmpty ? [] : [$0] } ?? [],
        chat: []
      )
      isInGame = true
      hasLoadedGameState = false
      activeInitialFEN = nil
      opponentPresenceMessage = nil
      canClaimVictory = false
      canClaimDraw = false
      startGameStream(gameID: event.game.gameId)
      events.insert(
        LichessEvent(title: "Game started", detail: "\((event.game.opponent.username ?? event.game.opponent.id) ?? "Opponent") • \(event.game.speed.capitalized)", systemImage: "play.circle"),
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
      if pendingDirectChallengeOpponent == event.challenge.destUser?.name || pendingDirectChallengeOpponent == event.challenge.challenger.name {
        isSendingDirectChallenge = false
        pendingDirectChallengeOpponent = nil
        pendingDirectChallengeLabel = nil
        pendingDirectChallengeKind = nil
      }
      events.insert(
        LichessEvent(title: "Challenge declined", detail: event.challenge.destUser?.name ?? event.challenge.challenger.name, systemImage: "xmark.circle"),
        at: 0
      )
    case "challengeCanceled":
      guard let event = try? JSONDecoder().decode(ChallengeEvent.self, from: data) else { return }
      updateChallengeStatus(id: event.challenge.id, status: .canceled)
      if pendingDirectChallengeOpponent == event.challenge.destUser?.name || pendingDirectChallengeOpponent == event.challenge.challenger.name {
        isSendingDirectChallenge = false
        pendingDirectChallengeOpponent = nil
        pendingDirectChallengeLabel = nil
        pendingDirectChallengeKind = nil
      }
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

  private func sendChallenge(
    username: String,
    rating: Int,
    preset: SeekPreset,
    icon: String,
    kind: PendingDirectChallengeKind
  ) async {
    guard !isSendingDirectChallenge else {
      events.insert(
        LichessEvent(title: "Challenge pending", detail: pendingDirectChallengeLabel ?? "Wait for the current challenge to resolve.", systemImage: "clock"),
        at: 0
      )
      return
    }

    isSendingDirectChallenge = true
    pendingDirectChallengeOpponent = username
    pendingDirectChallengeLabel = "\(username) • \(preset.title)"
    pendingDirectChallengeKind = kind

    do {
      let (data, response) = try await URLSession.shared.data(for: api.challengeRequest(username: username, preset: preset))
      guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        let message = String(data: data, encoding: .utf8) ?? "Challenge failed."
        isSendingDirectChallenge = false
        pendingDirectChallengeOpponent = nil
        pendingDirectChallengeLabel = nil
        pendingDirectChallengeKind = nil
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
      isSendingDirectChallenge = false
      pendingDirectChallengeOpponent = nil
      pendingDirectChallengeLabel = nil
      pendingDirectChallengeKind = nil
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

  private func handleSeekClosure() async {
    seekTask = nil

    do {
      try await Task.sleep(for: .seconds(3))
    } catch is CancellationError {
      return
    } catch {
      return
    }

    guard isSearching, !isInGame else {
      return
    }
    handleSeekFailure(message: "Seek closed before a gameStart event arrived. Try again or challenge a player directly.")
  }

  private func recordEvent(title: String, detail: String, icon: String) {
    events.insert(
      LichessEvent(title: title, detail: detail, systemImage: icon),
      at: 0
    )
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
      activeInitialFEN = event.initialFen
      updateBoardState(initialFEN: event.initialFen, movesString: event.state.moves)
      updateClockState(
        state: event.state,
        meIsWhite: meIsWhite,
        fallbackInitial: event.clock?.initial ?? 0
      )
      hasLoadedGameState = true
      events.insert(
        LichessEvent(title: "Board ready", detail: "Live game state loaded.", systemImage: "checkmark.circle"),
        at: 0
      )
    case "gameState":
      guard let event = try? JSONDecoder().decode(GameStateEvent.self, from: data) else { return }
      let meIsWhite = activeGame.myColor.lowercased() == "white"
      activeGame.status = event.status
      updateBoardState(initialFEN: activeInitialFEN, movesString: event.moves)
      updateClockState(state: event, meIsWhite: meIsWhite, fallbackInitial: 0)
    case "chatLine":
      guard let line = try? JSONDecoder().decode(ChatLineEvent.self, from: data) else { return }
      let room = line.room == "spectator" ? ChatRoom.spectator : .player
      activeGame.chat.insert(ChatLine(user: line.username, text: line.text, room: room), at: 0)
    case "opponentGone":
      guard let event = try? JSONDecoder().decode(OpponentGoneEvent.self, from: data) else { return }
      let detail: String
      if event.gone {
        let winText = event.claimWinInSeconds.map { $0 <= 0 ? "Win can be claimed." : "Win in \($0)s." }
        let drawText = event.claimDrawInSeconds.map { $0 <= 0 ? "Draw can be claimed." : "Draw in \($0)s." }
        let claimDetail = [winText, drawText].compactMap(\.self).joined(separator: " ")
        detail = claimDetail.isEmpty ? "Opponent left the game." : claimDetail
        opponentPresenceMessage = detail
        canClaimVictory = (event.claimWinInSeconds ?? Int.max) <= 0
        canClaimDraw = (event.claimDrawInSeconds ?? Int.max) <= 0
      } else {
        detail = "Opponent returned."
        opponentPresenceMessage = nil
        canClaimVictory = false
        canClaimDraw = false
      }
      events.insert(
        LichessEvent(title: "Presence update", detail: detail, systemImage: "person.crop.circle.badge.exclamationmark"),
        at: 0
      )
    default:
      break
    }
  }

  private func updateBoardState(initialFEN: String?, movesString: String) {
    let result = LichessBoardPositionBuilder.build(initialFEN: initialFEN, movesString: movesString)
    let previousMoveCount = activeGame.moves.count

    board = result.board
    activeGame.moves = result.moves
    activeGame.lastMove = result.lastMove
    activeGame.isMyTurn = board.position.sideToMove == (activeGame.myColor.lowercased() == "white" ? .white : .black)
    if pendingSubmittedMove == result.lastMove {
      pendingSubmittedMove = nil
    }

    if hasLoadedGameState,
       result.moves.count > previousMoveCount,
       let lastAppliedMove = result.lastAppliedMove,
       pendingSubmittedMove != result.lastMove {
      ChessSoundPlayer.shared.play(for: lastAppliedMove)
    }
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

  func applyConfirmedLocalMoveForTesting(_ move: String) {
    applyConfirmedLocalMove(move)
  }

  private func applyConfirmedLocalMove(_ move: String) {
    guard hasLoadedGameState else {
      return
    }

    var confirmedBoard = board
    guard LichessBoardPositionBuilder.apply(uciMove: move, to: &confirmedBoard) != nil else {
      return
    }

    pendingSubmittedMove = move
    board = confirmedBoard
    activeGame.moves.append(move)
    activeGame.lastMove = move
    activeGame.isMyTurn = board.position.sideToMove == (activeGame.myColor.lowercased() == "white" ? .white : .black)
  }

  private func chessSquare(_ square: BoardSquare) -> Square {
    Square(square.uci)
  }

  private func boardSquare(_ square: Square) -> BoardSquare {
    BoardSquare(file: square.file.number - 1, rank: square.rank.value - 1)
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

  private func submitChallengeDecision(
    _ challenge: LichessChallenge,
    title: String,
    status: ChallengeStatus,
    icon: String,
    request: URLRequest
  ) {
    guard isConfigured else {
      events.insert(
        LichessEvent(title: "Sign-in required", detail: "Sign in with Lichess before responding.", systemImage: "person.crop.circle"),
        at: 0
      )
      return
    }

    guard !isSubmittingChallengeAction else {
      return
    }

    isSubmittingChallengeAction = true
    events.insert(
      LichessEvent(title: "\(title) requested", detail: challenge.opponent, systemImage: icon),
      at: 0
    )

    Task { [weak self] in
      guard let self else { return }
      defer {
        Task { @MainActor in
          self.isSubmittingChallengeAction = false
        }
      }

      do {
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
          await self.recordEvent(title: "Challenge response failed", detail: challenge.opponent, icon: "exclamationmark.triangle")
          return
        }
        await MainActor.run {
          self.updateChallenge(challenge, status: status)
        }
        await self.recordEvent(title: title, detail: challenge.opponent, icon: icon)
      } catch {
        await self.recordEvent(title: "Challenge response failed", detail: error.localizedDescription, icon: "exclamationmark.triangle")
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
