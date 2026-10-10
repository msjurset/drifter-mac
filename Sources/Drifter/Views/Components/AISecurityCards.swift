import SwiftUI

struct AISecurityBriefCard: View {
    let brief: AIAnalysisResult
    var title: String = "AI Security Brief"
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)

                Text(title)
                    .font(.headline)

                classificationBadge(brief.classification)

                Text("\(brief.providerName) • \(brief.modelName)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                Text(brief.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help("Dismiss security brief")
            }

            Text(brief.summary)
                .font(.subheadline)
                .foregroundStyle(.primary)

            if !brief.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recommended Actions:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    ForEach(brief.recommendations, id: \.self) { rec in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                                .padding(.top, 2)
                            Text(rec)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func classificationBadge(_ classification: String) -> some View {
        let (color, icon): (Color, String) = {
            switch classification.lowercased() {
            case "suspicious":
                return (.red, "exclamationmark.triangle.fill")
            case "expected":
                return (.blue, "shield.lefthalf.filled")
            default:
                return (.green, "checkmark.shield.fill")
            }
        }()

        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(classification.capitalized)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

struct AIAdvisorErrorCard: View {
    let errorMessage: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Security Advisor Notice")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .focusable(false)
        }
        .padding(10)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
}
