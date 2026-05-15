import SwiftUI

// MARK: - Octagonal Frame Shape

/// Eight-sided polygon with straight diagonal corner cuts —
/// matches the nameplate_master / nav-button visual language.
struct CyberpunkOctagon: Shape {
    var cornerCut: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        let c = min(cornerCut, min(rect.width, rect.height) * 0.25)
        var p = Path()
        p.move(to:    CGPoint(x: rect.minX + c, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX,     y: rect.minY + c))
        p.addLine(to: CGPoint(x: rect.maxX,     y: rect.maxY - c))
        p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + c, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX,     y: rect.maxY - c))
        p.addLine(to: CGPoint(x: rect.minX,     y: rect.minY + c))
        p.closeSubpath()
        return p
    }
}

// MARK: - Reusable Panel Chrome

/// Consistent chrome wrapper for all dashboard panels.
struct CyberpunkPanel<Content: View>: View {
    let title: String
    var accentColor: Color = .cyan
    var minHeight: CGFloat? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 2, height: 10)
                Text(title)
                    .font(.gameLabel(9))
                    .foregroundStyle(accentColor)
                    .tracking(1.8)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(accentColor.opacity(0.07))

            content()
                .padding(10)
                .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        }
        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
        .clipShape(CyberpunkOctagon(cornerCut: 10))
        .overlay {
            CyberpunkOctagon(cornerCut: 10)
                .stroke(accentColor, lineWidth: 1.2)
        }
        .overlay {
            CyberpunkOctagon(cornerCut: 10)
                .stroke(accentColor.opacity(0.25), lineWidth: 0.5)
                .padding(3)
        }
        .shadow(color: accentColor.opacity(0.22), radius: 10)
    }
}

// MARK: - Empire Overview View

struct EmpireOverviewView: View {
    @Environment(GameState.self) private var gameState

    @State private var showTacticalMap = false
    @State private var syndicats:       [Syndikat] = []
    @State private var empireOverview:  EmpireOverviewResponse?
    @State private var minimapData:     MinimapResponse?

    // Animation states
    @State private var appeared       = false
    @State private var headerGlow     = false
    @State private var youPulse       = false
    @State private var outerRingAngle = 0.0
    @State private var innerRingAngle = 0.0
    @State private var ringFlash      = false
    @State private var panel1In       = false
    @State private var panel2In       = false
    @State private var panel3In       = false
    @State private var panel4In       = false
    @State private var didLoad        = false

    private var playerRing: Ring? { gameState.activePlayerWorld?.ring }
    private var worldId:    String? { gameState.activePlayerWorld?.worldId }

    private var activeRingStats: EmpireRingStats? {
        empireOverview?.rings.first(where: { $0.ringType == playerRing })?.stats
    }

