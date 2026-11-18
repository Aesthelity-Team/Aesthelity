import SwiftUI

struct LayeringGuidanceView: View {
    let steps: [RoutineStepItem]
    let period: RoutinePeriod

    var body: some View {
        let guidance = LayeringGuidance.evaluate(steps, period: period)
        VStack(alignment: .leading, spacing: 12) {
            Text(guidance.isIncomplete ? "Layering order is uncertain" : "Suggested layering order")
                .font(.headline)
            if guidance.isIncomplete {
                Text("Your saved order is shown. We need more product information to suggest a complete sequence.")
            }
            ForEach(Array(guidance.steps.enumerated()), id: \.offset) { index, step in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(index + 1). \(step.name)").font(.subheadline.bold())
                    Text(step.explanation).font(.caption)
                }
            }
            ForEach(Array(guidance.cautions.enumerated()), id: \.offset) { _, caution in
                Text(caution).font(.caption)
            }
            Text(LayeringGuidance.disclaimer).font(.caption)
            if let sourceURL = LayeringGuidance.sourceURL {
                Link("Source · American Academy of Dermatology", destination: sourceURL)
                    .font(.caption)
            }
        }
        .foregroundStyle(Constants.semanticInkPrimary)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Constants.semanticSurfaceRaised, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("layering-guidance")
    }
}
