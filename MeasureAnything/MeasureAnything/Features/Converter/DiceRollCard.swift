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
        VStack(alignment: .leading, spacing: 6) {
            Text("Roll the dice")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
                .lineLimit(1)

            Text("randomise absurd unit")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0x9A / 255, green: 0xB4 / 255, blue: 0xEE / 255))
                .textCase(.none)
                .lineLimit(1)

            if vm.showDiceResultPill, !vm.diceResultPillText.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                    Text(vm.diceResultPillText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )
                .transition(.opacity)
            }
        }
        .animation(.easeIn(duration: 0.25), value: vm.showDiceResultPill)
    }

    private var rightColumn: some View {
        VStack(alignment: .center, spacing: 6) {
            DiceFaceView(face: $vm.diceDisplayFace, isRolling: $vm.isDiceRolling)
                .rotationEffect(.degrees(vm.diceRotationDegrees))

            Text(vm.diceFaceLabel)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.5))
                .opacity(vm.diceFaceLabel.isEmpty ? 0 : 1)
                .animation(.easeIn(duration: 0.2), value: vm.diceFaceLabel)
        }
        .frame(width: 62)
    }

    private var cardBackground: some View {
        ZStack {
            Color(red: 0x2B / 255, green: 0x5C / 255, blue: 0xE6 / 255)

            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 2)
                .frame(width: 120, height: 120)
                .offset(x: 56, y: -54)
        }
    }
}

