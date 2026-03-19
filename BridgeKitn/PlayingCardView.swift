import SwiftUI

struct PlayingCardView: View {
    let rank: String   // e.g., "A", "K", "Q", "J", "T", ..., "2"
    let suitSymbol: String // e.g., "♠︎", "♥︎", "♦︎", "♣︎"
    let isRed: Bool

    // Convenience initializer from a code like "AS", "TD", etc.
    init(code: String) {
        self.rank = String(code.dropLast())
        let suitChar: Character = code.last ?? "S"
        switch suitChar {
        case "H":
            self.suitSymbol = "♥︎"; self.isRed = true
        case "D":
            self.suitSymbol = "♦︎"; self.isRed = true
        case "C":
            self.suitSymbol = "♣︎"; self.isRed = false
        default:
            self.suitSymbol = "♠︎"; self.isRed = false
        }
    }

    init(rank: String, suitSymbol: String, isRed: Bool) {
        self.rank = rank
        self.suitSymbol = suitSymbol
        self.isRed = isRed
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let inset = w * 0.24
            let iw = max(w - inset * 2, 1)
            let rankFont = max(iw * 0.62, 12) + 2
            let suitFont = max(iw * 0.54, 10) + 2
            let radius = iw * 0.06
            let emphasizedRadius = radius * 3.5
            let stroke = max(iw * 0.012, 0.75)
            let topPad = iw * 0.04
            let leftPad = iw * 0.06
            let suitColor: Color = isRed ? Color(red: 0.75, green: 0.05, blue: 0.08) : Color.black

            ZStack {
                UnevenRoundedRectangle(
                    cornerRadii: .init(
                        topLeading: emphasizedRadius,
                        bottomLeading: radius,
                        bottomTrailing: emphasizedRadius,
                        topTrailing: radius
                    ),
                    style: .continuous
                )
                .fill(Color.white)
                .padding(inset)

                UnevenRoundedRectangle(
                    cornerRadii: .init(
                        topLeading: emphasizedRadius,
                        bottomLeading: radius,
                        bottomTrailing: emphasizedRadius,
                        topTrailing: radius
                    ),
                    style: .continuous
                )
                .stroke(Color.black.opacity(0.6), lineWidth: stroke)
                .padding(inset)

                VStack(alignment: .leading, spacing: 0) {
                    Text(rank)
                        .font(.system(size: rankFont, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.black)
                    Text(suitSymbol)
                        .font(.system(size: suitFont, weight: .regular, design: .rounded))
                        .foregroundStyle(suitColor)
                        .padding(.top, -(rankFont * 0.16))
                }
                .padding(.leading, inset + leftPad)
                .padding(.top, inset + topPad)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .aspectRatio(2.5/3.5, contentMode: .fit)
    }
}

#Preview {
    VStack(spacing: 16) {
        PlayingCardView(code: "AS")
            .frame(width: 140)
        PlayingCardView(code: "TH")
            .frame(width: 140)
        PlayingCardView(code: "2D")
            .frame(width: 140)
        PlayingCardView(code: "KC")
            .frame(width: 140)
    }
    .padding()
}
