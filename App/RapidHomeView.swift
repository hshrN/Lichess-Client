import SwiftUI

struct RapidHomeView: View {
  @Bindable var model: LichessClientModel
  var showSettings: () -> Void

  var body: some View {
    VStack(spacing: 20) {
      HomeDashboardView(model: model, showSettings: showSettings)
      PlayControlPanel(model: model, showSettings: showSettings)
      FollowingChallengeView(model: model, showSettings: showSettings)
      ChallengeInboxPanel(model: model)
      EventFeedCompactView(events: model.events)
    }
  }
}

private struct HomeDashboardView: View {
  var model: LichessClientModel
  var showSettings: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Lichess Rapid")
            .font(.largeTitle.bold())
          Text("Play, challenge friends, and manage live games from one native iOS dashboard.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer()

        Button("Token", systemImage: model.isConfigured ? "checkmark.seal.fill" : "key.fill") {
          showSettings()
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .accessibilityLabel("Token settings")
      }

      HStack(spacing: 10) {
        DashboardMetric(title: "Status", value: model.streamState.title, systemImage: "antenna.radiowaves.left.and.right")
        DashboardMetric(title: "Following", value: "\(model.following.count)", systemImage: "person.2")
        DashboardMetric(title: "Inbox", value: "\(model.challenges.filter { $0.status == .pending }.count)", systemImage: "tray")
      }
    }
    .padding(18)
    .background(
      LinearGradient(
        colors: [Color.accentColor.opacity(0.18), Color(.secondarySystemGroupedBackground)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: .rect(cornerRadius: 20)
    )
  }
}

private struct DashboardMetric: View {
  var title: String
  var value: String
  var systemImage: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Image(systemName: systemImage)
        .foregroundStyle(.tint)
      Text(value)
        .font(.headline)
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color(.systemBackground).opacity(0.72), in: .rect(cornerRadius: 14))
  }
}

private struct PlayControlPanel: View {
  @Bindable var model: LichessClientModel
  var showSettings: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Label("Play", systemImage: "bolt.fill")
          .font(.headline)
        Spacer()
        Text(model.selectedSeekPreset.rated ? "Rated" : "Casual")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 8) {
        ForEach(SeekPreset.defaults) { preset in
          Button {
            model.selectSeekPreset(preset)
          } label: {
            Text(preset.title.replacingOccurrences(of: "Rapid ", with: ""))
              .font(.subheadline.weight(.semibold))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 10)
              .background(
                model.selectedSeekPreset.id == preset.id ? Color.accentColor.opacity(0.18) : Color(.tertiarySystemGroupedBackground),
                in: .rect(cornerRadius: 10)
              )
          }
          .buttonStyle(.plain)
        }
      }

      Button {
        if model.isConfigured {
          model.seek(model.selectedSeekPreset)
        } else {
          showSettings()
        }
      } label: {
        Label(model.isSearching ? "Searching…" : "Play \(model.selectedSeekPreset.title)", systemImage: model.isSearching ? "hourglass" : "play.fill")
          .font(.title3.bold())
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)

      if model.isSearching {
        HStack(spacing: 12) {
          ProgressView()
          Text("Waiting for Lichess to pair a rapid game.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Spacer()
          Button("Preview") {
            model.openPreviewGame()
          }
          .font(.subheadline.weight(.semibold))
        }
      }
    }
    .padding(16)
    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
  }
}

private struct ChallengeInboxPanel: View {
  var model: LichessClientModel

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("Challenge Inbox", systemImage: "tray")
        .font(.headline)

      ForEach(model.challenges.prefix(3)) { challenge in
        HStack(spacing: 12) {
          Image(systemName: challenge.status == .pending ? "clock" : "checkmark.circle")
            .foregroundStyle(.tint)
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 2) {
            Text(challenge.opponent)
              .font(.subheadline.weight(.semibold))
            Text("\(challenge.control) • \(challenge.rated ? "Rated" : "Casual")")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Spacer()

          Text(challenge.status.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 12))
      }
    }
    .padding(16)
    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
  }
}

private struct EventFeedCompactView: View {
  var events: [LichessEvent]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Activity", systemImage: "waveform.path.ecg")
        .font(.headline)

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
    .padding(16)
    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
  }
}
