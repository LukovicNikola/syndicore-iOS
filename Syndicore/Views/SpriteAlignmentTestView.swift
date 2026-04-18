import SwiftUI
import SpriteKit

/// Dev tool za vizuelno testiranje sprite alignment-a.
/// Ulaz preko SettingsView → "Sprite Alignment Test".
///
/// Flow: klikniš building type iz picker-a, sprajt se postavlja na grid sa debug overlay-em.
/// Ako diamond plinth iz sprajta poklapa cyan tile diamond outline → alignment je tačan.
struct SpriteAlignmentTestView: View {

    @State private var scene: SpriteAlignmentTestScene = {
        let s = SpriteAlignmentTestScene(size: CGSize(width: 400, height: 800))
        s.scaleMode = .resizeFill
        return s
    }()

    @State private var selectedMode: Mode = .hq
    @State private var selectedBuilding: BuildingType = .BARRACKS
    @State private var selectedCol: Int = 1
    @State private var selectedRow: Int = 2

    enum Mode: String, CaseIterable, Identifiable {
        case hq = "HQ (2×2)"
        case building = "1×1 Building"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Scene
            SpriteView(scene: scene)
                .ignoresSafeArea(edges: .top)
                .frame(maxHeight: .infinity)

            // Controls
            VStack(spacing: 12) {
                Picker("Mode", selection: $selectedMode) {
                    ForEach(Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if selectedMode == .building {
                    Picker("Building", selection: $selectedBuilding) {
                        ForEach(BuildingType.allCases.filter { $0 != .HQ }, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Stepper("Col: \(selectedCol)", value: $selectedCol, in: 0...5)
                        Stepper("Row: \(selectedRow)", value: $selectedRow, in: 0...5)
                    }
                    .font(.footnote.monospacedDigit())

                    Text(positionStatusText)
                        .font(.caption)
                        .foregroundStyle(positionStatusColor)
                }

                Legend()
            }
            .padding()
            .background(.thinMaterial)
        }
        .navigationTitle("Sprite Alignment Test")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { applyCurrent() }
        .onChange(of: selectedMode) { _, _ in applyCurrent() }
        .onChange(of: selectedBuilding) { _, _ in applyCurrent() }
        .onChange(of: selectedCol) { _, _ in applyCurrent() }
        .onChange(of: selectedRow) { _, _ in applyCurrent() }
    }

    // MARK: - Logic

    private func applyCurrent() {
        switch selectedMode {
        case .hq:
            scene.showHQ()
        case .building:
            scene.showBuilding(selectedBuilding, col: selectedCol, row: selectedRow)
        }
    }

    private var positionStatusText: String {
        if Isometric.isCutout(col: selectedCol, row: selectedRow) {
            return "⚠️ (\(selectedCol),\(selectedRow)) je u corner cutout-u — nema tile-a tu"
        }
        if Isometric.isHQ(col: selectedCol, row: selectedRow) {
            return "⚠️ (\(selectedCol),\(selectedRow)) je HQ region — prebaci u HQ mode"
        }
        return "✓ (\(selectedCol),\(selectedRow)) — buildable"
    }

    private var positionStatusColor: Color {
        if Isometric.isCutout(col: selectedCol, row: selectedRow) { return .orange }
        if Isometric.isHQ(col: selectedCol, row: selectedRow) { return .red }
        return .green
    }
}

// MARK: - Legend subview

private struct Legend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DEBUG OVERLAY LEGEND")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                LegendDot(color: Color(red: 0, green: 0.88, blue: 1), label: "tile diamond")
                LegendDot(color: Color(red: 1, green: 0.2, blue: 0.8), label: "anchor")
            }
            HStack(spacing: 10) {
                LegendDot(color: Color(red: 1, green: 0.6, blue: 0), label: "HQ 2×2")
                LegendDot(color: .red, label: "cutout")
            }
        }
        .font(.caption2)
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        SpriteAlignmentTestView()
    }
}
