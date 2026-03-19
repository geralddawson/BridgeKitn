//
//  HandComposeView.swift
//  BridgeTeacherHandCompose
//
//  Created by Gerald Dawson on 13/1/2026.
//
//

import SwiftUI
import Foundation

struct HandComposeView: View {
    private enum Suit: CaseIterable {
        case spades, hearts, diamonds, clubs
        
        var symbol: String {
            switch self {
            case .spades: return "♠︎"
            case .hearts: return "♥︎"
            case .diamonds: return "♦︎"
            case .clubs: return "♣︎"
            }
        }
        
        var isRed: Bool {
            switch self {
            case .hearts, .diamonds: return true
            case .spades, .clubs: return false
            }
        }
        
        var name: String {
            switch self {
            case .spades: return "Spades"
            case .hearts: return "Hearts"
            case .diamonds: return "Diamonds"
            case .clubs: return "Clubs"
            }
        }
    }
    
    private enum Hand: String, CaseIterable, Identifiable {
        case north = "N", south = "S", east = "E", west = "W"
        var id: String { rawValue }
    }
    
    @State private var handCards: [Hand: [Suit: [String]]] = [
        .north: [.spades: [], .hearts: [], .diamonds: [], .clubs: []],
        .east:  [.spades: [], .hearts: [], .diamonds: [], .clubs: []],
        .south: [.spades: [], .hearts: [], .diamonds: [], .clubs: []],
        .west:  [.spades: [], .hearts: [], .diamonds: [], .clubs: []]
    ]
    @State private var selectedHand: Hand = .south
    
    @State private var handName: String = ""
    @State private var showSaveError: Bool = false
    @State private var boardNumber: Int = 0
    
    @State private var sessionFolderURL: URL? = nil
    @State private var showDealPreview: Bool = false
    @State private var showSavingBanner: Bool = false
    @State private var lastComposedHands: [Hand: [Suit: [String]]]? = nil
    @State private var lastComposedBoard: Int? = nil
    @State private var composedDealsByBoard: [Int: DealDisplayData] = [:]
    @State private var selectedPreviewBoard: Int? = nil
    
    @FocusState private var isNameFieldFocused: Bool
    @State private var canEditHandName: Bool = false
    private let headerHeight: CGFloat = 90

