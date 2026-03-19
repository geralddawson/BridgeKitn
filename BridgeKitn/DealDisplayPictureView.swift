//
//
//  DealDisplayPictureView.swift
//  BridgeTeacherHandCompose
//
//  Created by Gerald Dawson on 13/1/2026.
//
import SwiftUI
import AppKit

public enum DisplaySeat: String, CaseIterable { case N, E, S, W }

public enum DisplaySuit: String, CaseIterable {
    case spades = "S", hearts = "H", diamonds = "D", clubs = "C"

    var symbol: String { switch self { case .spades: return "♠︎"; case .hearts: return "♥︎"; case .diamonds: return "♦︎"; case .clubs: return "♣︎" } }
    var isRed: Bool { switch self { case .hearts, .diamonds: return true; default: return false } }
}

public struct DealDisplayData {
    public var board: Int
    public var dealer: DisplaySeat
    public var vulnerability: String
    // ranks are expected in descending order: A,K,Q,J,T,9,...,2
    public var hands: [DisplaySeat: [DisplaySuit: [String]]]

    public init(board: Int, dealer: DisplaySeat, vulnerability: String, hands: [DisplaySeat: [DisplaySuit: [String]]]) {
        self.board = board
        self.dealer = dealer
        self.vulnerability = vulnerability
        self.hands = hands
    }
}

public struct DealDisplayPictureView: View {
    public var sessionFolderURL: URL?
    public var sessionName: String?
    public var deal: DealDisplayData?
    @Environment(\.dismiss) private var dismiss
    @State private var notes: String = ""
    @State private var saveNotesTask: Task<Void, Never>? = nil
    @State private var contentWidth: CGFloat? = nil

    public init(sessionFolderURL: URL? = nil, sessionName: String? = nil, deal: DealDisplayData? = nil) {
        self.sessionFolderURL = sessionFolderURL
        self.sessionName = sessionName
        self.deal = deal
    }
    
    private let cardWidth: CGFloat = 122 // Increase/decrease card size
    private let visibleFraction: CGFloat = 0.35 // show 35% of each preceding card
    private let middleGap: CGFloat = 70 // minimum gap between West and East hands
    private let infoFontSize: CGFloat = 18 // ~50% larger than caption
    private let groupSpacing: CGFloat = 6
    private let interSuitTightening: CGFloat = 58 // pulls suit groups closer
    private let notesWidthScale: CGFloat = 0.73

    // Solid base green for sheet background (tweak)
    private let baseGreen = Color(red: 46.0/255.0, green: 123.0/255.0, blue: 96.0/255.0)

