import SwiftUI

struct ChallengesView: View {
  var model: LichessClientModel

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Challenges")
        .font(.headline)

      ForEach(model.challenges) { challenge in
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            VStack(alignment: .leading, spacing: 3) {
              Text(challenge.opponent)
                .font(.headline)
              Text("\(challenge.rating) • \(challenge.control) • \(challenge.rated ? "Rated" : "Casual")")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(challenge.status.title)
              .font(.caption.weight(.semibold))
              .foregroundStyle(.tint)
          }

          if challenge.status == .pending {
            HStack {
              Button("Decline", systemImage: "xmark") {
                model.decline(challenge)
              }
              .buttonStyle(.bordered)

              Button("Accept", systemImage: "checkmark") {
                model.accept(challenge)
              }
              .buttonStyle(.borderedProminent)
            }
          }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
