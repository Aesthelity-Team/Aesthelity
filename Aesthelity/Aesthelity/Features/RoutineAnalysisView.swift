import SwiftUI

/// Personal entry point. Demo scenarios never stand in for the selected routine.
struct RoutineAnalysisView: View {
    let routineName: String
    let steps: [RoutineStepItem]
    let onDismiss: () -> Void
    @State private var showDemo = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(routineName).font(.title2.bold())
                    if steps.isEmpty {
                        Text("Add products to your routine to prepare for analysis.")
                    } else {
                        ForEach(steps) { step in
                            Text("\(step.stepNumber). \(step.title)")
                        }
                    }
                    Label("Personal routine analysis is not yet available", systemImage: "info.circle")
                        .font(.headline)
                    Text("No compatibility assessment has been generated for this routine. Demo findings do not describe your products or skin profile.")
                        .foregroundStyle(.secondary)
                    Button("Demo / Dev Mode") { showDemo = true }
                        .accessibilityIdentifier("open-analysis-demo")
                    Text("Explore fictional scenarios using a local demo server or bundled sample findings.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .navigationTitle("Routine analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back", action: onDismiss)
                }
            }
            .sheet(isPresented: $showDemo) {
                LiveAnalysisView(onDismiss: { showDemo = false })
            }
        }
    }
}