    // Auto-fill the remaining hand with the last 13 cards when three hands are complete
    private func autofillIfEligible() {
        // Count total selected cards across all hands
        let totalSelected = Hand.allCases.reduce(0) { partial, hand in
            partial + (handCards[hand]?.values.reduce(0) { $0 + $1.count } ?? 0)
        }
        // Only proceed when exactly 39 cards have been selected
        guard totalSelected == 39 else { return }

        // Find the single incomplete hand
        let incompleteHands = Hand.allCases.filter { hand in
            let count = handCards[hand]?.values.reduce(0) { $0 + $1.count } ?? 0
            return count < 13
        }
        guard incompleteHands.count == 1, let targetHand = incompleteHands.first else { return }

        // Build a set of remaining cards by suit and rank
        var remaining: [Suit: Set<String>] = [.spades: [], .hearts: [], .diamonds: [], .clubs: []]
        let allRanks: [String] = ["A","K","Q","J","T","9","8","7","6","5","4","3","2"]

        // Start with full deck
        for suit in Suit.allCases {
            remaining[suit] = Set(allRanks)
        }
        // Remove already assigned cards
        for hand in Hand.allCases {
            if let suits = handCards[hand] {
                for (suit, ranks) in suits {
                    remaining[suit]?.subtract(ranks)
                }
            }
        }

        // Assign remaining cards to the target hand preserving rank display order
        for suit in Suit.allCases {
            let ranksLeft = remaining[suit] ?? []
            let ordered = allRanks.filter { ranksLeft.contains($0) }
            if !ordered.isEmpty {
                handCards[targetHand]?[suit, default: []].append(contentsOf: ordered)
            }
        }
        
        // After autofill, if we now have a full deal (52 cards), export to PBN, bump board number, and reset for next board.
        let finalTotal = Hand.allCases.reduce(0) { partial, hand in
            partial + (handCards[hand]?.values.reduce(0) { $0 + $1.count } ?? 0)
        }
        if finalTotal == 52, let folder = sessionFolderURL {
            do {
                // Snapshot the just-composed deal before increment/reset
                lastComposedHands = handCards
                let savedBoard = max(boardNumber, 1)
                lastComposedBoard = savedBoard

                // Store display deal for dropdown previews
                let display = mapToDisplayData(hands: handCards, board: savedBoard)
                composedDealsByBoard[savedBoard] = display
                selectedPreviewBoard = savedBoard

                _ = try writeCurrentBoardPBN(to: folder, boardNumber: savedBoard)
                // Increment board number
                boardNumber = savedBoard + 1
                // Reset hands for next composition
                handCards = [
                    .north: [.spades: [], .hearts: [], .diamonds: [], .clubs: []],
                    .east:  [.spades: [], .hearts: [], .diamonds: [], .clubs: []],
                    .south: [.spades: [], .hearts: [], .diamonds: [], .clubs: []],
                    .west:  [.spades: [], .hearts: [], .diamonds: [], .clubs: []]
                ]
                selectedHand = .south

                // Show 'Saving…' banner, then present preview after ~3 seconds
                showSavingBanner = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    showSavingBanner = false
                    showDealPreview = true
                }
            } catch {
                print("Failed to write PBN: \(error)")
            }
        }
    }
    
    private func saveApprovedHand() -> URL? {
        // Fix the session name for filesystem safety
        let trimmed = handName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Replace illegal path characters with hyphens
        let illegal = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let safeName = trimmed.components(separatedBy: illegal).joined(separator: "-")

        do {
            // Base directory: Documents/BridgeSessions
            let docs = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let base = docs.appendingPathComponent("BridgeSessions", isDirectory: true)
            // Ensure base exists
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            // Session directory
            let sessionDir = base.appendingPathComponent(safeName, isDirectory: true)
            // Create if missing (idempotent)
            try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
            return sessionDir
        } catch {
#if DEBUG
            print("Failed to create session directory: \(error)")
#endif
            return nil
        }
    }
    
    // Standard duplicate bridge rotation (matching DealDisplayPictureView)
    private func standardDealer(forBoard board: Int) -> Hand {
        guard board > 0 else { return .north }
        let index = (board - 1) % 4
        switch index {
        case 0: return .north
        case 1: return .east
        case 2: return .south
        default: return .west
        }
    }

    // Standard duplicate bridge vulnerability cycle across 16 boards (matching DealDisplayPictureView)
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

    // Convert our internal cards mapping to a PBN hand string like: "N:AKQ.JT9.8.AKQ ..."
    private func pbnStringForCurrentHands(dealer: Hand = .north) -> String {
        // PBN seat order starting from dealer: N E S W rotating
        let baseOrder: [Hand] = [.north, .east, .south, .west]
        guard let startIndex = baseOrder.firstIndex(of: dealer) else { return "N:" }
        let order = Array(baseOrder[startIndex...] + baseOrder[..<startIndex])
        func suitString(_ ranks: [String]) -> String {
            // Ensure PBN order AKQJT98765432
            let pbnOrder = ["A","K","Q","J","T","9","8","7","6","5","4","3","2"]
            let set = Set(ranks)
            return pbnOrder.filter { set.contains($0) }.joined()
        }
        func handString(for hand: Hand) -> String {
            let suits = handCards[hand] ?? [:]
            let sp = suitString(suits[.spades] ?? [])
            let he = suitString(suits[.hearts] ?? [])
            let di = suitString(suits[.diamonds] ?? [])
            let cl = suitString(suits[.clubs] ?? [])
            return "\(sp).\(he).\(di).\(cl)"
        }
        let handsJoined = order.map { handString(for: $0) }.joined(separator: " ")
        return "\(dealer.rawValue):\(handsJoined)"
    }

    private func writeCurrentBoardPBN(to folder: URL, boardNumber: Int) throws -> URL {
        let dealerHand = standardDealer(forBoard: boardNumber)
        let vul = standardVulnerability(forBoard: boardNumber)
        let dealString = pbnStringForCurrentHands(dealer: dealerHand)
        let pbnHeader = "[Event \"\(handName)\"]\n[Board \"\(boardNumber)\"]\n[Dealer \"\(dealerHand.rawValue)\"]\n[Vulnerable \"\(vul)\"]\n[Deal \"\(dealString)\"]\n\n"
        let fileName = String(format: "Board %d.pbn", boardNumber)
        let fileURL = folder.appendingPathComponent(fileName)
        try pbnHeader.write(to: fileURL, atomically: true, encoding: .utf8)
#if DEBUG
        print("Saved Board #\(boardNumber) for session '\(handName)' to: \(fileURL.path)")
#endif
        return fileURL
    }
    
    private func makeDisplayDeal() -> DealDisplayData {
        // Map local enums to display enums used by DealDisplayPictureView
        let seatMap: [Hand: DisplaySeat] = [.north: .N, .east: .E, .south: .S, .west: .W]
        let suitMap: [Suit: DisplaySuit] = [.spades: .spades, .hearts: .hearts, .diamonds: .diamonds, .clubs: .clubs]

        // Ensure descending rank order as required by DealDisplayPictureView
        let rankOrder = ["A","K","Q","J","T","9","8","7","6","5","4","3","2"]

        // Decide whether to show the current in-progress hands or the last composed snapshot
        let currentTotal = Hand.allCases.reduce(0) { partial, hand in
            partial + (handCards[hand]?.values.reduce(0) { $0 + $1.count } ?? 0)
        }

        let sourceHands: [Hand: [Suit: [String]]]
        let board: Int
        if currentTotal == 0, let last = lastComposedHands {
            // After auto-reset, show the just-composed deal
            sourceHands = last
            board = lastComposedBoard ?? max(boardNumber - 1, 1)
        } else {
            // Otherwise, show what is currently composed (partial or full)
            sourceHands = handCards
            board = boardNumber
        }

        var hands: [DisplaySeat: [DisplaySuit: [String]]] = [:]
        for (hand, suits) in sourceHands {
            var suitDict: [DisplaySuit: [String]] = [:]
            for (suit, ranks) in suits {
                let sorted = rankOrder.filter { ranks.contains($0) }
                if let mappedSuit = suitMap[suit] {
                    suitDict[mappedSuit] = sorted
                }
            }
            if let mappedSeat = seatMap[hand] {
                hands[mappedSeat] = suitDict
            }
        }

        return DealDisplayData(
            board: board,
            dealer: .N,              // If board > 0, DealDisplayPictureView computes standard dealer
            vulnerability: standardVulnerability(forBoard: board),   // Use corrected vulnerability cycle
            hands: hands
        )
    }
    
    private func mapToDisplayData(hands: [Hand: [Suit: [String]]], board: Int) -> DealDisplayData {
        let seatMap: [Hand: DisplaySeat] = [.north: .N, .east: .E, .south: .S, .west: .W]
        let suitMap: [Suit: DisplaySuit] = [.spades: .spades, .hearts: .hearts, .diamonds: .diamonds, .clubs: .clubs]
        let rankOrder = ["A","K","Q","J","T","9","8","7","6","5","4","3","2"]
        var displayHands: [DisplaySeat: [DisplaySuit: [String]]] = [:]
        for (hand, suits) in hands {
            var suitDict: [DisplaySuit: [String]] = [:]
            for (suit, ranks) in suits {
                let sorted = rankOrder.filter { ranks.contains($0) }
                if let mappedSuit = suitMap[suit] {
                    suitDict[mappedSuit] = sorted
                }
            }
            if let mappedSeat = seatMap[hand] {
                displayHands[mappedSeat] = suitDict
            }
        }
        return DealDisplayData(
            board: board,
            dealer: .N,
            vulnerability: standardVulnerability(forBoard: board),
            hands: displayHands
        )
    }
    
    private struct LiquidGlassButtonStyle: ButtonStyle {
        var labelColor: Color = .primary
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(labelColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(0)
                .background(
                    ZStack {
                        // Base liquid glass material
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial)

                        // Blue-tinted highlight
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(configuration.isPressed ? 0.16 : 0.08),
                                        Color.blue.opacity(configuration.isPressed ? 0.08 : 0.03)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        // Inner glow for depth
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(configuration.isPressed ? 0.5 : 0.35), lineWidth: 1.0)
                            .blendMode(.overlay)
                    }
                )
                .overlay(
                    // Outer stroke to define edges against the background
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.blue.opacity(configuration.isPressed ? 0.26 : 0.18), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(configuration.isPressed ? 0.08 : 0.14), radius: configuration.isPressed ? 5 : 8, x: 0, y: 3)
                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.9), value: configuration.isPressed)
        }
    }
    
    private struct HandGrid: View {
        let onAdd: (Suit, String) -> Void
        let selectedCards: [Suit: Set<String>]
        let isCurrentHandFull: Bool
        private let suits = Suit.allCases
        private let ranks = ["A","K","Q","J","T","9","8","7","6","5","4","3","2"]
        
        var body: some View {
            VStack(spacing: 4) {
                ForEach(suits, id: \.self) { suit in
                    HStack(spacing: 4) {
                        Text(suit.symbol)
                            .foregroundColor(suit.isRed ? .red : .primary)
                            .font(.system(size: 26, weight: .regular, design: .monospaced))
                            .frame(minWidth: 20, alignment: .leading)
                        
                        ForEach(ranks, id: \.self) { rank in
                            let isDisabled = isCurrentHandFull || (selectedCards[suit]?.contains(rank) == true)
                            Button {
                                onAdd(suit, rank)
                            } label: {
                                Text(rank)
                                    .font(.system(size: 18, weight: .regular, design: .monospaced))
                                    .frame(minWidth: 18)
                                    .padding(.vertical, 1)
                                    .padding(.horizontal, 3)
                                    .frame(minWidth: 28, minHeight: 24)
                                    .overlay(
                                        Rectangle()
                                            .stroke(.quaternary.opacity(0.6), lineWidth: 0.5)
                                    )
                                    .opacity(isDisabled ? 0.25 : 1.0)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isDisabled)
                            .clipShape(Rectangle())
                            .accessibilityLabel("Add \(rank) of \(suit.name)")
                        }
                    }
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private struct PlayerHandGrid: View {
        let title: String
        let cardsBySuit: [Suit: [String]]
        let onRemove: ((Suit, String) -> Void)?
        private let suits = Suit.allCases
        private let displayOrder: [String] = ["A","K","Q","J","T","9","8","7","6","5","4","3","2"]
        private let gridColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 6), count: 14)

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                header
                ForEach(suits, id: \.self) { suit in
                    suitRow(for: suit)
                }
            }
            .padding(8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }

        private var header: some View {
            HStack {
                Text(title)
                    .font(.callout)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.thinMaterial)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(.quaternary, lineWidth: 1)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(.tint.opacity(0.25), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Total: \(cardsBySuit.values.reduce(0) { $0 + $1.count })")
                    .frame(alignment: .trailing)
                    .font(.title3)
                
            }
        }

        private func suitRow(for suit: Suit) -> some View {
            let cards: [String] = cardsBySuit[suit] ?? []
            return HStack(alignment: .center, spacing: 8) {
                Text(suit.symbol)
                    .foregroundColor(suit.isRed ? .red : .primary)
                    .font(.system(size: 30, weight: .regular, design: .monospaced))
                    .frame(minWidth: 24, alignment: .leading)

                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 6) {
                    ForEach(displayOrder, id: \.self) { rank in
                        cardCell(for: rank, suit: suit, hasCard: cards.contains(rank))
                    }
                    countCell(count: cards.count)
                }
                .frame(maxWidth: .infinity)
            }
        }

        private func cardCell(for rank: String, suit: Suit, hasCard: Bool) -> some View {
            Group {
                if hasCard, let onRemove = onRemove {
                    Button {
                        onRemove(suit, rank)
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.clear)
                                .background(Color.accentColor.opacity(0.22))
                            Text(rank)
                                .font(.title2)
                                .foregroundStyle(.primary)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(.quaternary, lineWidth: 1)
                        )
                        .aspectRatio(1, contentMode: .fit)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(rank) of \(suit.name)")
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.clear)
                            .background(
                                Group {
                                    if hasCard {
                                        Color.accentColor.opacity(0.22)
                                    } else {
                                        Color.clear.background(.ultraThinMaterial)
                                    }
                                }
                            )
                        if hasCard {
                            Text(rank)
                                .font(.title2)
                                .foregroundStyle(.primary)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(.quaternary, lineWidth: 1)
                    )
                    .aspectRatio(1, contentMode: .fit)
                }
            }
        }

        private func countCell(count: Int) -> some View {
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(.systemYellow).opacity(0.2))
                Text(String(count))
                    .font(.title2)
                    .monospacedDigit()
                    .foregroundColor(.primary)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(.quaternary, lineWidth: 1)
            )
            .aspectRatio(1, contentMode: .fit)
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            
            HStack(spacing: 12) {
                Button("New Session") {
                    handCards = [
                        .north: [.spades: [], .hearts: [], .diamonds: [], .clubs: []],
                        .east:  [.spades: [], .hearts: [], .diamonds: [], .clubs: []],
                        .south: [.spades: [], .hearts: [], .diamonds: [], .clubs: []],
                        .west:  [.spades: [], .hearts: [], .diamonds: [], .clubs: []]
                    ]
                    handName = ""
                    boardNumber = 0
                    sessionFolderURL = nil
                    canEditHandName = true
                    isNameFieldFocused = true
                    composedDealsByBoard = [:]
                    selectedPreviewBoard = nil
                }
                .buttonStyle(LiquidGlassButtonStyle(labelColor: .secondary))
                .frame(height: 40)
                .frame(minWidth: 72, maxWidth: 150)
                .padding(.horizontal, 8)
                .accessibilityLabel("New")
                
                TextField("🖊️ session name", text: Binding(
                    get: { String(handName.prefix(20)) },
                    set: { newValue in
                        handName = String(newValue.prefix(20))
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .focused($isNameFieldFocused)
                .disabled(!canEditHandName)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .frame(height: 48)
                .frame(minWidth: 160, maxWidth: 220)
                .padding(.horizontal, 8)
                .accessibilityLabel("Hand name")

                Button("Save") {
                    let name = handName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if name.isEmpty {
                        showSaveError = true
                    } else if let sessionURL = saveApprovedHand() {
#if DEBUG
                        print("Session folder created at: \(sessionURL.path)")
#endif
                        sessionFolderURL = sessionURL
                        canEditHandName = false
                        if boardNumber == 0 { boardNumber = 1 }
                    } else {
                        showSaveError = true
                    }
                }
                .buttonStyle(LiquidGlassButtonStyle(labelColor: .secondary))
                .frame(height: 40)
                .frame(minWidth: 72, maxWidth: 80)
                .padding(.horizontal, 8)
                .accessibilityLabel("Save")

                Spacer()
                HStack(spacing: 8) {
                    Text("Board :")
                        .font(.headline)

                    Text("\(boardNumber)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(.thinMaterial)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.blue.opacity(0.22), lineWidth: 1)
                        )
                }
                .padding(.trailing, 24)
                
                Picker("Preview", selection: Binding<Int?>(
                    get: { selectedPreviewBoard },
                    set: { newValue in
                        selectedPreviewBoard = newValue
                        if newValue != nil {
                            showDealPreview = true
                        }
                    }
                )) {
                    ForEach(composedDealsByBoard.keys.sorted(), id: \.self) { b in
                        Text("Board \(b)").tag(Optional(b))
                    }
                }
                .pickerStyle(.menu)
                .disabled(composedDealsByBoard.isEmpty)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 66)
            .padding(.trailing, 200)
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    PlayerHandGrid(
                        title: "North",
                        cardsBySuit: handCards[.north] ?? [:],
                        onRemove: { suit, rank in
                            if let idx = handCards[.north]?[suit]?.firstIndex(of: rank) {
                                handCards[.north]?[suit]?.remove(at: idx)
                            }
                        }
                    )
                    .frame(maxWidth: .infinity)
                    PlayerHandGrid(
                        title: "East",
                        cardsBySuit: handCards[.east] ?? [:],
                        onRemove: { suit, rank in
                            if let idx = handCards[.east]?[suit]?.firstIndex(of: rank) {
                                handCards[.east]?[suit]?.remove(at: idx)
                            }
                        }
                    )
                    .frame(maxWidth: .infinity)
                }
                HStack(spacing: 12) {
                    PlayerHandGrid(
                        title: "South",
                        cardsBySuit: handCards[.south] ?? [:],
                        onRemove: { suit, rank in
                            if let idx = handCards[.south]?[suit]?.firstIndex(of: rank) {
                                handCards[.south]?[suit]?.remove(at: idx)
                            }
                        }
                    )
                    .frame(maxWidth: .infinity)
                    PlayerHandGrid(
                        title: "West",
                        cardsBySuit: handCards[.west] ?? [:],
                        onRemove: { suit, rank in
                            if let idx = handCards[.west]?[suit]?.firstIndex(of: rank) {
                                handCards[.west]?[suit]?.remove(at: idx)
                            }
                        }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(0.9)
            .animation(nil, value: 0)
            .padding(.top, -14)
            
            ZStack {
                VStack(spacing: 2) {
                    HStack(alignment: .top, spacing: 8) {
                        // Left: Bottom grid (kept visually similar, but without layout hacks)
                        ZStack {
                            HandGrid(
                                onAdd: { suit, rank in
                                    guard sessionFolderURL != nil else { return }
                                    let totalInSelected = (handCards[selectedHand]?.values.reduce(0) { $0 + $1.count }) ?? 0
                                    guard totalInSelected < 13 else { return }
                                    if !(handCards[selectedHand]?[suit]?.contains(rank) ?? false) {
                                        handCards[selectedHand]?[suit, default: []].append(rank)
                                        autofillIfEligible()
                                    }
                                },
                                selectedCards: {
                                    var result: [Suit: Set<String>] = [.spades: [], .hearts: [], .diamonds: [], .clubs: []]
                                    for hand in Hand.allCases {
                                        if let suits = handCards[hand] {
                                            for (suit, ranks) in suits {
                                                result[suit, default: []].formUnion(ranks)
                                            }
                                        }
                                    }
                                    return result
                                }(),
                                isCurrentHandFull: ((handCards[selectedHand]?.values.reduce(0) { $0 + $1.count }) ?? 0) >= 13
                            )
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity((showSavingBanner || sessionFolderURL == nil) ? 0.35 : 1.0)
                            .disabled(showSavingBanner || sessionFolderURL == nil)

                            if showSavingBanner {
                                VStack(spacing: 10) {
                                    ProgressView()
                                        .controlSize(.regular)
                                    Text("Saving…")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
                                .transition(.scale.combined(with: .opacity))
                                .animation(.spring(response: 0.35, dampingFraction: 0.9), value: showSavingBanner)
                            }
                        }

                        // Right: Grouped buttons (2x2), fixed width and top-aligned
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Button("N") { selectedHand = .north }
                                    .buttonStyle(LiquidGlassButtonStyle(labelColor: .secondary))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(selectedHand == .north ? Color.blue.opacity(0.35) : .clear, lineWidth: 2)
                                    )
                                    .accessibilityLabel("North")
                                Button("E") { selectedHand = .east }
                                    .buttonStyle(LiquidGlassButtonStyle(labelColor: .secondary))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(selectedHand == .east ? Color.blue.opacity(0.35) : .clear, lineWidth: 2)
                                    )
                                    .accessibilityLabel("East")
                            }
                            HStack(spacing: 12) {
                                Button("S") { selectedHand = .south }
                                    .buttonStyle(LiquidGlassButtonStyle(labelColor: .secondary))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(selectedHand == .south ? Color.blue.opacity(0.35) : .clear, lineWidth: 2)
                                    )
                                    .accessibilityLabel("South")
                                Button("W") { selectedHand = .west }
                                    .buttonStyle(LiquidGlassButtonStyle(labelColor: .secondary))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(selectedHand == .west ? Color.blue.opacity(0.35) : .clear, lineWidth: 2)
                                    )
                                    .accessibilityLabel("West")
                            }
                        }
                        .frame(width: 140, alignment: .top)
                        .padding(0)
                    }
                }
                
            }
        }
        .padding()
        .padding(.top, headerHeight)
        .overlay(alignment: .topLeading) {
            
            VStack(alignment: .leading, spacing: 6) {
                
                Text("A Bridge hand composer for teachers by G Dawson")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 92)
                    .padding(.trailing, 200)
                    .padding(.bottom, 8)
                
                Text("Saved in .pbn format for use on dealing machines, RealBridge and others. Coded for MacOS")
                    .font(.title2).bold()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 92)
                    .padding(.trailing, 200)
                    .padding(.bottom, 6)

                Text("Guide : Start a [New Session] > Name the session > [Save] (a file is generated) > Select the [N] [S] [E] or [W] tabs in turn > Deal the cards [A...2] > Record > Next hand")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 92)
                    .padding(.trailing, 200)
                    .padding(.bottom, 10)
            }
            .frame(height: headerHeight, alignment: .topLeading)
            .allowsHitTesting(false)
        }
        .alert("Cannot Save", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(handName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                 "Please provide a name (tap New to name this session)." :
                 "There was an error creating the session folder. Please try again.")
        }
        .sheet(isPresented: $showDealPreview) {
            let dealToShow = selectedPreviewBoard.flatMap { composedDealsByBoard[$0] } ?? makeDisplayDeal()
            DealDisplayPictureView(
                sessionFolderURL: sessionFolderURL,
                sessionName: handName,
                deal: dealToShow
            )
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    HandComposeView()
        .padding()
}

