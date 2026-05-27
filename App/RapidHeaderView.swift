import SwiftUI

struct RapidHeaderView: View {
  var model: LichessClientModel

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(model.activeGame.isMyTurn ? "Your move" : "Waiting")
          .font(.title2.bold())
        Text("\(model.activeGame.opponent) • \(model.activeGame.speed)")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Text(model.streamState.title)
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.tint.opacity(0.12), in: .capsule)
        .foregroundStyle(.tint)
    }
    .padding(.top, 4)
  }
}