    var body: some View {
        ZStack {
            atmosphericBackground

            if showTacticalMap {
                MapView(onDismiss: {
                    withAnimation(.easeInOut(duration: 0.35)) { showTacticalMap = false }
                })
                .transition(.opacity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        pageHeader
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : -10)

                        // Full-width minimap
                        minimapSection
                            .opacity(appeared ? 1 : 0)
                            .scaleEffect(appeared ? 1 : 0.96)

                        // 3 stat cards
                        statsCardsRow
                            .opacity(appeared ? 1 : 0)

                        // 4 dashboard panels — 2 × 2 grid
                        dashboardGrid
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 54)
                    .padding(.bottom, 90)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showTacticalMap)
        .overlay(alignment: .top) {
            if !showTacticalMap {
                CyberpunkResourceBar(
                    items: ResourceItem.from(gameState.activeCity?.resources, premium: gameState.premium)
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .overlay(alignment: .topTrailing) {
            if !showTacticalMap {
                CyberpunkSideMenu(actions: sideMenuActions)
                    .padding(.trailing, 12)
                    .padding(.top, 60)
            }
        }
        .onAppear { startContinuousAnimations() }
        .task { await entranceAndLoad() }
    }

    // MARK: - Startup

    private func startContinuousAnimations() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever()) { headerGlow = true }
        withAnimation(.easeInOut(duration: 1.5).repeatForever()) { youPulse = true }
        withAnimation(.linear(duration: 720).repeatForever(autoreverses: false)) { outerRingAngle = 360 }
        withAnimation(.linear(duration: 1200).repeatForever(autoreverses: false)) { innerRingAngle = 360 }
    }

    private func entranceAndLoad() async {
        withAnimation(.easeOut(duration: 0.4)) { appeared = true }

        try? await Task.sleep(for: .seconds(0.15))
        withAnimation(.easeOut(duration: 0.35)) { panel1In = true }
        try? await Task.sleep(for: .seconds(0.1))
        withAnimation(.easeOut(duration: 0.35)) { panel2In = true }
        try? await Task.sleep(for: .seconds(0.1))
        withAnimation(.easeOut(duration: 0.35)) { panel3In = true }
        try? await Task.sleep(for: .seconds(0.1))
        withAnimation(.easeOut(duration: 0.35)) { panel4In = true }

        let api = gameState.api
        let wid = worldId

        async let overviewFetch = api.empireOverview()
        if gameState.activeReports.isEmpty { await gameState.refreshReports(limit: 10) }
        empireOverview = try? await overviewFetch

        if let wid {
            async let syndicatsFetch = api.syndikats(worldId: wid)
            async let minimapFetch   = api.minimap(worldId: wid)
            minimapData = try? await minimapFetch
            syndicats   = ((try? await syndicatsFetch) ?? [])
                .sorted { ($0.memberCount ?? 0) > ($1.memberCount ?? 0) }
        }
        didLoad = true
    }
}

// MARK: - Atmospheric Background

private extension EmpireOverviewView {
    var atmosphericBackground: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.07)
            Canvas { ctx, size in
                for y in stride(from: CGFloat(0), to: size.height, by: 4) {
                    ctx.fill(
                        Path(CGRect(x: 0, y: y, width: size.width, height: 0.5)),
                        with: .color(.white.opacity(0.022))
                    )
                }
            }
            TimelineView(.animation(minimumInterval: 0.1)) { timeline in
                Canvas { ctx, size in
                    let t = timeline.date.timeIntervalSince1970
                    for i in 0..<22 {
                        let fi = Double(i)
                        let x  = (fi * 83.0).truncatingRemainder(dividingBy: Double(size.width))
                        let by = (fi * 61.0).truncatingRemainder(dividingBy: Double(size.height))
                        let y  = (by + t * 5.0).truncatingRemainder(dividingBy: Double(size.height))
                        let a  = (sin(t * 0.35 + fi) * 0.5 + 0.5) * 0.16
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                            with: .color(Color.cyan.opacity(a))
                        )
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Header

private extension EmpireOverviewView {
    var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                Text("EMPIRE")
                    .font(.gameTitle(26))
                    .foregroundStyle(Color(red: 0, green: 0.9, blue: 1))
                Text(" OVERVIEW")
                    .font(.gameTitle(26))
                    .foregroundStyle(.white)
            }
            .shadow(color: Color.cyan.opacity(headerGlow ? 0.65 : 0.25), radius: headerGlow ? 10 : 5)

            GeometryReader { geo in
                Rectangle()
                    .fill(LinearGradient(
                        colors: [.cyan, .cyan.opacity(0.3), .clear],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: geo.size.width * 0.6, height: 1.5)
                    .opacity(headerGlow ? 1.0 : 0.45)
            }
            .frame(height: 2)

            if let ring = playerRing {
                Text("ACTIVE RING · \(ring.displayName.uppercased())")
                    .font(.gameLabel(11))
                    .foregroundStyle(Color(red: 0.36, green: 0.85, blue: 0.89))
                    .tracking(2)
            }
        }
        .padding(.top, 36)
    }
}

// MARK: - Minimap

private extension EmpireOverviewView {
    var minimapSection: some View {
        Button {
            guard playerRing != nil else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.easeIn(duration: 0.08)) { ringFlash = true }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.12))
                withAnimation { ringFlash = false }
                withAnimation(.easeInOut(duration: 0.3)) { showTacticalMap = true }
            }
        } label: {
            minimapContainer
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Empire minimap — tap to enter tactical view")
    }

    var minimapContainer: some View {
        ZStack {
            Color(red: 0.039, green: 0.059, blue: 0.094)

            ringView(ring: .fringe, size: 312, rotAngle: outerRingAngle)
            ringView(ring: .grid,   size: 240, rotAngle: innerRingAngle * 0.8)
            ringView(ring: .core,   size: 172, rotAngle: innerRingAngle * 0.6)
            ringView(ring: .nexus,  size: 102, rotAngle: innerRingAngle * 0.4)

            // NEXUS center burst
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [
                            Color(red: 0.75, green: 0.15, blue: 1.0).opacity(0.70),
                            Color(red: 0.40, green: 0.00, blue: 0.85).opacity(0.30),
                            .clear
                        ],
                        center: .center, startRadius: 0, endRadius: 50
                    ))
                    .frame(width: 96, height: 96)
                Canvas { ctx, size in
                    let c   = CGPoint(x: size.width / 2, y: size.height / 2)
                    let t   = Date().timeIntervalSince1970
                    let rot = t.truncatingRemainder(dividingBy: .pi * 2)
                    for i in 0..<8 {
                        let angle = rot + Double(i) * .pi / 4
                        let len   = CGFloat(i % 2 == 0 ? 44 : 28)
                        var p = Path()
                        p.move(to: c)
                        p.addLine(to: CGPoint(x: c.x + cos(angle) * len,
                                              y: c.y + sin(angle) * len))
                        let alpha = i % 2 == 0 ? 0.65 : 0.35
                        ctx.stroke(p, with: .color(Color(red: 0.85, green: 0.45, blue: 1.0).opacity(alpha)),
                                   style: StrokeStyle(lineWidth: i % 2 == 0 ? 1.2 : 0.7))
                    }
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x-5, y: c.y-5, width: 10, height: 10)),
                             with: .color(.white.opacity(0.9)))
                }
                .frame(width: 96, height: 96)
            }
            .allowsHitTesting(false)

            ringLabels

            if let ring = playerRing { youMarker(ring: ring) }

            if let mm = minimapData, mm.worldRadius > 0 {
                Canvas { ctx, size in
                    let radius = Double(mm.worldRadius)
                    let hw = size.width  / 2
                    let hh = size.height / 2
                    let margin = 0.88
                    for tile in mm.tiles {
                        let nx = Double(tile.x) / radius * margin
                        let ny = Double(tile.y) / radius * margin
                        let sx = hw + nx * hw
                        let sy = hh - ny * hh
                        let (dotSize, color): (CGFloat, Color) = switch tile.type {
                        case .playerCity:   (7,   .cyan)
                        case .allyCity:     (4,   Color(red: 1.0, green: 0.78, blue: 0.2))
                        case .enemyCity:    (3,   Color(red: 1,   green: 0.2,  blue: 0.2))
                        case .rogueOutpost: (2.5, .orange.opacity(0.7))
                        case .resourceMine: (2,   .green.opacity(0.6))
                        case .warpGate:     (2.5, .purple.opacity(0.8))
                        case .ruins:        (1.5, .gray.opacity(0.35))
                        }
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: sx - dotSize/2, y: sy - dotSize/2,
                                                   width: dotSize, height: dotSize)),
                            with: .color(color)
                        )
                    }
                }
                .allowsHitTesting(false)
                .mask(alignment: .center) {
                    if let ring = playerRing { ringBandMask(for: ring) }
                    else { Rectangle().fill(.white) }
                }
            }

            Color.white.opacity(ringFlash ? 0.12 : 0).allowsHitTesting(false)

            cornerCircuits
        }
        .frame(width: 340, height: 340)
        .clipShape(CyberpunkOctagon(cornerCut: 22))
        .overlay {
            CyberpunkOctagon(cornerCut: 22)
                .stroke(
                    LinearGradient(
                        colors: [.cyan, Color(red: 0.0, green: 0.6, blue: 0.85), .cyan],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .shadow(color: .cyan.opacity(0.7), radius: 12)
        }
        .overlay {
            CyberpunkOctagon(cornerCut: 22)
                .stroke(.cyan.opacity(0.18), lineWidth: 0.5)
                .padding(4)
        }
    }

    func ringView(ring: Ring, size: CGFloat, rotAngle: Double) -> some View {
        let isOwn  = playerRing == ring
        let accent = ringAccentColor(ring)
        let texName: String = switch ring {
        case .fringe: "ring_texture_fringe"
        case .grid:   "ring_texture_grid"
        case .core:   "ring_texture_core"
        case .nexus:  "ring_texture_nexus"
        }
        return ZStack {
            Circle().fill(Color(red: 0.039, green: 0.059, blue: 0.094))
            Image(texName).resizable().aspectRatio(contentMode: .fill)
                .frame(width: size, height: size).clipShape(Circle())
            Circle().stroke(Color.black.opacity(0.9), lineWidth: 3)
            Circle().stroke(accent.opacity(isOwn ? 1.0 : 0.45), lineWidth: isOwn ? 2 : 1)
            if isOwn {
                Circle()
                    .stroke(AngularGradient(colors: [.clear, accent.opacity(0.9), .clear], center: .center),
                            lineWidth: 3)
                    .rotationEffect(.degrees(rotAngle))
            }
        }
        .frame(width: size, height: size)
        .shadow(color: accent.opacity(isOwn ? 0.55 : 0.18), radius: isOwn ? 14 : 5)
    }

    func ringBandMask(for ring: Ring) -> some View {
        let (outer, inner): (CGFloat, CGFloat) = {
            switch ring {
            case .fringe: return (312, 240)
            case .grid:   return (240, 172)
            case .core:   return (172, 102)
            case .nexus:  return (102, 0)
            }
        }()
        return ZStack {
            Circle().fill(.white).frame(width: outer, height: outer)
            if inner > 0 {
                Circle().fill(.black).frame(width: inner, height: inner)
                    .blendMode(.destinationOut)
            }
        }
        .compositingGroup()
    }

    var ringLabels: some View {
        ZStack {
            ringLabel("NEXUS",  ring: .nexus,  yOffset: 0)
            ringLabel("CORE",   ring: .core,   yOffset: -68)
            ringLabel("GRID",   ring: .grid,   yOffset: -103)
            ringLabel("FRINGE", ring: .fringe, yOffset: -137)
        }
    }

    func ringLabel(_ text: String, ring: Ring, yOffset: CGFloat) -> some View {
        Text(text)
            .font(.gameHeader(8))
            .foregroundStyle(.white.opacity(0.9))
            .shadow(color: .black.opacity(0.85), radius: 2, x: 0, y: 1)
            .shadow(color: .black.opacity(0.55), radius: 4)
            .overlay(alignment: .center) {
                Text(text)
                    .font(.gameHeader(8))
                    .foregroundStyle(ringAccentColor(ring).opacity(0.20))
                    .blendMode(.screen)
            }
            .offset(y: yOffset)
    }

    func youMarker(ring: Ring) -> some View {
        let yOffset: CGFloat
        switch ring {
        case .fringe: yOffset = 137
        case .grid:   yOffset = 103
        case .core:   yOffset = 68
        case .nexus:  yOffset = 27
        }
        return ZStack {
            Image("nameplate_master")
                .resizable()
                .frame(width: 92, height: 35)
                .opacity(0.88)
            Text("YOU · \(ring.displayName.uppercased())")
                .font(.gameTitle(7))
                .foregroundStyle(.cyan)
        }
        .scaleEffect(youPulse ? 1.1 : 1.0)
        .shadow(color: .cyan.opacity(youPulse ? 0.85 : 0.45), radius: youPulse ? 9 : 4)
        .offset(y: -yOffset)
        .accessibilityLabel("Your location: \(ring.displayName) ring")
    }

    var cornerCircuits: some View {
        ZStack {
            circuitMark.offset(x: -130, y: -130)
            circuitMark.rotationEffect(.degrees(90)).offset(x: 130, y: -130)
            circuitMark.rotationEffect(.degrees(180)).offset(x: 130, y: 130)
            circuitMark.rotationEffect(.degrees(270)).offset(x: -130, y: 130)
        }
    }

    var circuitMark: some View {
        Canvas { ctx, size in
            let s = size.width
            ctx.stroke(
                Path { p in
                    p.move(to: CGPoint(x: 0, y: s * 0.65))
                    p.addLine(to: CGPoint(x: 0, y: s * 0.2))
                    p.addLine(to: CGPoint(x: s * 0.2, y: 0))
                    p.addLine(to: CGPoint(x: s * 0.65, y: 0))
                },
                with: .color(.cyan.opacity(0.55)),
                style: StrokeStyle(lineWidth: 1)
            )
            ctx.fill(
                Path(ellipseIn: CGRect(x: s * 0.58, y: -3.5, width: 5, height: 5)),
                with: .color(.cyan.opacity(0.75))
            )
        }
        .frame(width: 22, height: 22)
    }
}

