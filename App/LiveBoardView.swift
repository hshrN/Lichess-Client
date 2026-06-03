import SwiftUI

struct LiveBoardView: View {
  @Bindable var model: LichessClientModel

  var body: some View {
    ScrollView {
      VStack(spacing: 14) {
        gameHeader
        if model.activeGame.status != "started" {
          statusBanner
        }
        ClockStrip(game: model.activeGame, side: .opponent)
        ChessBoardStage(model: model)
        ClockStrip(game: model.activeGame, side: .player)
        gameActions
        OpponentPresenceView(model: model)
        chatSection
      }
      .frame(maxWidth: 520)
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
    }
    .background(Color(.systemGroupedBackground))
  }

  private var gameHeader: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(headerTitle)
          .font(.title2.bold())
        Text("\(model.activeGame.opponent) • \(model.activeGame.speed)")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer()

      Label(model.activeGame.myColor, systemImage: "circle.lefthalf.filled")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .labelStyle(.titleAndIcon)
    }
  }

  private var statusBanner: some View {
    HStack(spacing: 10) {
      Image(systemName: "info.circle")
        .foregroundStyle(.tint)
      Text("Status: \(model.activeGame.status.capitalized)")
        .font(.subheadline.weight(.semibold))
      Spacer()
    }
    .padding(12)
    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
  }

  private var headerTitle: String {
    if model.activeGame.status != "started" {
      return model.activeGame.status.capitalized
    }
    return model.activeGame.isMyTurn ? "Your move" : "Waiting"
  }

  private var gameActions: some View {
    HStack(spacing: 10) {
      Button("Draw", systemImage: "equal") {
        model.offerDraw()
      }
      .buttonStyle(.bordered)
      .disabled(model.isSubmittingGameAction)

      Button("Resign", systemImage: "flag") {
        model.resign()
      }
      .buttonStyle(.bordered)
      .disabled(model.isSubmittingGameAction)

      Spacer()

      Menu {
        Button("Abort", systemImage: "stop") {
          model.abort()
        }
        Button("Takeback", systemImage: "arrow.uturn.backward") {
          model.requestTakeback()
        }
        Button("Claim Victory", systemImage: "crown") {
          model.claimVictory()
        }
        Button("Claim Draw", systemImage: "equal.square") {
          model.claimDraw()
        }
        Button("Berserk", systemImage: "bolt") {
          model.berserk()
        }
        Button("Flip Board", systemImage: "arrow.triangle.2.circlepath") {
          model.flipBoard()
        }
      } label: {
        Label("More", systemImage: "ellipsis")
          .labelStyle(.iconOnly)
      }
      .buttonStyle(.bordered)
      .accessibilityLabel("More game actions")
      .disabled(model.isSubmittingGameAction)
    }
  }

  private var chatSection: some View {
    DisclosureGroup {
      ChatComposerView(model: model)
        .padding(.top, 8)
    } label: {
      Label("Chat", systemImage: "bubble.left.and.bubble.right")
        .font(.subheadline.weight(.semibold))
    }
    .padding(14)
    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
  }
}

private enum ClockSide {
  case player
  case opponent
}

private struct ClockStrip: View {
  var game: LichessGame
  var side: ClockSide

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 3) {
        Text(name)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(time)
          .font(.title2.monospacedDigit().weight(.semibold))
      }

      Spacer()

      if isActive {
        Image(systemName: "timer")
          .foregroundStyle(.tint)
      }
    }
    .padding(14)
    .background(isActive ? Color.accentColor.opacity(0.13) : Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
  }

  private var isPlayerWhite: Bool {
    game.myColor.localizedCaseInsensitiveCompare("white") == .orderedSame
  }

  private var isWhiteClock: Bool {
    switch side {
    case .player:
      isPlayerWhite
    case .opponent:
      !isPlayerWhite
    }
  }

  private var name: String {
    switch side {
    case .player:
      "You"
    case .opponent:
      game.opponent
    }
  }

  private var time: String {
    isWhiteClock ? game.whiteTime : game.blackTime
  }

  private var isActive: Bool {
    if game.isMyTurn {
      return side == .player
    }
    return side == .opponent
  }
}

private struct ChessBoardStage: View {
  @Bindable var model: LichessClientModel

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      ChessBoardView(
        state: model.chessBoardState,
        isInteractionEnabled: model.hasLoadedGameState && model.activeGame.isMyTurn && model.activeGame.status == "started" && !model.isSubmittingMove,
        syncingMessage: model.hasLoadedGameState ? nil : "Syncing board…",
        onSelectSquare: model.selectBoardSquare
      )

      if model.isSubmittingMove {
        Label("Submitting…", systemImage: "hourglass")
          .font(.caption.weight(.semibold))
          .padding(.horizontal, 10)
          .padding(.vertical, 7)
          .background(Color(.systemBackground).opacity(0.92), in: .capsule)
          .padding(10)
      }
    }
  }
}

private struct OpponentPresenceView: View {
  @Bindable var model: LichessClientModel

  var body: some View {
    if let message = model.opponentPresenceMessage {
      HStack(spacing: 10) {
        Image(systemName: "person.crop.circle.badge.exclamationmark")
          .foregroundStyle(.tint)

        Text(message)
          .font(.subheadline)
          .frame(maxWidth: .infinity, alignment: .leading)

        if model.canClaimVictory {
          Button("Claim", systemImage: "crown") {
            model.claimVictory()
          }
          .buttonStyle(.borderedProminent)
          .disabled(model.isSubmittingGameAction)
        } else if model.canClaimDraw {
          Button("Claim", systemImage: "equal.square") {
            model.claimDraw()
          }
          .buttonStyle(.bordered)
          .disabled(model.isSubmittingGameAction)
        }
      }
      .padding(14)
      .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
    }
  }
}

private struct ChatComposerView: View {
  @Bindable var model: LichessClientModel

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        TextField("Message", text: $model.draftMessage)
          .textFieldStyle(.roundedBorder)

        Button("Send", systemImage: "paperplane.fill") {
          model.sendChat()
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderedProminent)
        .accessibilityLabel("Send chat")
        .disabled(model.isSendingChat)
      }

      ForEach(model.activeGame.chat.prefix(2)) { line in
        HStack {
          Text(line.user)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Text(line.text)
            .font(.subheadline)
          Spacer()
        }
      }
    }
  }
}
