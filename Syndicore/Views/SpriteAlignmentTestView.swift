import SwiftUI
import SpriteKit

/// Dev tool za vizuelno tuniranje sprite alignment-a.
/// Pomeraš anchor X/Y i scale slider-ima uživo dok se sprite plinth ne poklopi sa
/// cyan/orange debug outline-ovima. Na kraju kopiraš SpriteSpec vrednosti u kod.
struct SpriteAlignmentTestView: View {

    @State private var scene: SpriteAlignmentTestScene = {
        let s = SpriteAlignmentTestScene(size: CGSize(width: 400, height: 800))
        s.scaleMode = .resizeFill
        return s
    }()

    // MARK: - Mode / sprite selection

    @State private var selectedMode: Mode = .hq
    @State private var selectedBuilding: BuildingType = .BARRACKS
    @State private var selectedCol: Int = 1
    @State private var selectedRow: Int = 2

    // MARK: - Live tuning state (tri slider-a)

    @State private var anchorX: Double = 0.50
    @State private var anchorY: Double = 0.25
    @State private var scaleMultiplier: Double = 1.00

    enum Mode: String, CaseIterable, Identifiable {
        case hq = "HQ (2×2)"
        case building = "1×1 Building"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ==== Scene ====
            SpriteView(scene: scene)
                .ignoresSafeArea(edges: .top)
                .frame(maxHeight: .infinity)

            // ==== Controls ====
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    modePicker
                    if selectedMode == .building { buildingPicker }

                    Divider()

                    tuningSliders

                    Divider()

                    specOutput

                    Legend()
                }
                .padding()
            }
            .frame(maxHeight: 360)
            .background(.thinMaterial)
        }
        .navigationTitle("Sprite Alignment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") { resetToDefaults() }
                    .font(.footnote)
            }
        }
        .onAppear { applyCurrent() }
        .onChange(of: selectedMode) { _, _ in applyCurrent() }
        .onChange(of: selectedBuilding) { _, _ in applyCurrent() }
        .onChange(of: selectedCol) { _, _ in applyCurrent() }
        .onChange(of: selectedRow) { _, _ in applyCurrent() }
        .onChange(of: anchorX) { _, _ in applyCurrent() }
        .onChange(of: anchorY) { _, _ in applyCurrent() }
        .onChange(of: scaleMultiplier) { _, _ in applyCurrent() }
    }

    // MARK: - Subviews

    private var modePicker: some View {
        Picker("Mode", selection: $selectedMode) {
            ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    private var buildingPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Building", selection: $selectedBuilding) {
                ForEach(BuildingType.allCases.filter { $0 != .HQ }, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.menu)

            HStack(spacing: 12) {
                Stepper("Col: \(selectedCol)", value: $selectedCol, in: 0...5)
                Stepper("Row: \(selectedRow)", value: $selectedRow, in: 0...5)
            }
            .font(.footnote.monospacedDigit())

            Text(positionStatusText)
                .font(.caption)
                .foregroundStyle(positionStatusColor)
        }
    }

    private var tuningSliders: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LIVE TUNING")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            labeledSlider(label: "Anchor X",
                          value: $anchorX,
                          range: 0.0...1.0,
                          format: "%.3f")

            labeledSlider(label: "Anchor Y",
                          value: $anchorY,
                          range: 0.0...1.0,
                          format: "%.3f")

            labeledSlider(label: "Scale ×",
                          value: $scaleMultiplier,
                          range: 0.5...3.0,
                          format: "%.2f")

            Text(effectiveRenderHeightText)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func labeledSlider(label: String,
                               value: Binding<Double>,
                               range: ClosedRange<Double>,
                               format: String) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.caption.monospacedDigit()).frame(width: 70, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: format, value.wrappedValue))
                .font(.caption.monospacedDigit())
                .frame(width: 50, alignment: .trailing)
        }
    }

    private var specOutput: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("COPY INTO SpriteSpec.swift")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            Text(generatedSpecCode)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
                UIPasteboard.general.string = generatedSpecCode
            } label: {
                Label("Copy to clipboard", systemImage: "doc.on.doc")
                    .font(.caption)
            }
        }
    }

    // MARK: - Computed state

    private var effectiveRenderHeightText: String {
        let base = selectedMode == .hq ? Isometric.tileWidth * 2 : Isometric.tileWidth
        let final = base * CGFloat(scaleMultiplier)
        return "renderHeight = \(Int(final)) units (base=\(Int(base)) × \(String(format: "%.2f", scaleMultiplier)))"
    }

    private var generatedSpecCode: String {
        let anchorStr = String(format: "CGPoint(x: %.3f, y: %.3f)", anchorX, anchorY)
        let scaleStr = String(format: "%.2f", scaleMultiplier)
        let base = selectedMode == .hq ? "Isometric.tileWidth * 2" : "Isometric.tileWidth"
        let footprint = selectedMode == .hq ? "(cols: 2, rows: 2)" : "(cols: 1, rows: 1)"

        let assetName: String
        switch selectedMode {
        case .hq: assetName = "hq_pyramid_v1"
        case .building: assetName = "\(selectedBuilding.rawValue.lowercased())_v1"
        }

        return """
        SpriteSpec(
            assetName: "\(assetName)",
            footprint: \(footprint),
            renderHeight: \(base) * \(scaleStr),
            anchor: \(anchorStr)
        )
        """
    }

    private var positionStatusText: String {
        if Isometric.isCutout(col: selectedCol, row: selectedRow) {
            return "⚠️ (\(selectedCol),\(selectedRow)) je cutout — nema tile-a"
        }
        if Isometric.isHQ(col: selectedCol, row: selectedRow) {
            return "⚠️ (\(selectedCol),\(selectedRow)) je HQ region — switch to HQ mode"
        }
        return "✓ (\(selectedCol),\(selectedRow)) — buildable"
    }

    private var positionStatusColor: Color {
        if Isometric.isCutout(col: selectedCol, row: selectedRow) { return .orange }
        if Isometric.isHQ(col: selectedCol, row: selectedRow) { return .red }
        return .green
    }

    // MARK: - Actions

    private func applyCurrent() {
        let anchor = CGPoint(x: anchorX, y: anchorY)
        let scale = CGFloat(scaleMultiplier)

        switch selectedMode {
        case .hq:
            scene.showHQ(anchor: anchor, scaleMultiplier: scale)
        case .building:
            scene.showBuilding(selectedBuilding,
                               col: selectedCol,
                               row: selectedRow,
                               anchor: anchor,
                               scaleMultiplier: scale)
        }
    }

    private func resetToDefaults() {
        anchorX = 0.50
        anchorY = 0.25
        scaleMultiplier = 1.00
    }
}

// MARK: - Legend subview

private struct Legend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DEBUG OVERLAY")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                LegendDot(color: Color(red: 0, green: 0.88, blue: 1), label: "tile diamond")
                LegendDot(color: Color(red: 1, green: 0.2, blue: 0.8), label: "anchor target")
            }
            HStack(spacing: 10) {
                LegendDot(color: Color(red: 1, green: 0.6, blue: 0), label: "HQ 2×2")
                LegendDot(color: .red, label: "cutout")
            }

            Text("Kad se plinth sprajta poklopi sa cyan tile outline-om (za 1×1) ili orange 2×2 outline-om (za HQ) — alignment je tačan. Magenta tačka mora biti na centru plinth-a.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
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
        .font(.caption2)
    }
}

#Preview {
    NavigationStack {
        SpriteAlignmentTestView()
    }
}
