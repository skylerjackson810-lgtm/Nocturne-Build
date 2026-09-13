import SwiftUI

struct GameHUD: View {
    @ObservedObject var session: GameSession
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LookSurface(input: session.input).frame(width: geometry.size.width * 0.54)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                // Decorative reticle never receives touches.
                ZStack {
                    Circle().stroke(WizardTheme.parchment.opacity(0.55), lineWidth: 0.7).frame(width: 17, height: 17)
                    Circle().fill(WizardTheme.parchment).frame(width: 2, height: 2)
                }.allowsHitTesting(false)
                VStack {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: session.selectedClass.sigil).foregroundStyle(WizardTheme.gold)
                                Text(session.selectedClass.title.uppercased()).font(.system(size: 9, weight: .medium)).tracking(2)
                            }
                            HStack(spacing: 8) {
                                GeometryReader { bar in
                                    ZStack(alignment: .leading) {
                                        Rectangle().fill(.white.opacity(0.12))
                                        Rectangle().fill(Color(red: 0.63, green: 0.26, blue: 0.32))
                                            .frame(width: bar.size.width * CGFloat(session.health / PrototypeContent.stats(session.selectedClass).maximumHealth))
                                    }
                                }.frame(width: 110, height: 3)
                                Text("\(Int(session.health))").font(.system(size: 10, design: .monospaced))
                            }
                        }
                        Spacer()
                        VStack(spacing: 5) {
                            Text("THE HOLLOW COURT").font(WizardTheme.serif(12)).tracking(2)
                            Text("SENTINELS BANISHED  \(session.defeated) / 10").font(.system(size: 8)).tracking(1.4).foregroundStyle(WizardTheme.muted)
                        }
                        Spacer()
                        Button { session.pause() } label: {
                            Image(systemName: "pause").font(.system(size: 16)).frame(width: 44, height: 44)
                                .background(WizardTheme.ink.opacity(0.6)).overlay(Circle().stroke(WizardTheme.gold.opacity(0.3), lineWidth: 0.7))
                        }.buttonStyle(.plain).accessibilityLabel("Pause game")
                    }
                    if !session.banner.isEmpty {
                        Text(session.banner).font(WizardTheme.serif(13)).foregroundStyle(WizardTheme.parchment)
                            .padding(.horizontal, 15).padding(.vertical, 8).background(WizardTheme.ink.opacity(0.65))
                            .padding(.top, 6).allowsHitTesting(false)
                    }
                    Spacer()
                    HStack(alignment: .bottom) {
                        MovementStick(input: session.input)
                        Spacer()
                        VStack(spacing: 7) {
                            Text(session.cooldown > 0 ? "GATHERING EMBERS" : "SPEAK  ‘FIREBALL’")
                                .font(.system(size: 10, weight: .medium)).tracking(2).foregroundStyle(WizardTheme.parchment)
                            GeometryReader { bar in
                                ZStack(alignment: .leading) {
                                    Rectangle().fill(WizardTheme.gold.opacity(0.16))
                                    Rectangle().fill(WizardTheme.gold).frame(width: bar.size.width * CGFloat(1 - session.cooldown))
                                }
                            }.frame(width: 130, height: 2)
                            if !session.transcript.isEmpty {
                                Text(session.transcript).font(WizardTheme.serif(11)).lineLimit(1).foregroundStyle(WizardTheme.muted)
                            }
                            Button { session.toggleVoice() } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: session.voiceActive ? "mic.fill" : "mic.slash")
                                        .foregroundStyle(session.voiceActive ? WizardTheme.violet : WizardTheme.muted)
                                    Text(session.voiceStatus).lineLimit(2).multilineTextAlignment(.leading)
                                }.font(.system(size: 10)).padding(.horizontal, 13).frame(minHeight: 44)
                                    .background(WizardTheme.ink.opacity(0.70))
                            }.buttonStyle(.plain).frame(maxWidth: 310).disabled(session.requestingVoice)
                                .accessibilityLabel(session.voiceActive ? "Turn microphone off" : "Enable microphone")
                            HStack(spacing: 3) {
                                ForEach(0..<12) { index in
                                    Capsule().fill(session.voiceActive && session.microphoneLevel > Float(index) / 12
                                        ? WizardTheme.violet : WizardTheme.muted.opacity(0.2))
                                        .frame(width: 5, height: 4 + CGFloat(index % 3) * 2)
                                }
                            }.accessibilityLabel("Microphone input level")
                                .accessibilityValue("\(Int(session.microphoneLevel * 100)) percent")
                                .allowsHitTesting(false)
                        }.frame(maxWidth: 320)
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "viewfinder").font(.system(size: 21, weight: .ultraLight))
                            Text("DRAG TO LOOK").font(.system(size: 7)).tracking(1.5)
                        }.foregroundStyle(WizardTheme.parchment.opacity(0.50)).frame(width: 110, height: 65)
                            .allowsHitTesting(false)
                    }
                }.padding(.horizontal, 26).padding(.top, 12).padding(.bottom, 15)
                if session.hitFlash > 0 {
                    Color.red.opacity(Double(session.hitFlash) * 0.16).ignoresSafeArea().allowsHitTesting(false)
                }
            }.foregroundStyle(WizardTheme.parchment)
                .allowsHitTesting(session.phase == .playing)
        }
    }
}

