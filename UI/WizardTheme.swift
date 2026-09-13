import SwiftUI

enum WizardTheme {
    static let ink = Color(red: 0.025, green: 0.025, blue: 0.055)
    static let parchment = Color(red: 0.91, green: 0.86, blue: 0.73)
    static let muted = Color(red: 0.62, green: 0.63, blue: 0.72)
    static let gold = Color(red: 0.69, green: 0.55, blue: 0.32)
    static let violet = Color(red: 0.57, green: 0.42, blue: 0.90)

    static func serif(_ size: CGFloat) -> Font { .custom("Georgia", size: size) }
}

struct MoonlitBackdrop: View {
    var body: some View {
        GeometryReader { geometry in
            Image("MoonlitCourt")
                .resizable().scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            LinearGradient(colors: [WizardTheme.ink.opacity(0.91), WizardTheme.ink.opacity(0.54), .clear],
                           startPoint: .leading, endPoint: .trailing)
            LinearGradient(colors: [.black.opacity(0.16), .clear, WizardTheme.ink.opacity(0.90)],
                           startPoint: .top, endPoint: .bottom)
        }.ignoresSafeArea()
    }
}

struct ArcaneSigil: View {
    var size: CGFloat = 42
    var body: some View {
        ZStack {
            Circle().stroke(WizardTheme.gold.opacity(0.6), lineWidth: 0.7)
            Circle().stroke(WizardTheme.gold.opacity(0.3), lineWidth: 0.6).padding(size * 0.1)
            Image(systemName: "moon.stars").font(.system(size: size * 0.37, weight: .ultraLight))
                .foregroundStyle(WizardTheme.parchment)
            Rectangle().fill(WizardTheme.gold).frame(width: 3, height: 3).rotationEffect(.degrees(45)).offset(y: -size / 2)
            Rectangle().fill(WizardTheme.gold).frame(width: 3, height: 3).rotationEffect(.degrees(45)).offset(y: size / 2)
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct ArcaneButton: View {
    let title: String
    var subtitle: String? = nil
    var symbol = "arrow.right"
    var primary = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: primary ? "sparkle" : symbol).font(.system(size: 16, weight: .light))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(WizardTheme.serif(17)).tracking(1.5)
                    if let subtitle { Text(subtitle).font(.system(size: 10)).tracking(0.7).foregroundStyle(WizardTheme.muted) }
                }
                Spacer(minLength: 8)
                if primary { Image(systemName: "arrow.right").font(.system(size: 13)) }
            }
            .foregroundStyle(WizardTheme.parchment)
            .padding(.horizontal, 19).padding(.vertical, subtitle == nil ? 13 : 14)
            .frame(minHeight: 48)
            .background(primary ? WizardTheme.violet.opacity(0.2) : WizardTheme.ink.opacity(0.36))
            .overlay(Rectangle().stroke(primary ? WizardTheme.gold.opacity(0.8) : WizardTheme.gold.opacity(0.20), lineWidth: 0.7))
        }.buttonStyle(.plain)
    }
}

struct EmberField: View {
    var animate = true
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !animate)) { timeline in
            Canvas { context, size in
                let t = animate ? timeline.date.timeIntervalSinceReferenceDate : 0
                for i in 0..<22 {
                    let x = Double((i * 137 + 61) % 1000) / 1000 * size.width
                    let y = (Double((i * 197) % 1000) / 1000 * size.height - t * Double(3 + i % 3))
                        .truncatingRemainder(dividingBy: size.height)
                    let p = CGPoint(x: x + sin(t * 0.2 + Double(i)) * 12, y: y < 0 ? y + size.height : y)
                    context.fill(Path(ellipseIn: CGRect(x: p.x, y: p.y, width: i % 3 == 0 ? 2 : 1, height: i % 3 == 0 ? 2 : 1)),
                                 with: .color(WizardTheme.violet.opacity(0.65)))
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
