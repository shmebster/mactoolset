import SwiftUI

/// Карточка инструмента: плитка-иконка, название, статус, переключатель
/// и разворачиваемая панель настроек.
struct ToolCard<Detail: View>: View {
    let icon: String
    let tint: Color
    let title: String
    let status: String
    let isActive: Bool
    var isToggleEnabled = true
    let onToggle: @MainActor () -> Void
    @Binding var isExpanded: Bool
    @ViewBuilder let detail: () -> Detail

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ToolTile(icon: icon, tint: tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(status)
                        .font(.system(size: 11))
                        .foregroundStyle(isActive ? AnyShapeStyle(tint) : AnyShapeStyle(.secondary))
                        .monospacedDigit()
                        .lineLimit(1)
                        .contentTransition(.numericText())
                }

                Spacer(minLength: 8)

                Toggle("", isOn: Binding(get: { isActive }, set: { _ in onToggle() }))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
                    .tint(tint)
                    .disabled(!isToggleEnabled)

                SVGImage("chevron", size: 12)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 18, height: 18)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.snappy(duration: 0.2)) { isExpanded.toggle() }
            }

            if isExpanded {
                Divider().padding(.vertical, 10)
                detail()
                    .transition(.opacity)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(isActive ? 0.45 : 0), lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.15), value: isActive)
    }
}

struct ToolTile: View {
    let icon: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(tint.gradient)
            .frame(width: 32, height: 32)
            .overlay(SVGImage(icon, size: 19).foregroundStyle(.white))
    }
}