    private struct RecordButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.red)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.red.opacity(configuration.isPressed ? 0.35 : 0.0), lineWidth: 2)
                )
                .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
                .shadow(color: Color.red.opacity(configuration.isPressed ? 0.25 : 0.0), radius: configuration.isPressed ? 8 : 0, x: 0, y: 0)
                .animation(.spring(response: 0.25, dampingFraction: 0.9), value: configuration.isPressed)
        }
    }

    private func aggregateSessionIfPossible() {
        guard let folderURL = sessionFolderURL, let name = sessionName else { return }
        Task {
            do {
                let fm = FileManager.default
                // Small delay to avoid reading files mid-write
                try await Task.sleep(nanoseconds: 200_000_000)

                let contents = try fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                let pbnFiles = contents.filter { $0.pathExtension.lowercased() == "pbn" }

                func boardNumber(from url: URL) -> Int? {
                    let base = url.deletingPathExtension().lastPathComponent
                    if let r = base.range(of: "\\d+", options: .regularExpression) { return Int(base[r]) }
                    return nil
                }

                let sorted = pbnFiles.sorted { a, b in
                    switch (boardNumber(from: a), boardNumber(from: b)) {
                    case let (x?, y?): return x < y
                    case (_?, nil): return true
                    case (nil, _?): return false
                    default: return a.lastPathComponent < b.lastPathComponent
                    }
                }

                #if DEBUG
                print("Aggregator found PBNs: \(sorted.map { $0.lastPathComponent })")
                #endif

                var parts: [String] = []
                for file in sorted {
                    do {
                        let data = try Data(contentsOf: file)
                        if var s = String(data: data, encoding: .utf8) {
                            // Normalize to end with a single newline
                            while s.hasSuffix("\n") { s.removeLast() }
                            s.append("\n")
                            parts.append(s)
                            #if DEBUG
                            print("Included: \(file.lastPathComponent)")
                            #endif
                        } else {
                            #if DEBUG
                            print("Skipped (encoding): \(file.lastPathComponent)")
                            #endif
                        }
                    } catch {
                        #if DEBUG
                        print("Skipped (read error): \(file.lastPathComponent) — \(error)")
                        #endif
                    }
                }

                guard !parts.isEmpty else {
                    #if DEBUG
                    print("No PBN fragments to aggregate")
                    #endif
                    return
                }
                // Separate deals with a blank line
                let aggregate = parts.joined(separator: "\n") + "\n"

                let destURL = folderURL.deletingLastPathComponent().appendingPathComponent("\(name).pbn")
                if fm.fileExists(atPath: destURL.path) {
                    try fm.removeItem(at: destURL)
                }
                try aggregate.write(to: destURL, atomically: true, encoding: .utf8)
                #if DEBUG
                print("Aggregated session to: \(destURL.path)")
                #endif
            } catch {
                #if DEBUG
                print("Aggregation failed: \(error)")
                #endif
            }
        }
    }

    private func notesURL(for board: Int) -> URL? {
        guard let folder = sessionFolderURL, board > 0 else { return nil }
        return folder.appendingPathComponent("Board \(board).notes.txt")
    }

    private func loadNotesIfAvailable() {
        guard let b = deal?.board, b > 0, let url = notesURL(for: b) else { return }
        if let data = try? Data(contentsOf: url), let s = String(data: data, encoding: .utf8) {
            notes = s
        } else {
            notes = ""
        }
    }

    private func saveNotes() {
        guard let b = deal?.board, b > 0, let url = notesURL(for: b) else { return }
        do {
            try notes.write(to: url, atomically: true, encoding: .utf8)
            #if DEBUG
            print("Saved notes to: \(url.lastPathComponent)")
            #endif
        } catch {
            #if DEBUG
            print("Failed to save notes: \(error)")
            #endif
        }
    }

    private func saveSnapshot() {
        guard let b = deal?.board, b > 0 else {
            #if DEBUG
            print("Snapshot skipped: invalid board number.")
            #endif
            return
        }
        guard let folder = sessionFolderURL else {
            #if DEBUG
            print("Snapshot skipped: no session folder available.")
            #endif
            return
        }
        let fileURL = folder.appendingPathComponent("Board \(b).jpg")

        // Build a snapshot-optimized view: no controls, constrained width, simplified background
        let targetWidth = contentWidth ?? 1600
        let snapshotView = content(notesView: notesSnapshotView(), showControls: false, snapshotMode: true)
            .frame(width: targetWidth)

        let renderer = ImageRenderer(content: snapshotView)
        // Let the view size itself to its ideal size
        renderer.proposedSize = .unspecified

        // Render at ~1.3x to balance detail and file size (about 15% smaller than before)
        renderer.scale = 1.00
        // Hint that the snapshot is opaque for better encoding
        renderer.isOpaque = true
        if let image = renderer.nsImage,
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.96]) {
            do {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                }
                try jpegData.write(to: fileURL, options: .atomic)
                #if DEBUG
                print("Saved snapshot to: \(fileURL.lastPathComponent) (\(jpegData.count) bytes)")
                #endif
            } catch {
                #if DEBUG
                print("Failed to save snapshot: \(error)")
                #endif
            }
        } else {
            #if DEBUG
            print("Failed to render snapshot image.")
            #endif
        }
    }

    // MARK: - Snapshot-aware content builders

    private func notesEditorView() -> some View {
        HStack {
            TextEditor(text: $notes)
                .font(.title3)
                .frame(width: widthForSeat(.S) * notesWidthScale, height: 200)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func notesSnapshotView() -> some View {
        HStack {
            Text(notes)
                .font(.title3)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .frame(width: widthForSeat(.S) * notesWidthScale, height: 200, alignment: .topLeading)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func content<NV: View>(notesView: NV, showControls: Bool = true, snapshotMode: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header + disclaimer
            HStack(alignment: .top, spacing: 12) {
                // Board info panel (top-left)
                boardInfoPanel
                if showControls {
                    Spacer()
                    Button(action: {
                        saveNotes()
                        saveSnapshot()
                    }) {
                        Text("Record")
                    }
                    .buttonStyle(RecordButtonStyle())
                    
                    Button(action: { dismiss() }) {
                        Text("Next Hand")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white)
                            )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                }
            }

            // North at top center
            VStack(spacing: 1) {
                seatHeader(.N)
                cardsRow(for: .N)
            }
            .frame(maxWidth: .infinity)

            // Middle row: West (left) and East (right)
            HStack(alignment: .top) {
                VStack(spacing: 1) {
                    seatHeader(.W)
                    cardsRow(for: .W)
                }
                Spacer(minLength: middleGap)
                VStack(spacing: 1) {
                    seatHeader(.E)
                    cardsRow(for: .E)
                }
            }

            // South at bottom center
            VStack(spacing: 1) {
                seatHeader(.S)
                cardsRow(for: .S)
            }
            .frame(maxWidth: .infinity)

            // Notes area
            notesView
                .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .padding()
        .background(
            ZStack {
                // Solid base to control the overall green tone
                Rectangle().fill(baseGreen)

                if !snapshotMode {
                    Rectangle().fill(.ultraThinMaterial).opacity(0.12)
                }

                // Radial gradient for heavy green depth
                RadialGradient(
                    gradient: Gradient(stops: [
                        // lighter center glow (~ #2e7b60)
                        .init(color: Color(red: 46.0/255.0, green: 123.0/255.0, blue: 96.0/255.0), location: 0.0),
                        // base heavy green (#0b3d2e)
                        .init(color: Color(red: 11.0/255.0, green: 61.0/255.0,  blue: 46.0/255.0), location: 0.55),
                        // darker edge (~ #062820)
                        .init(color: Color(red: 6.0/255.0,  green: 40.0/255.0,  blue: 32.0/255.0), location: 1.0)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 900
                )
                .opacity(0.55)
            }
            .ignoresSafeArea()
        )
    }

    public var body: some View {
        content(notesView: notesEditorView())
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { contentWidth = proxy.size.width }
                        .onChange(of: proxy.size) { _, newSize in
                            contentWidth = newSize.width
                        }
                }
            )
            .onAppear {
                aggregateSessionIfPossible()
                loadNotesIfAvailable()
            }
            .onChange(of: deal?.board ?? 0) { _, _ in
                loadNotesIfAvailable()
            }
            .onChange(of: notes) { _, _ in
                saveNotesTask?.cancel()
                saveNotesTask = Task {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    await MainActor.run { saveNotes() }
                }
            }
            .onDisappear {
                saveNotesTask?.cancel()
                saveNotes()
            }
    }

    private var boardInfoPanel: some View {
        let b = deal?.board ?? 0
        let d = b > 0 ? standardDealer(forBoard: b).rawValue : (deal?.dealer.rawValue ?? "N")
        let v = b > 0 ? standardVulnerability(forBoard: b) : (deal?.vulnerability ?? "None")
        return VStack(alignment: .leading, spacing: 9) {
            infoRow(label: "Board:", value: b == 0 ? "—" : String(b))
            infoRow(label: "Dealer:", value: d)
            infoRow(label: "Vul:", value: v)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.quaternary, lineWidth: 1.5)
        )
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.system(size: infoFontSize, weight: .bold))
            Text(value).font(.system(size: infoFontSize))
        }
    }
    
    // Standard duplicate bridge rotation
    private func standardDealer(forBoard board: Int) -> DisplaySeat {
        guard board > 0 else { return .N }
        let index = (board - 1) % 4
        switch index {
        case 0: return .N
        case 1: return .E
        case 2: return .S
        default: return .W
        }
    }

    // Standard duplicate bridge vulnerability cycle across 16 boards
    private func standardVulnerability(forBoard board: Int) -> String {
        guard board > 0 else { return "None" }
        let idx = ((board - 1) % 16) + 1
        switch idx {
        case 1, 8, 11, 14:
            return "None"
        case 2, 5, 12, 15:
            return "N/S"
        case 3, 6, 9, 16:
            return "E/W"
        case 4, 7, 10, 13:
            return "Both"
        default:
            return "None"
        }
    }

    private func hcp(for seat: DisplaySeat) -> Int {
        guard let seatHands = deal?.hands[seat] else { return 0 }
        let points: [String: Int] = ["A": 4, "K": 3, "Q": 2, "J": 1]
        var total = 0
        for (_, ranks) in seatHands {
            for r in ranks { total += points[r] ?? 0 }
        }
        return total
    }

    private func hcpBadge(for seat: DisplaySeat) -> some View {
        let value = hcp(for: seat)
        return Text("HCP: \(value)")
            .font(.callout)
            .foregroundStyle(Color.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.yellow)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.red.opacity(0.35), lineWidth: 1)
            )
    }

    private func seatDisplayName(_ seat: DisplaySeat) -> String {
        switch seat {
        case .N: return "NORTH"
        case .E: return "EAST"
        case .S: return "SOUTH"
        case .W: return "WEST"
        }
    }

    private func seatHeader(_ seat: DisplaySeat) -> some View {
        HStack(spacing: 10) {
            Text(seatDisplayName(seat))
                .font(.headline)
                .foregroundStyle(Color.yellow)
            hcpBadge(for: seat)
        }
    }

    private func cardsRow(for seat: DisplaySeat) -> some View {
        let groups = cardGroups(for: seat)
        return HStack(alignment: .bottom, spacing: groupSpacing) {
            ForEach(groups.indices, id: \.self) { idx in
                overlappedGroup(for: groups[idx])
                    .padding(.trailing, idx < groups.count - 1 ? -interSuitTightening : 0)
            }
        }
    }
    
    private func widthForSeat(_ seat: DisplaySeat) -> CGFloat {
        let groups = cardGroups(for: seat)
        let step = cardWidth * visibleFraction
        let effectiveSpacing = max(groupSpacing - interSuitTightening, 0)
        let spacings = effectiveSpacing * CGFloat(max(groups.count - 1, 0))
        let totalGroupsWidth = groups.reduce(CGFloat(0)) { partial, codes in
            let count = codes.count
            let groupWidth = cardWidth + step * CGFloat(max(count - 1, 0))
            return partial + groupWidth
        }
        return totalGroupsWidth + spacings
    }

    private func overlappedGroup(for codes: [String]) -> some View {
        let step = cardWidth * visibleFraction
        let totalWidth = cardWidth + step * CGFloat(max(codes.count - 1, 0))
        return ZStack(alignment: .leading) {
            ForEach(Array(codes.enumerated()), id: \.offset) { index, code in
                cardImage(code: code)
                    .frame(width: cardWidth, height: cardWidth * 3.5 / 2.5)
                    .offset(x: CGFloat(index) * step)
                    .zIndex(Double(index)) // later cards (lower ranks) appear on top
            }
        }
        .frame(width: totalWidth, alignment: .leading)
    }

    // Build card groups by suit in order: spades, hearts, diamonds, clubs
    private func cardGroups(for seat: DisplaySeat) -> [[String]] {
        guard let seatHands = deal?.hands[seat] else { return [] }
        let order: [DisplaySuit] = [.spades, .hearts, .diamonds, .clubs]
        let rankOrder = ["A","K","Q","J","T","9","8","7","6","5","4","3","2"]
        return order.map { suit in
            let ranks = seatHands[suit] ?? []
            let sorted = rankOrder.filter { ranks.contains($0) }
            // Map to asset code e.g., "AS", "TD"
            return sorted.map { assetCode(for: suit, rank: $0) }
        }.filter { !$0.isEmpty }
    }

    private func assetCode(for suit: DisplaySuit, rank: String) -> String {
        // Adjust this if your asset naming differs. Current convention: "AS" for Ace of Spades, "TD" for Ten of Diamonds, etc.
        return rank + suit.rawValue
    }

    @ViewBuilder
    private func cardImage(code: String) -> some View {
        PlayingCardView(code: code)
    }
}

#Preview {
    let sampleHands: [DisplaySeat: [DisplaySuit: [String]]] = [
        .N: [.spades: ["A","K","9"], .hearts: ["Q","J"], .diamonds: ["A","K","Q","J","T","9"], .clubs: ["3","2"]],
        .E: [.spades: ["J","8"], .hearts: ["8","6"], .diamonds: ["K","3"], .clubs: ["K","Q","J"]],
        .S: [.spades: ["A","5"], .hearts: ["A","K","Q"], .diamonds: ["5","4","3"], .clubs: ["A","9","8","7"]],
        .W: [.spades: ["Q","T"], .hearts: ["A","7","4"], .diamonds: ["A","7","2"], .clubs: ["T","9","6"]]
    ]
    let sample = DealDisplayData(board: 1, dealer: .N, vulnerability: "None", hands: sampleHands)
    return DealDisplayPictureView(sessionFolderURL: nil, sessionName: "My Session", deal: sample)
        .padding()
}


