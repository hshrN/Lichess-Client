import SwiftUI

struct BotMatchTestView: View {
  @Bindable var model: LichessClientModel

  private var sortedBots: [LichessBotPlayer] {
    model.onlineBots.sorted {
      ($0.rating ?? 0) < ($1.rating ?? 0)
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Picker("Rapid", selection: $model.selectedSeekPreset) {
          ForEach(SeekPreset.defaults) { preset in
            Text(preset.title.replacingOccurrences(of: "Rapid ", with: "")).tag(preset)
          }
        }
        .pickerStyle(.segmented)

        Text("Direct bot challenges are a cleaner live harness than public seeking. They still use the same board/game stream path, but avoid waiting on the public rapid pool.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        HStack(spacing: 10) {
          Button("Refresh Bots", systemImage: "arrow.clockwise") {
            Task {
              await model.refreshOnlineBots()
            }
          }
          .buttonStyle(.borderedProminent)

          if let pendingLabel = model.pendingDirectChallengeLabel {
            Label(pendingLabel, systemImage: "hourglass")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }

        ForEach(sortedBots.prefix(12)) { bot in
          HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
              Text(bot.username)
                .font(.subheadline.weight(.semibold))
              Text(bot.rating.map { "Rapid \($0)" } ?? "Rapid unrated")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Challenge", systemImage: "cpu") {
              Task {
                await model.challengeBot(bot)
              }
            }
            .buttonStyle(.bordered)
            .disabled(model.isSendingDirectChallenge)
          }
          .padding(12)
          .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding()
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("Bot Match Test")
    .task {
      if model.isConfigured {
        await model.refreshOnlineBots()
      }
    }
  }
}
