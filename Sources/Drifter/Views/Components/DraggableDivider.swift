import SwiftUI
import AppKit

struct DraggableDivider: View {
    @Binding var width: CGFloat
    var minWidth: CGFloat
    var maxWidth: CGFloat
    var defaultWidth: CGFloat? = nil

    @State private var dragStartWidth: CGFloat? = nil
    @State private var isHovering = false

    init(width: Binding<CGFloat>, minWidth: CGFloat = 160, maxWidth: CGFloat = 500, defaultWidth: CGFloat? = nil) {
        self._width = width
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.defaultWidth = defaultWidth
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1)
        }
        .frame(width: 7)
        .contentShape(Rectangle())
        .onHover { inside in
            isHovering = inside
            if inside {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
        }
        .onTapGesture(count: 2) {
            if let defaultW = defaultWidth {
                withAnimation(.easeInOut(duration: 0.15)) {
                    width = defaultW
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if dragStartWidth == nil {
                        dragStartWidth = width
                    }
                    let base = dragStartWidth ?? width
                    let newWidth = base + value.translation.width
                    width = max(minWidth, min(maxWidth, newWidth))
                }
                .onEnded { _ in
                    dragStartWidth = nil
                }
        )
    }
}
