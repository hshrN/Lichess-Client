import SwiftUI

struct HeaderPanel: View {
  var model: LichessClientModel

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 12) {
        Image(systemName: "checkerboard.shield")
          .font(.system(size: 34, weight: .semibold))
          .foregroundStyle(.tint)
          .frame(width: 48, height: 48)
          .background(.tint.opacity(0.12), in: .rect(cornerRadius: 12))

        VStack(alignment: .leading, spacing: 4) {
          Text(model.activeGame.isMyTurn ? "Your move" : "Opponent thinking")
            .font(.title2.bold())
          Text("\(model.activeGame.speed) against \(model.activeGame.opponent)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        Spacer()
      }

      HStack(spacing: 10) {
        StatusPill(title: model.streamState.title, systemImage: "antenna.radiowaves.left.and.right")
        StatusPill(title: model.activeGame.status.capitalized, systemImage: "play.circle")
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
  }
}

private struct StatusPill: View {
  var title: String
  var systemImage: String

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.caption.weight(.semibold))
      .padding(.horizontal, 10)
      .padding(.vertical, 7)
      .background(.tint.opacity(0.12), in: .capsule)
      .foregroundStyle(.tint)
  }
}
