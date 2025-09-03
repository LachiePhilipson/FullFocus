import SwiftUI

struct ControlCenterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ControlCenterButton(configuration: configuration)
    }

    private struct ControlCenterButton: View {
        let configuration: Configuration
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(backgroundColor)
                )
                .contentShape(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .onHover { hovering in
                    isHovered = hovering
                }
        }

        private var backgroundColor: Color {
            if configuration.isPressed {
                return Color.gray.opacity(0.1)
            } else if isHovered {
                return Color.gray.opacity(0.2)
            } else {
                return Color.clear
            }
        }
    }
}

