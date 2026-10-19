import SwiftUI

/// Сетка пресетов + произвольная длительность.
/// Активная длительность залита, длительность по умолчанию (последняя) обведена.
struct DurationPicker: View {
    let presets: [Int]
    let tint: Color
    let activeMinutes: Int?
    let defaultMinutes: Int
    let onPick: (Int) -> Void

    @State private var custom = 90

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(presets, id: \.self) { minutes in
                    Button(DurationFormat.chip(minutes)) { onPick(minutes) }
                        .buttonStyle(ChipStyle(
                            tint: tint,
                            isActive: activeMinutes == minutes,
                            isDefault: defaultMinutes == minutes
                        ))
                }
            }

            HStack(spacing: 8) {
                Text("Своё:")
                    .foregroundStyle(.secondary)
                Text(DurationFormat.short(custom))
                    .monospacedDigit()
                    .frame(minWidth: 70, alignment: .leading)
                Stepper("", onIncrement: increment, onDecrement: decrement)
                    .labelsHidden()
                Spacer()
                Button("Старт") { onPick(custom) }
                    .buttonStyle(ChipStyle(
                        tint: tint,
                        isActive: activeMinutes == custom && !presets.contains(custom),
                        isDefault: defaultMinutes == custom && !presets.contains(custom)
                    ))
                    .frame(width: 64)
            }
            .font(.system(size: 12))
        }
        .onAppear {
            if defaultMinutes > 0 && !presets.contains(defaultMinutes) {
                custom = defaultMinutes
            }
        }
    }

    // Шаг 5 минут до часа, дальше — 15 минут. Максимум сутки.
    private func increment() {
        custom = min(custom + (custom < 60 ? 5 : 15), 24 * 60)
    }

    private func decrement() {
        custom = max(custom - (custom <= 60 ? 5 : 15), 5)
    }
}

struct ChipStyle: ButtonStyle {
    let tint: Color
    let isActive: Bool
    let isDefault: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        configuration.label
            .font(.system(size: 12, weight: isActive ? .semibold : .regular))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .frame(height: 26)
            .foregroundStyle(isActive ? Color.white : Color.primary)
            .background(shape.fill(
                isActive ? tint : Color.primary.opacity(configuration.isPressed ? 0.16 : 0.07)
            ))
            .overlay(shape.strokeBorder(tint.opacity(isDefault && !isActive ? 0.9 : 0), lineWidth: 1))
            .contentShape(shape)
    }
}

/// Выбор одного варианта из нескольких в виде ряда чипов (растягивается на всю ширину, в отличие от segmented).
struct ChipPicker<Value: Hashable & Identifiable>: View {
    let options: [Value]
    let title: (Value) -> String
    @Binding var selection: Value
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options) { option in
                Button(title(option)) { selection = option }
                    .buttonStyle(ChipStyle(tint: tint, isActive: selection == option, isDefault: false))
            }
        }
    }
}
