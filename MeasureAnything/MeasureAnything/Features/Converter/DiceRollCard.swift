import SwiftUI

struct DiceRollCard: View {
    @ObservedObject var vm: ConverterViewModel

    var body: some View {
        Button {
            vm.rollDice()
        } label: {
            HStack(alignment: .center, spacing: 16) {
                leftColumn
                    .frame(maxWidth: .infinity, alignment: .leading)

                rightColumn
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(vm.isDiceRolling)
        .accessibilityLabel("Roll the dice")
        .accessibilityHint("Randomises the absurd target unit")
        .accessibilityAddTraits(.isButton)
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Roll the\ndice")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
                .fixedSize(horizontal: false, vertical: true)

            subtitleRow
        }
    }

    private var subtitleRow: some View {
        HStack(spacing: 0) {
            Text("landed on ")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0xC8 / 255, green: 0xD9 / 255, blue: 0xFF / 255))

            Text(vm.diceLandedUnitName)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .opacity(vm.showDiceSubtitle ? 1 : 0)
        .frame(minHeight: 14, alignment: .leading) // reserve space so card height is stable
        .animation(.easeIn(duration: 0.25), value: vm.showDiceSubtitle)
    }

    private var rightColumn: some View {
        DiceFaceView(face: $vm.diceDisplayFace)
            .rotationEffect(.degrees(vm.diceRotationDegrees))
    }

    private var cardBackground: some View {
        ZStack {
            Color(red: 0x2B / 255, green: 0x5C / 255, blue: 0xE6 / 255)

            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 2)
                .frame(width: 110, height: 110)
                .offset(x: 52, y: -50)
        }
    }
}

