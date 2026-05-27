import SwiftUI

struct RapidPairingStrip: View {
  var model: LichessClientModel

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(SeekPreset.defaults) { preset in
          Button {
            Task {
              await model.seek(preset)
            }
          } label: {
            VStack(alignment: .leading, spacing: 4) {
              Text(preset.title)
                .font(.subheadline.weight(.semibold))
              Text(preset.rated ? "Rated" : "Casual")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(width: 122, alignment: .leading)
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
}
