import SwiftUI

/// A segmented volume bar in the style of the macOS volume HUD: 16 discrete
/// blocks, one per press of the volume key. Click or drag to set the level; the
/// value snaps to whole steps. A volume set elsewhere that falls between steps
/// shows as a partly filled block, so the bar never misreports the real level.
struct StepVolumeBar: View {
    @Binding var value: Float
    static let defaultSteps = 16
    var steps: Int = defaultSteps
    var tint: Color = .accentColor

    private let blockHeight: CGFloat = 8
    private let gap: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let blockWidth = max((geo.size.width - gap * CGFloat(steps - 1)) / CGFloat(steps), 1)
            let filled = CGFloat(min(max(value, 0), 1)) * CGFloat(steps)

            HStack(spacing: gap) {
                ForEach(0..<steps, id: \.self) { index in
                    let fill = min(max(filled - CGFloat(index), 0), 1)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(tint)
                            .frame(width: blockWidth * fill)
                    }
                    .frame(width: blockWidth, height: blockHeight)
                }
            }
            .contentShape(Rectangle().inset(by: -5))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let fraction = min(max(drag.location.x / geo.size.width, 0), 1)
                        let step = (fraction * CGFloat(steps)).rounded()
                        let newValue = Float(step) / Float(steps)
                        if newValue != value { value = newValue }
                    }
            )
        }
        .frame(height: blockHeight)
    }
}
