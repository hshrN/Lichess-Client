import SwiftUI

struct LiveBoardView: View {
  @Bindable var model: LichessClientModel

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        RapidHeaderView(model: model)
        GameClockRow(game: model.activeGame)
        ChessBoardStage(model: model)
        MoveControlsView(model: model)
        OpponentPresenceView(model: model)
        ChatComposerView(model: model)
        EventFeedView(events: model.events)
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
    }
    .background(Color(.systemGroupedBackground))
  }
}

private struct GameClockRow: View {
  var game: LichessGame

  var body: some View {
    HStack(spacing: 12) {
      ClockCard(name: "White", time: game.whiteTime, isActive: activeSide == "white")
      ClockCard(name: "Black", time: game.blackTime, isActive: activeSide == "black")
    }
  }

  private var activeSide: String {
    if game.isMyTurn {
      return game.myColor.lowercased()
    }
    return game.myColor.lowercased() == "white" ? "black" : "white"
  }
}

private struct ClockCard: View {
  var name: String
  var time: String
  var isActive: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(name)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(time)
        .font(.title3.monospacedDigit().weight(.semibold))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(isActive ? Color.accentColor.opacity(0.14) : Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
  }
}

private struct ChessBoardStage: View {
  @Bindable var model: LichessClientModel

  var body: some View {
    VStack(spacing: 12) {
      ChessBoardView(
        state: model.chessBoardState,
        isInteractionEnabled: model.hasLoadedGameState && model.activeGame.isMyTurn && model.activeGame.status == "started" && !model.isSubmittingMove,
        syncingMessage: model.hasLoadedGameState ? nil : "Syncing board…",
        onSelectSquare: model.selectBoardSquare
      )
      .frame(maxWidth: .infinity)

      HStack(spacing: 10) {
        boardMeta(title: "You", value: model.activeGame.myColor)
        boardMeta(title: "Status", value: model.activeGame.status.capitalized)
        boardMeta(title: "Speed", value: model.activeGame.speed)
      }

      HStack(spacing: 10) {
        Button("Flip Board", systemImage: "arrow.triangle.2.circlepath") {
          model.flipBoard()
        }
        .buttonStyle(.bordered)

        Spacer()

        if model.isSubmittingMove {
          Label("Submitting…", systemImage: "hourglass")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        } else {
          Label(model.activeGame.isMyTurn ? "Your move" : "Waiting", systemImage: model.activeGame.isMyTurn ? "hand.point.up.left.fill" : "clock")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(12)
    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
  }

  private func boardMeta(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 12))
  }
}

private struct MoveControlsView: View {
  @Bindable var model: LichessClientModel

  var body: some View {
    VStack(spacing: 10) {
      HStack(spacing: 10) {
        actionButton("Draw", systemImage: "equal.circle") {
          model.offerDraw()
        }
        .buttonStyle(.bordered)

        actionButton("Abort", systemImage: "stop.circle") {
          model.abort()
        }
        .buttonStyle(.bordered)
      }

      HStack(spacing: 10) {
        actionButton("Resign", systemImage: "flag") {
          model.resign()
        }
        .buttonStyle(.borderedProminent)

        Menu {
          Button("Takeback", systemImage: "arrow.uturn.backward.circle") {
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
        } label: {
          Label("More", systemImage: "ellipsis")
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.bordered)
        .disabled(model.isSubmittingGameAction)
      }
    }
  }

  private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
    Button(title, systemImage: systemImage, action: action)
      .font(.subheadline.weight(.semibold))
      .frame(maxWidth: .infinity)
      .padding(.vertical, 14)
      .disabled(model.isSubmittingGameAction)
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
          Button("Claim Win", systemImage: "crown") {
            model.claimVictory()
          }
          .buttonStyle(.borderedProminent)
          .disabled(model.isSubmittingGameAction)
        } else if model.canClaimDraw {
          Button("Claim Draw", systemImage: "equal.square") {
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
    .padding(14)
    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
  }
}

private struct EventFeedView: View {
  var events: [LichessEvent]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ForEach(events.prefix(3)) { event in
        Label {
          VStack(alignment: .leading, spacing: 2) {
            Text(event.title)
              .font(.subheadline.weight(.semibold))
            Text(event.detail)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        } icon: {
          Image(systemName: event.systemImage)
            .foregroundStyle(.tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(14)
    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
  }
}
