import SwiftUI
import AppKit

public struct ActionPillItem: Identifiable {
    public let id: String
    public let title: String
    public let icon: String
    public let help: String
    public var isProminent: Bool
    public var isDestructive: Bool
    public let action: () -> Void

    public init(
        id: String,
        title: String,
        icon: String,
        help: String,
        isProminent: Bool = false,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.help = help
        self.isProminent = isProminent
        self.isDestructive = isDestructive
        self.action = action
    }
}

public struct CollapsibleActionRow: View {
    public let items: [ActionPillItem]
    public var isConstrained: Bool

    @State private var hoveredId: String? = nil

    public init(items: [ActionPillItem], isConstrained: Bool = false) {
        self.items = items
        self.isConstrained = isConstrained
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(items) { item in
                let isHovered = hoveredId == item.id
                let showLabel = !isConstrained || isHovered

                Button {
                    item.action()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 14, height: 14)

                        if showLabel {
                            Text(item.title)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.9, anchor: .leading)),
                                    removal: .opacity
                                ))
                        }
                    }
                    .padding(.horizontal, showLabel ? 10 : 7)
                    .padding(.vertical, 5)
                    .frame(height: 28)
                    .background(buttonBackground(for: item, isHovered: isHovered))
                    .foregroundStyle(buttonForeground(for: item, isHovered: isHovered))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(borderColor(for: item, isHovered: isHovered), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .focusable(false)
                .onHover { hovering in
                    if hovering {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            hoveredId = item.id
                        }
                    }
                }
                .help(item.help)
            }
        }
    }

    private func buttonBackground(for item: ActionPillItem, isHovered: Bool) -> Color {
        if item.isProminent {
            return isHovered ? Color.accentColor.opacity(0.85) : Color.accentColor
        } else if item.isDestructive {
            return isHovered ? Color.red.opacity(0.18) : Color(nsColor: .controlBackgroundColor)
        } else {
            return isHovered ? Color(nsColor: .selectedControlColor).opacity(0.35) : Color(nsColor: .controlBackgroundColor)
        }
    }

    private func buttonForeground(for item: ActionPillItem, isHovered: Bool) -> Color {
        if item.isProminent {
            return .white
        } else if item.isDestructive {
            return isHovered ? .red : .primary
        } else {
            return .primary
        }
    }

    private func borderColor(for item: ActionPillItem, isHovered: Bool) -> Color {
        if item.isProminent {
            return Color.clear
        } else if item.isDestructive {
            return isHovered ? Color.red.opacity(0.4) : Color(nsColor: .separatorColor).opacity(0.5)
        } else {
            return isHovered ? Color.accentColor.opacity(0.4) : Color(nsColor: .separatorColor).opacity(0.5)
        }
    }
}
