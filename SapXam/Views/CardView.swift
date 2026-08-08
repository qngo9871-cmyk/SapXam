import SwiftUI

struct CardView: View {
    let card: Card
    var selected: Bool = false
    var faceDown: Bool = false
    var width: CGFloat = 46

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(faceDown ? AnyShapeStyle(backGradient) : AnyShapeStyle(Color.white))
            .frame(width: width, height: width * 1.45)
            .overlay {
                if !faceDown {
                    VStack(spacing: 2) {
                        Text(card.rank.label)
                            .font(.system(size: width * 0.32, weight: .bold, design: .rounded))
                        Text(card.suit.symbol)
                            .font(.system(size: width * 0.32))
                    }
                    .foregroundStyle(card.suit.isRed ? .red : .black)
                } else {
                    Image(systemName: "suit.spade.fill")
                        .foregroundStyle(.white.opacity(0.35))
                        .font(.system(size: width * 0.4))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? Color.yellow : Color.black.opacity(0.25), lineWidth: selected ? 3 : 1)
            )
            .offset(y: selected ? -14 : 0)
            .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
            .animation(.spring(response: 0.25), value: selected)
    }

    private var backGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.05, green: 0.2, blue: 0.45), Color(red: 0.02, green: 0.08, blue: 0.25)],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

#Preview {
    HStack {
        CardView(card: Card(rank: .ace, suit: .spades))
        CardView(card: Card(rank: .two, suit: .hearts), selected: true)
        CardView(card: Card(rank: .ten, suit: .diamonds), faceDown: true)
    }
    .padding().background(Color.green)
}
