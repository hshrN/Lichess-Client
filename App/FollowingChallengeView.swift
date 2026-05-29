import SwiftUI

struct FollowingChallengeView: View {
  @Bindable var model: LichessClientModel
  var showSettings: () -> Void

  private var filteredPlayers: [LichessFollowedPlayer] {
    let query = model.playerSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else {
      return model.following
    }

    return model.following.filter {
      $0.username.localizedCaseInsensitiveContains(query)
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Label("Challenge Following", systemImage: "person.crop.circle.badge.plus")
          .font(.headline)
        Spacer()
        Button("Following", systemImage: "arrow.clockwise") {
          if model.isConfigured {
            Task {
              await model.refreshFollowing()
            }
          } else {
            showSettings()
          }
        }
        .font(.caption.weight(.semibold))
      }

      HStack {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.secondary)
        TextField("Search following", text: $model.playerSearchText)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
      }
      .padding(11)
      .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 12))

      ForEach(filteredPlayers) { player in
        HStack(spacing: 12) {
          Circle()
            .fill(player.online ? Color.green : Color.secondary.opacity(0.35))
            .frame(width: 9, height: 9)

          VStack(alignment: .leading, spacing: 2) {
            Text(player.username)
              .font(.subheadline.weight(.semibold))
            Text(player.rapidRating.map { "Rapid \($0)" } ?? "Rapid unrated")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Spacer()

          Button(
            model.pendingDirectChallengeOpponent == player.username ? "Waiting…" : "10+5",
            systemImage: "paperplane.fill"
          ) {
            if model.isConfigured {
              Task {
                await model.challenge(player)
              }
            } else {
              showSettings()
            }
          }
          .labelStyle(.titleAndIcon)
          .font(.caption.weight(.semibold))
          .buttonStyle(.bordered)
          .disabled(model.isSendingDirectChallenge)
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 12))
      }
    }
    .padding(16)
    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
  }
}