// MARK: - Stat Cards Row

private extension EmpireOverviewView {
    var statsCardsRow: some View {
        HStack(spacing: 10) {
            statCard(
                icon: "person.3.fill",
                value: activeRingStats.map { "\($0.totalPlayersInWorld)" } ?? "—",
                subtitle: "PLAYERS IN RING",
                accentColor: .cyan
            )
            statCard(
                icon: "sparkle",
                value: empireOverview.map { "\($0.totalActiveRings)" } ?? "—",
                subtitle: "ACTIVE RIFTS",
                accentColor: Color(red: 0.95, green: 0.10, blue: 0.95)
            )
            statCard(
                icon: "trophy.fill",
                value: activeRingStats.map { $0.playerRank > 0 ? "#\($0.playerRank)" : "—" } ?? "—",
                subtitle: "YOUR RANK",
                accentColor: Color(red: 1.0, green: 0.82, blue: 0.0)
            )
        }
    }

    func statCard(icon: String, value: String, subtitle: String, accentColor: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(accentColor)
            Text(value)
                .font(.gameTitle(20))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(subtitle)
                .font(.gameCaption(7))
                .foregroundStyle(accentColor.opacity(0.7))
                .tracking(0.8)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(red: 0.09, green: 0.11, blue: 0.17))
        .clipShape(CyberpunkOctagon(cornerCut: 8))
        .overlay {
            CyberpunkOctagon(cornerCut: 8)
                .stroke(accentColor.opacity(0.5), lineWidth: 1.2)
        }
        .shadow(color: accentColor.opacity(0.2), radius: 8)
    }
}

