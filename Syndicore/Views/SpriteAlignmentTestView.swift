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

    // MARK: - Zoom / pan state (sync-uje se iz scene callback-a)

    @State private var currentGridZoom: Double = 1.0
    @State private var currentPan: CGPoint = .zero

    // MARK: - Live tuning state — sprite

    @State private var anchorX: Double = 0.50
    @State private var anchorY: Double = 0.25
    @State private var scaleMultiplier: Double = 1.00
    @State private var rotationDegrees: Double = 0.00
    @State private var cameraZoom: Double = 1.00


    enum Mode: String, CaseIterable, Identifiable {
        case hq       = "HQ"
        case building = "1×1"
        case grid     = "Grid"
        case cityZoom = "Zoom"
        var id: String { rawValue }
    }

    var body: some View {
        withSpriteObservers(layout)
            .onAppear {
                scene.onZoomChanged = { zoom in
                    currentGridZoom = Double(zoom)
                    if selectedMode == .cityZoom { autoCopy() }
                }
                scene.onPanChanged = { pan in
                    currentPan = pan
                    if selectedMode == .cityZoom { autoCopy() }
                }
                applyCurrent()
            }
    }

    private func withSpriteObservers<V: View>(_ v: V) -> some View {
        v
            .onChange(of: selectedMode)      { _, _ in applyCurrent() }
            .onChange(of: selectedBuilding)  { _, _ in applyCurrent() }
            .onChange(of: selectedCol)       { _, _ in applyCurrent() }
            .onChange(of: selectedRow)       { _, _ in applyCurrent() }
            .onChange(of: anchorX)           { _, _ in applyCurrent() }
            .onChange(of: anchorY)           { _, _ in applyCurrent() }
            .onChange(of: scaleMultiplier)   { _, _ in applyCurrent() }
            .onChange(of: rotationDegrees)   { _, _ in applyCurrent() }
            .onChange(of: cameraZoom)        { _, v in scene.setZoom(CGFloat(v)) }
    }

    private var layout: some View {
        Group {
            if selectedMode == .cityZoom {
                zoomFullscreen
            } else if selectedMode == .grid {
                gridLayout
            } else {
                normalLayout
            }
        }
        .navigationTitle("Sprite Alignment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") { resetToDefaults() }
                    .font(.footnote)
            }
        }
    }

    /// Zoom mode — scena full screen, floating picker + info badge.
    private var zoomFullscreen: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: scene)
                .ignoresSafeArea()

            // Floating mode picker pri vrhu
            modePicker
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .background(.ultraThinMaterial.opacity(0.85))

            // Mini info badge — bottom trailing
            VStack(alignment: .trailing, spacing: 3) {
                Spacer()
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(String(format: "%.2f ×", currentGridZoom))
                            .font(.system(.callout, design: .monospaced).bold())
                        Text(String(format: "x: %.0f  y: %.0f", currentPan.x, currentPan.y))
                            .font(.system(.caption, design: .monospaced))
                        Text("📋 copied on change")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding([.trailing, .bottom], 20)
                }
            }
        }
    }

    /// Grid editor mode — full screen tile layout editor.
    private var gridLayout: some View {
        VStack(spacing: 0) {
            modePicker
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .background(.thinMaterial)
            TileGridEditorView()
        }
    }

    /// HQ / 1×1 mode — scene + bottom controls panel.
    private var normalLayout: some View {
        VStack(spacing: 0) {
            SpriteView(scene: scene)
                .ignoresSafeArea(edges: .top)
                .frame(maxHeight: .infinity)

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
            .frame(maxHeight: 380)
            .background(.thinMaterial)
        }
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

    private func autoCopy() {
        UIPasteboard.general.string = zoomCode
    }

    private var zoomCode: String {
        "static let defaultZoom: CGFloat = \(String(format: "%.2f", currentGridZoom))\nstatic let defaultPan:  CGPoint = CGPoint(x: \(String(format: "%.0f", currentPan.x)), y: \(String(format: "%.0f", currentPan.y)))"
    }

    private var tuningSliders: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LIVE TUNING")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            labeledSlider(label: "Anchor X",  value: $anchorX,         range: 0.0...1.0, format: "%.3f")
            labeledSlider(label: "Anchor Y",  value: $anchorY,         range: 0.0...1.0, format: "%.3f")
            labeledSlider(label: "Scale ×",   value: $scaleMultiplier, range: 0.5...3.0, format: "%.2f")
            labeledSlider(label: "Rotation°", value: $rotationDegrees, range: -45...45,  format: "%+.1f°")
            Text(effectiveRenderHeightText)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)

            labeledSlider(label: "Zoom 🔍", value: $cameraZoom, range: 0.5...6.0, format: "%.2f")
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
        let (title, code) = generatedCode
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            Text(code)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
                UIPasteboard.general.string = code
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

    /// Vraća (naslov sekcije, kod za kopiranje) za trenutni mode.
    private var generatedCode: (String, String) {
        ("COPY INTO SpriteSpec.swift", generatedSpriteSpecCode)
    }

    private var generatedSpriteSpecCode: String {
        let anchorStr = String(format: "CGPoint(x: %.3f, y: %.3f)", anchorX, anchorY)
        let scaleStr  = String(format: "%.2f", scaleMultiplier)
        let rotStr    = String(format: "%.1f", rotationDegrees)
        let zoomStr   = String(format: "%.2f", cameraZoom)
        let base      = selectedMode == .hq ? "Isometric.tileWidth * 2" : "Isometric.tileWidth"
        let footprint = selectedMode == .hq ? "(cols: 2, rows: 2)" : "(cols: 1, rows: 1)"
        let assetName = selectedMode == .hq
            ? "hq_pyramid_v1"
            : "\(selectedBuilding.rawValue.lowercased())_v1"
        let rotationLine = abs(rotationDegrees) < 0.05 ? "" : ",\n    rotationDegrees: \(rotStr)"
        return """
        SpriteSpec(
            assetName: "\(assetName)",
            footprint: \(footprint),
            renderHeight: \(base) * \(scaleStr),
            anchor: \(anchorStr)\(rotationLine)
        )

        // CityScene.swift — ako menjao zoom:
        // static let defaultZoom: CGFloat = \(zoomStr)
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
        switch selectedMode {
        case .hq:
            scene.showHQ(
                anchor: CGPoint(x: anchorX, y: anchorY),
                scaleMultiplier: CGFloat(scaleMultiplier),
                rotationDegrees: CGFloat(rotationDegrees)
            )
        case .building:
            scene.showBuilding(
                selectedBuilding,
                col: selectedCol, row: selectedRow,
                anchor: CGPoint(x: anchorX, y: anchorY),
                scaleMultiplier: CGFloat(scaleMultiplier),
                rotationDegrees: CGFloat(rotationDegrees)
            )
        case .grid, .cityZoom:
            scene.clearTestSprites()
        }
    }

    private func resetToDefaults() {
        switch selectedMode {
        case .hq, .building:
            anchorX = 0.50; anchorY = 0.25; scaleMultiplier = 1.00
            rotationDegrees = 0.00; cameraZoom = 1.00
        case .grid:
            break   // TileGridEditorView handles its own reset
        case .cityZoom:
            scene.setZoom(1.0)
        }
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    NavigationStack {
        SpriteAlignmentTestView()
    }
}