private struct LookSurface: View {
    let input: InputRouter
    @State private var previous = CGSize.zero
    var body: some View {
        Color.clear.contentShape(Rectangle()).gesture(
            DragGesture(minimumDistance: 0).onChanged { value in
                let delta = SIMD2<Float>(Float(value.translation.width - previous.width), Float(value.translation.height - previous.height))
                input.addLook(delta); previous = value.translation
            }.onEnded { _ in previous = .zero }
        ).accessibilityLabel("Drag to look around")
    }
}

private struct MovementStick: View {
    @ObservedObject var input: InputRouter
    @State private var offset = CGSize.zero
    var body: some View {
        ZStack {
            Circle().fill(WizardTheme.ink.opacity(0.28))
            Circle().stroke(WizardTheme.parchment.opacity(0.23), lineWidth: 0.7)
            Circle().stroke(WizardTheme.parchment.opacity(0.12), lineWidth: 0.6).padding(14)
            Circle().fill(WizardTheme.parchment.opacity(0.13)).frame(width: 39, height: 39)
                .overlay(Circle().stroke(WizardTheme.parchment.opacity(0.35), lineWidth: 0.7)).offset(offset)
        }.frame(width: 105, height: 105)
            .opacity(input.hardwareConnected ? 0 : 1)
            .allowsHitTesting(!input.hardwareConnected)
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                let x = value.translation.width, y = value.translation.height
                let length = max(1, sqrt(x * x + y * y)), capped = min(37, length)
                offset = CGSize(width: x / length * capped, height: y / length * capped)
                input.touchMovement = SIMD2(Float(offset.width / 37), Float(-offset.height / 37))
            }.onEnded { _ in offset = .zero; input.touchMovement = .zero })
            .onDisappear { input.touchMovement = .zero }
            .accessibilityLabel("Movement joystick")
    }
}

struct PauseView: View {
    @ObservedObject var session: GameSession
    @State private var settings = false
    var body: some View {
        ZStack {
            WizardTheme.ink.opacity(0.90).ignoresSafeArea()
            VStack(spacing: 15) {
                ArcaneSigil(size: 48)
                Text("THE NIGHT CAN WAIT").font(WizardTheme.serif(24)).tracking(3).foregroundStyle(WizardTheme.parchment)
                Text("Your ritual is paused.").font(WizardTheme.serif(13)).foregroundStyle(WizardTheme.muted)
                VStack(spacing: 8) {
                    ArcaneButton(title: "Return to the court", primary: true) { session.resume() }
                    HStack(spacing: 8) {
                        ArcaneButton(title: "Settings", symbol: "slider.horizontal.3") { settings = true }
                        ArcaneButton(title: "Main menu", symbol: "door.left.hand.open") { session.leave() }
                    }
                }.frame(maxWidth: 380)
            }.padding(22)
        }.sheet(isPresented: $settings) { SettingsView(session: session) }
    }
}
