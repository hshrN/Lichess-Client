import SwiftUI

struct LiveBoardView: View {
  @Bindable var model: LichessClientModel

  var body: some View {
    VStack(spacing: 12) {
      RapidHeaderView(model: model)
      GameClockRow(game: model.activeGame)
      ChessBoardPanel(model: model)
      MoveControlsView(model: model)
      ChatComposerView(model: model)
      EventFeedView(events: model.events)
    }
  }
}

private struct GameClockRow: View {
  var game: LichessGame

  var body: some View {
    HStack(spacing: 12) {
      ClockCard(name: "White", time: game.whiteTime, isActive: game.isMyTurn && game.myColor == "White")
      ClockCard(name: "Black", time: game.blackTime, isActive: !game.isMyTurn && game.myColor == "White")
    }
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

private struct ChessBoardPanel: View {
  @Bindable var model: LichessClientModel

  var body: some View {
    VStack(spacing: 8) {
      ChessBoardView(
        state: model.chessBoardState,
        isInteractionEnabled: model.hasLoadedGameState && model.activeGame.isMyTurn && model.activeGame.status == "started" && !model.isSubmittingMove,
        syncingMessage: model.hasLoadedGameState ? nil : "Syncing board…",
        onSelectSquare: model.selectBoardSquare
      )

      Button("Flip Board", systemImage: "arrow.triangle.2.circlepath") {
        model.flipBoard()
      }
      .buttonStyle(.bordered)
      .frame(maxWidth: .infinity, alignment: .trailing)
    }
  }
}

private struct MoveControlsView: View {
  @Bindable var model: LichessClientModel

  var body: some View {
    HStack(spacing: 10) {
      Button("Abort", systemImage: "stop.circle") {
        model.abort()
      }
      .buttonStyle(.bordered)
      .disabled(model.isSubmittingGameAction)

      Button("Draw", systemImage: "equal.circle") {
        model.offerDraw()
      }
      .buttonStyle(.bordered)
      .disabled(model.isSubmittingGameAction)

      Button("Resign", systemImage: "flag") {
        model.resign()
      }
      .buttonStyle(.borderedProminent)
      .disabled(model.isSubmittingGameAction)

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
      }
      .buttonStyle(.bordered)
      .disabled(model.isSubmittingGameAction)
    }
    .frame(maxWidth: .infinity)
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
