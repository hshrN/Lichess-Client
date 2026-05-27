import SwiftUI

struct RapidHomeView: View {
  @Bindable var model: LichessClientModel
  var showSettings: () -> Void

  var body: some View {
    VStack(spacing: 24) {
      VStack(spacing: 8) {
        Image(systemName: "bolt.fill")
          .font(.system(size: 42, weight: .semibold))
          .foregroundStyle(.tint)
          .frame(width: 72, height: 72)
          .background(.tint.opacity(0.12), in: .circle)

        Text("Rapid")
          .font(.largeTitle.bold())
        Text("Find a 10+5 rapid game on Lichess.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding(.top, 36)

      Button {
        if model.isConfigured {
          model.seek(SeekPreset.defaults[0])
        } else {
          showSettings()
        }
      } label: {
        Label(model.isSearching ? "Searching…" : "Play", systemImage: model.isSearching ? "hourglass" : "play.fill")
          .font(.title3.bold())
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)

      if model.isSearching {
        VStack(spacing: 10) {
          ProgressView()
          Button("Open Preview Game") {
            model.openPreviewGame()
          }
          .font(.subheadline.weight(.semibold))
        }
      }

      VStack(spacing: 10) {
        ForEach(SeekPreset.defaults.dropFirst()) { preset in
          Button {
            if model.isConfigured {
              model.seek(preset)
            } else {
              showSettings()
            }
          } label: {
            HStack {
              Text(preset.title)
                .font(.subheadline.weight(.semibold))
              Spacer()
              Text(preset.rated ? "Rated" : "Casual")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
          }
          .buttonStyle(.plain)
        }
      }

      EventFeedCompactView(events: model.events)
    }
  }
}

private struct EventFeedCompactView: View {
  var events: [LichessEvent]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ForEach(events.prefix(2)) { event in
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
