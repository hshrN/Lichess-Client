import SwiftUI

struct RapidHomeView: View {
  @Bindable var model: LichessClientModel
  @State private var previewGame = ChessPreviewGameModel()
  var showSettings: () -> Void

  private var pendingChallenge: LichessChallenge? {
    model.challenges.first { $0.status == .pending }
  }

  var body: some View {
    VStack(spacing: 22) {
      header

      ChessBoardView(
        state: previewGame.chessBoardState,
        isInteractionEnabled: true,
        syncingMessage: nil,
        onSelectSquare: { _ in }
      )
        .frame(maxWidth: 360)
        .padding(.horizontal, 10)

      playPanel

      if let pendingChallenge {
        challengeRow(pendingChallenge)
      }
    }
    .frame(maxWidth: 430)
    .frame(maxWidth: .infinity)
  }

  private var header: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(model.isConfigured ? model.accountLabel : "Sign in to play on Lichess")
          .font(.title3.weight(.semibold))
        Text("Rapid pairing")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Button("Account", systemImage: model.isConfigured ? "person.crop.circle" : "person.crop.circle.badge.plus") {
        showSettings()
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.bordered)
      .accessibilityLabel(model.isConfigured ? "Account" : "Sign in")
    }
  }

  private var playPanel: some View {
    VStack(spacing: 14) {
      Picker("Time Control", selection: $model.selectedSeekPreset) {
        ForEach(SeekPreset.defaults) { preset in
          Text(shortTitle(for: preset)).tag(preset)
        }
      }
      .pickerStyle(.segmented)

      HStack {
        Label(model.selectedSeekPreset.rated ? "Rated" : "Casual", systemImage: model.selectedSeekPreset.rated ? "checkmark.seal" : "leaf")
        Spacer()
        Label("Random color", systemImage: "circle.lefthalf.filled")
      }
      .font(.caption.weight(.semibold))
      .foregroundStyle(.secondary)

      Button {
        if model.isConfigured {
          Task {
            await model.seek(model.selectedSeekPreset)
          }
        } else {
          showSettings()
        }
      } label: {
        Label(model.isSearching ? "Searching…" : "Play \(shortTitle(for: model.selectedSeekPreset))", systemImage: model.isSearching ? "hourglass" : "play.fill")
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(model.isSendingDirectChallenge)

      if model.isSearching {
        HStack(spacing: 10) {
          ProgressView()
          Text(model.selectedSeekPreset.title)
            .font(.subheadline)
            .foregroundStyle(.secondary)

          Spacer()

          Button("Cancel") {
            model.cancelSeek()
          }
          .font(.subheadline.weight(.semibold))
        }
      } else if let pendingLabel = model.pendingDirectChallengeLabel {
        HStack(spacing: 10) {
          ProgressView()
          Text("Waiting for \(pendingLabel)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Spacer()
        }
      }
    }
    .padding(16)
    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
  }

  private func challengeRow(_ challenge: LichessChallenge) -> some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(challenge.opponent)
          .font(.subheadline.weight(.semibold))
        Text("\(challenge.control) • \(challenge.rated ? "Rated" : "Casual")")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Button("Decline", systemImage: "xmark") {
        model.decline(challenge)
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.bordered)
      .accessibilityLabel("Decline challenge")
      .disabled(model.isSubmittingChallengeAction)

      Button("Accept", systemImage: "checkmark") {
        model.accept(challenge)
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.borderedProminent)
      .accessibilityLabel("Accept challenge")
      .disabled(model.isSubmittingChallengeAction)
    }
    .padding(14)
    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
  }

  private func shortTitle(for preset: SeekPreset) -> String {
    preset.title.replacingOccurrences(of: "Rapid ", with: "")
  }
}
