import SwiftUI

/// A timeline that thickens while dragged, notches at chapter boundaries and floats a preview above the playhead.
/// Values are fractions of the timeline; the caller owns the position.
public struct Scrubber<Preview: View>: View {
    private let value: Double
    private let isEditing: Bool
    private let chapterMarks: [Double]
    private let precision: ScrubPrecision
    private let accessibilityStep: Double
    private let accessibilityValue: String
    private let onEditingChanged: (Bool) -> Void
    private let onChange: (Double) -> Void
    private let preview: Preview

    @State private var width: CGFloat = 1
    @State private var drag: (value: Double, translation: CGFloat)?
    @State private var previewSize = CGSize.zero
    @ScaledMetric(relativeTo: .body) private var restingThickness = 5.0
    @ScaledMetric(relativeTo: .body) private var editingThickness = 14.0
    @ScaledMetric(relativeTo: .body) private var previewGap = 14.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        value: Double,
        isEditing: Bool,
        chapterMarks: [Double] = [],
        precision: ScrubPrecision = .standard,
        accessibilityStep: Double = 0.05,
        accessibilityValue: String,
        onEditingChanged: @escaping (Bool) -> Void,
        onChange: @escaping (Double) -> Void,
        @ViewBuilder preview: () -> Preview
    ) {
        self.value = value
        self.isEditing = isEditing
        self.chapterMarks = chapterMarks
        self.precision = precision
        self.accessibilityStep = accessibilityStep
        self.accessibilityValue = accessibilityValue
        self.onEditingChanged = onEditingChanged
        self.onChange = onChange
        self.preview = preview()
    }

    public var body: some View {
        let track = ChapteredTrack(marks: chapterMarks)
        let barTop = (Metrics.minimumHitTarget - editingThickness) / 2
        let previewCenter = previewCenterX(playhead: clamped(value) * width, width: width, previewWidth: previewSize.width)
        ZStack(alignment: .leading) {
            track.fill(Color.scrubberTrack)
            track.fill(Color.scrubberFill)
                .mask(alignment: .leading) {
                    Rectangle().scaleEffect(x: clamped(value), anchor: .leading)
                }
        }
        .frame(height: isEditing ? editingThickness : restingThickness)
        .frame(maxWidth: .infinity, minHeight: Metrics.minimumHitTarget)
        .contentShape(.rect)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = max($0, 1) }
        .overlay(alignment: .topLeading) {
            if isEditing {
                preview
                    .fixedSize()
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { previewSize = $0 }
                    .offset(x: previewCenter - previewSize.width / 2, y: barTop - previewGap - previewSize.height)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
                    .allowsHitTesting(false)
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.25, bounce: 0.3), value: isEditing)
        .gesture(dragGesture)
        .accessibilityElement()
        .accessibilityValue(accessibilityValue)
        .accessibilityAdjustableAction { direction in
            let step = direction == .increment ? accessibilityStep : -accessibilityStep
            onEditingChanged(true)
            onChange(clamped(value + step))
            onEditingChanged(false)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                guard let drag else {
                    drag = (value, gesture.translation.width)
                    onEditingChanged(true)
                    return
                }
                // Relative rather than absolute, so slowing down trades reach for precision instead of jumping to the finger.
                let delta = gesture.translation.width - drag.translation
                let scale = precision.scale(forSpeed: gesture.velocity.width)
                let next = clamped(drag.value + delta / width * scale)
                self.drag = (next, gesture.translation.width)
                onChange(next)
            }
            .onEnded { gesture in
                if abs(gesture.translation.width) < 4, abs(gesture.translation.height) < 4 {
                    onChange(clamped(gesture.location.x / width))
                }
                drag = nil
                onEditingChanged(false)
            }
    }

    private func clamped(_ fraction: Double) -> Double {
        min(max(fraction, 0), 1)
    }
}

extension Scrubber where Preview == EmptyView {
    public init(
        value: Double,
        isEditing: Bool,
        chapterMarks: [Double] = [],
        accessibilityValue: String,
        onEditingChanged: @escaping (Bool) -> Void,
        onChange: @escaping (Double) -> Void
    ) {
        self.init(
            value: value,
            isEditing: isEditing,
            chapterMarks: chapterMarks,
            accessibilityValue: accessibilityValue,
            onEditingChanged: onEditingChanged,
            onChange: onChange
        ) {
            EmptyView()
        }
    }
}

// Keeps the preview centered over the playhead without running off either end of the track.
private func previewCenterX(playhead: CGFloat, width: CGFloat, previewWidth: CGFloat) -> CGFloat {
    let upper = max(width - previewWidth / 2, previewWidth / 2)
    return min(max(playhead, previewWidth / 2), upper)
}

/// Rounded segments split at each mark. A shape rather than a Canvas so the thickness change animates its path.
private struct ChapteredTrack: Shape {
    let marks: [Double]

    func path(in rect: CGRect) -> Path {
        let gap = min(rect.height * 0.4, 3)
        let interior = marks.filter { $0 > 0.005 && $0 < 0.995 }.sorted()
        let bounds = [0] + interior + [1]
        var path = Path()
        for (start, end) in zip(bounds, bounds.dropFirst()) {
            let leading = rect.minX + start * rect.width + (start > 0 ? gap / 2 : 0)
            let trailing = rect.minX + end * rect.width - (end < 1 ? gap / 2 : 0)
            guard trailing > leading else { continue }
            let segment = CGRect(x: leading, y: rect.minY, width: trailing - leading, height: rect.height)
            path.addRoundedRect(in: segment, cornerSize: CGSize(width: rect.height / 2, height: rect.height / 2))
        }
        return path
    }
}

#Preview {
    @Previewable @State var value = 0.35
    @Previewable @State var isEditing = false
    Scrubber(
        value: value,
        isEditing: isEditing,
        chapterMarks: [0.2, 0.55, 0.8],
        accessibilityValue: "\(Int(value * 100)) percent",
        onEditingChanged: { isEditing = $0 },
        onChange: { value = $0 }
    ) {
        RoundedRectangle(cornerRadius: 8).fill(.gray).frame(width: 120, height: 68)
    }
    .padding(40)
}
