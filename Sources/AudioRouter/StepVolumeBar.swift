import SwiftUI

/// A row of numbered circles, one per volume level from 0 to `maxValue`. Click
/// or drag across them to pick a level. Every circle at or below the current
/// volume is lit.
struct StepVolumeBar: View {
    @Binding var value: Float
    /// Number of steps above zero; the bar shows `steps + 1` circles.
    var steps: Int = 5
    /// The volume the last circle stands for (1 = 100%).
    var maxValue: Float = 1
    var tint: Color = .accentColor

    private let dotSize: CGFloat = 22

    private func level(_ index: Int) -> Float {
        Float(index) / Float(steps) * maxValue
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(0...steps, id: \.self) { index in
                    // Small tolerance so a level read back from Core Audio as
                    // 0.39999 still lights the 40 circle.
                    let lit = value + 0.001 >= level(index)
                    Text("\(Int((level(index) * 100).rounded()))")
                        .font(.system(size: 9, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(lit ? Color.white : Color.secondary)
                        .frame(width: dotSize, height: dotSize)
                        .background(Circle().fill(lit ? tint : Color.white.opacity(0.12)))
                    if index < steps { Spacer(minLength: 2) }
                }
            }
            .contentShape(Rectangle().inset(by: -4))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let fraction = min(max(drag.location.x / geo.size.width, 0), 0.9999)
                        let index = Int(fraction * CGFloat(steps + 1))
                        let newValue = level(index)
                        if newValue != value { value = newValue }
                    }
            )
        }
        .frame(height: dotSize)
    }
}
