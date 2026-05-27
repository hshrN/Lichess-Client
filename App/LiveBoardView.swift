import SwiftUI

struct LiveBoardView: View {
  @Bindable var model: LichessClientModel

  var body: some View {
    VStack(spacing: 14) {
      GameClockRow(game: model.activeGame)
      ChessBoardView(model: model)
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

private struct ChessBoardView: View {
  @Bindable var model: LichessClientModel

  private let pieces = [
    ["r", "n", "b", "q", "k", "b", "n", "r"],
    ["p", "p", "p", "p", "p", "p", "p", "p"],
    ["", "", "", "", "", "", "", ""],
    ["", "", "", "", "", "", "", ""],
    ["", "", "", "", "", "", "", ""],
    ["", "", "", "", "", "", "", ""],
    ["P", "P", "P", "P", "P", "P", "P", "P"],
    ["R", "N", "B", "Q", "K", "B", "N", "R"]
  ]

  var body: some View {
    VStack(spacing: 0) {
      ForEach(0..<8, id: \.self) { row in
        HStack(spacing: 0) {
          ForEach(0..<8, id: \.self) { column in
            let square = BoardSquare(file: column, rank: 7 - row)
            Button {
              withAnimation(.snappy) {
                model.playMove(to: square)
              }
            } label: {
              ZStack {
                Rectangle()
                  .fill(squareColor(row: row, column: column))
                if model.selectedSquare == square {
                  Circle()
                    .stroke(.tint, lineWidth: 4)
                    .padding(8)
                }
                Text(pieceSymbol(pieces[row][column]))
                  .font(.system(size: 28, weight: .semibold))
                  .minimumScaleFactor(0.7)
              }
              .aspectRatio(1, contentMode: .fit)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(square.uci)
          }
        }
      }
    }
    .clipShape(.rect(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.black.opacity(0.08), lineWidth: 1)
    }
  }

  private func squareColor(row: Int, column: Int) -> Color {
    (row + column).isMultiple(of: 2) ? Color(red: 0.91, green: 0.87, blue: 0.76) : Color(red: 0.36, green: 0.53, blue: 0.39)
  }

  private func pieceSymbol(_ piece: String) -> String {
    switch piece {
    case "K": "♔"
    case "Q": "♕"
    case "R": "♖"
    case "B": "♗"
    case "N": "♘"
    case "P": "♙"
    case "k": "♚"
    case "q": "♛"
    case "r": "♜"
    case "b": "♝"
    case "n": "♞"
    case "p": "♟"
    default: ""
    }
  }
}

private struct MoveControlsView: View {
  var model: LichessClientModel

  var body: some View {
    HStack(spacing: 10) {
      Button("Abort", systemImage: "stop.circle") {
        model.abort()
      }
      .buttonStyle(.bordered)

      Button("Draw", systemImage: "equal.circle") {}
        .buttonStyle(.bordered)

      Button("Resign", systemImage: "flag") {
        model.resign()
      }
      .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity)
  }
}

private struct ChatComposerView: View {
  @Bindable var model: LichessClientModel

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Picker("Room", selection: $model.selectedRoom) {
        ForEach(ChatRoom.allCases) { room in
          Text(room.title).tag(room)
        }
      }
      .pickerStyle(.segmented)

      HStack(spacing: 8) {
        TextField("Message", text: $model.draftMessage)
          .textFieldStyle(.roundedBorder)

        Button("Send", systemImage: "paperplane.fill") {
          model.sendChat()
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderedProminent)
        .accessibilityLabel("Send chat")
      }

      ForEach(model.activeGame.chat) { line in
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
      Text("Events")
        .font(.headline)

      ForEach(events.prefix(5)) { event in
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
