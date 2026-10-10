import SwiftUI

struct AISecurityBriefCard: View {
    let brief: AIAnalysisResult
    var title: String = "AI Security Brief"
    var onDeepInvestigate: (() -> Void)? = nil
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: brief.isDeepReasoning ? "brain.head.profile" : "sparkles")
                    .foregroundStyle(brief.isDeepReasoning ? .indigo : .purple)

                Text(brief.isDeepReasoning ? "Deep Security Investigation" : title)
                    .font(.headline)

                classificationBadge(brief.classification)

                reasoningBadge

                Text("\(brief.providerName) • \(brief.modelName)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                if !brief.isDeepReasoning, let onDeepInvestigate {
                    Button {
                        onDeepInvestigate()
                    } label: {
                        Label("Deep Investigation", systemImage: "brain.head.profile")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .focusable(false)
                    .help("Escalate to multi-step threat model with extended reasoning")
                }

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
    private var reasoningBadge: some View {
        if brief.isDeepReasoning {
            HStack(spacing: 4) {
                Image(systemName: "brain.head.profile")
                    .font(.caption2)
                Text("Deep Reasoning")
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.indigo.opacity(0.15))
            .foregroundStyle(.indigo)
            .clipShape(Capsule())
        }
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