// MARK: - Dashboard Grid

private extension EmpireOverviewView {
    var dashboardGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            syndicatesPanel
                .opacity(panel1In ? 1 : 0).offset(y: panel1In ? 0 : 16)
            threatsPanel
                .opacity(panel2In ? 1 : 0).offset(y: panel2In ? 0 : 16)
            alliesPanel
                .opacity(panel3In ? 1 : 0).offset(y: panel3In ? 0 : 16)
            eventsPanel
                .opacity(panel4In ? 1 : 0).offset(y: panel4In ? 0 : 16)
        }
    }

    // MARK: Panel 1 — Top Syndicates

    var syndicatesPanel: some View {
        CyberpunkPanel(title: "TOP SYNDICATES", accentColor: .cyan, minHeight: 110) {
            if !didLoad {
                panelSpinner
            } else if syndicats.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "person.3").font(.system(size: 16)).foregroundStyle(.cyan.opacity(0.28))
                    Text("No syndicates yet")
                        .font(.gameCaption(8)).foregroundStyle(.white.opacity(0.28))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 8)
            } else {
                VStack(spacing: 7) {
                    ForEach(Array(syndicats.prefix(3).enumerated()), id: \.element.id) { idx, s in
                        HStack(spacing: 6) {
                            Text("#\(idx + 1)")
                                .font(.gameTitle(9))
                                .foregroundStyle(rankColor(idx + 1))
                                .frame(width: 20, alignment: .leading)
                            Text("[\(s.tag)]")
                                .font(.gameHeader(9))
                                .foregroundStyle(.white.opacity(0.88))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if let n = s.memberCount {
                                Label("\(n)", systemImage: "person.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.white.opacity(0.38))
                            }
                        }
                    }
                }
            }
        }
    }

    func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: Color(red: 1.0,  green: 0.82, blue: 0.0)
        case 2: Color(red: 0.75, green: 0.75, blue: 0.75)
        default: Color(red: 0.72, green: 0.45, blue: 0.20)
        }
    }

    // MARK: Panel 2 — Active Threats

    var threatsPanel: some View {
        let attack = gameState.socket.lastIncomingAttack
        return CyberpunkPanel(
            title: "ACTIVE THREATS",
            accentColor: attack != nil ? .red : .cyan,
            minHeight: 110
        ) {
            if let atk = attack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10)).foregroundStyle(.red)
                        Text("INCOMING \(atk.type.rawValue)")
                            .font(.gameHeader(8)).foregroundStyle(.red)
                    }
                    if let name = atk.attackerName {
                        Text("From: \(name)")
                            .font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.system(size: 8)).foregroundStyle(.orange)
                        CountdownLabel(endsAt: atk.arrivesAt)
                            .font(.gameHeader(9)).foregroundStyle(.orange)
                    }
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        gameState.selectedTab = .army
                    } label: {
                        Text("Mobilize →")
                            .font(.gameLabel(7)).foregroundStyle(.red.opacity(0.7))
                    }
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 22)).foregroundStyle(.green.opacity(0.45))
                    Text("ZONE CLEAR")
                        .font(.gameHeader(9)).foregroundStyle(.green.opacity(0.6))
                    Text("No incoming threats")
                        .font(.system(size: 8)).foregroundStyle(.white.opacity(0.22))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 6)
            }
        }
    }

    // MARK: Panel 3 — Allies by Ring

    var alliesPanel: some View {
        CyberpunkPanel(title: "ALLIES BY RING", accentColor: .green, minHeight: 110) {
            if !didLoad { panelSpinner } else { allyRingContent }
        }
    }

    var allyRingContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let top = syndicats.first {
                HStack(spacing: 4) {
                    Image(systemName: "person.3.fill").font(.system(size: 8)).foregroundStyle(.green.opacity(0.6))
                    Text("\(top.memberCount ?? 0) in [\(top.tag)]")
                        .font(.gameLabel(8)).foregroundStyle(.white.opacity(0.7))
                }
            }
            ForEach(Ring.allCases, id: \.self) { ring in
                HStack(spacing: 6) {
                    Text(ring.displayName)
                        .font(.gameCaption(7))
                        .foregroundStyle(ringBaseColor(ring).opacity(0.8))
                        .frame(width: 34, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.06))
                            if ring == playerRing {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(LinearGradient(
                                        colors: [ringBaseColor(ring), ringBaseColor(ring).opacity(0.4)],
                                        startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * 0.65)
                            }
                        }
                    }
                    .frame(height: 5)
                }
            }
            let total = syndicats.reduce(0) { $0 + ($1.memberCount ?? 0) }
            Text("TOTAL · \(total) ACROSS ALL SYNDICATES")
                .font(.gameCaption(6))
                .foregroundStyle(.white.opacity(0.28))
                .padding(.top, 2)
        }
    }

    // MARK: Panel 4 — Recent Events

    var eventsPanel: some View {
        CyberpunkPanel(title: "RECENT EVENTS", accentColor: .orange, minHeight: 110) {
            if gameState.activeReports.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "scroll").font(.system(size: 18)).foregroundStyle(.orange.opacity(0.28))
                    Text("No recent events")
                        .font(.gameCaption(8)).foregroundStyle(.white.opacity(0.22))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(gameState.activeReports.prefix(4))) { report in
                        HStack(spacing: 6) {
                            Image(systemName: report.isAttacker ? "shield.lefthalf.filled" : "shield.fill")
                                .font(.system(size: 9))
                                .foregroundStyle((report.attackerWon == report.isAttacker) ? .green : .red)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Battle (\(report.targetX),\(report.targetY))")
                                    .font(.system(size: 8)).foregroundStyle(.white.opacity(0.72)).lineLimit(1)
                                Text(relativeTime(report.occurredAt))
                                    .font(.gameCaption(6)).foregroundStyle(.white.opacity(0.3))
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        gameState.selectedTab = .army
                    } label: {
                        Text("View all →")
                            .font(.gameLabel(7)).foregroundStyle(.orange.opacity(0.5))
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    // MARK: Shared helpers

    var panelSpinner: some View {
        HStack(spacing: 6) {
            ProgressView().scaleEffect(0.5)
            Text("Loading…").font(.gameCaption(8)).foregroundStyle(.white.opacity(0.3))
        }
    }

    func relativeTime(_ date: Date) -> String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Shared Colour Helpers

private extension EmpireOverviewView {
    func ringAccentColor(_ ring: Ring) -> Color {
        switch ring {
        case .fringe: .cyan
        case .grid:   Color(red: 1.0, green: 0.82, blue: 0.20)
        case .core:   .red
        case .nexus:  Color(red: 0.95, green: 0.10, blue: 0.95)
        }
    }

    func ringBaseColor(_ ring: Ring) -> Color { ringAccentColor(ring) }

    var sideMenuActions: [SideMenuAction] {
        [
            SideMenuAction(id: "settings", assetName: "ui_settings_v1",
                           accentColor: Color(red: 0.0, green: 0.9, blue: 1.0), badgeCount: nil) {
                gameState.selectedTab = .settings
            },
            SideMenuAction(id: "email", assetName: "ui_email_v1",
                           accentColor: Color(red: 0.0, green: 0.9, blue: 1.0),
                           badgeCount: gameState.unreadEmailCount) {
                gameState.lastCompletionNotice = .comingSoon("Mailbox")
            },
            SideMenuAction(id: "notifications", assetName: "ui_notifications_v1",
                           accentColor: Color(red: 1.0, green: 0.3, blue: 0.3),
                           badgeCount: gameState.unreadNotificationCount) {
                gameState.lastCompletionNotice = .comingSoon("Notifications")
            },
            SideMenuAction(id: "shop", assetName: "ui_shop_v1",
                           accentColor: Color(red: 1.0, green: 0.3, blue: 0.9), badgeCount: nil) {
                gameState.lastCompletionNotice = .comingSoon("Shop")
            },
        ]
    }
}
