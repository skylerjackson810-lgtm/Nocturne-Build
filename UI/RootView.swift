import SwiftUI
import RealityKit
import UIKit

struct RootView: View {
    @ObservedObject var session: GameSession
    var body: some View {
        ZStack {
            WizardTheme.ink.ignoresSafeArea()
            switch session.phase {
            case .menu: MainMenuView(session: session)
            case .loading: LoadingView(session: session)
            case .playing, .paused:
                if let view = session.view { GameViewport(view: view).ignoresSafeArea() }
                GameHUD(session: session)
                if session.phase == .paused { PauseView(session: session) }
            }
        }
        .alert("The court is unavailable", isPresented: Binding(get: { session.errorMessage != nil },
            set: { if !$0 { session.errorMessage = nil } })) {
            Button("Return", role: .cancel) { session.errorMessage = nil }
        } message: { Text(session.errorMessage ?? "") }
    }
}

struct GameViewport: UIViewRepresentable {
    let view: ARView
    func makeUIView(context: Context) -> ARView { view }
    func updateUIView(_ uiView: ARView, context: Context) {}
}

struct MainMenuView: View {
    @ObservedObject var session: GameSession
    @State private var settings = false
    @State private var grimoire = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 450
            ZStack {
                MoonlitBackdrop()
                EmberField(animate: !reduceMotion && !session.reducedMotion)
                HStack(alignment: .top, spacing: 28) {
                    VStack(alignment: .leading, spacing: compact ? 13 : 23) {
                        HStack(spacing: 10) {
                            ArcaneSigil(size: 30)
                            Text("A VOICEBOUND WIZARD DUEL")
                                .font(.system(size: 9, weight: .medium)).tracking(2.8).foregroundStyle(WizardTheme.muted)
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            Text("NOCTURNE").font(WizardTheme.serif(compact ? 43 : 64)).tracking(compact ? 5 : 8)
                                .foregroundStyle(WizardTheme.parchment).minimumScaleFactor(0.6).lineLimit(1)
                            HStack(spacing: 11) {
                                Rectangle().fill(WizardTheme.gold).frame(width: 25, height: 1)
                                Text("THE HOLLOW COURT").font(.system(size: 10)).tracking(3).foregroundStyle(WizardTheme.gold)
                            }
                            if !compact {
                                Text("The night listens.\nGive it something to fear.")
                                    .font(WizardTheme.serif(17)).lineSpacing(5).foregroundStyle(WizardTheme.muted).padding(.top, 8)
                            }
                        }
                        VStack(spacing: 7) {
                            ArcaneButton(title: "Enter the court", subtitle: "Moonlit training grounds", primary: true) { session.enterCourt() }
                            HStack(spacing: 7) {
                                ArcaneButton(title: "Grimoire", symbol: "book.closed") { grimoire = true }
                                ArcaneButton(title: "Settings", symbol: "slider.horizontal.3") { settings = true }
                            }
                        }
                        Spacer(minLength: 0)
                        HStack(spacing: 7) {
                            Circle().fill(WizardTheme.violet).frame(width: 4, height: 4)
                            Text("SOLO PRACTICE").tracking(1.5)
                            Text("·").padding(.horizontal, 3)
                            Text("Your voice is your weapon.")
                        }.font(.system(size: 9)).foregroundStyle(WizardTheme.muted)
                    }.frame(width: min(geometry.size.width * 0.49, 470))
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 10) {
                        Text("CHOOSE YOUR ORDER").font(.system(size: 9)).tracking(2).foregroundStyle(WizardTheme.muted)
                        ForEach(WizardClassID.allCases, id: \.rawValue) { wizard in
                            Button { session.selectedClass = wizard } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: wizard.sigil).font(.system(size: 19, weight: .light))
                                        .frame(width: 24).foregroundStyle(session.selectedClass == wizard ? WizardTheme.parchment : WizardTheme.muted)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(wizard.title).font(WizardTheme.serif(14))
                                        Text(wizard.subtitle).font(.system(size: 7)).tracking(1.2).foregroundStyle(WizardTheme.muted)
                                    }
                                    Spacer(minLength: 0)
                                    if session.selectedClass == wizard { Image(systemName: "checkmark").font(.system(size: 10)) }
                                }
                                .foregroundStyle(WizardTheme.parchment).padding(.horizontal, 13).padding(.vertical, compact ? 10 : 14)
                                .frame(minHeight: 44)
                                .background(WizardTheme.ink.opacity(session.selectedClass == wizard ? 0.80 : 0.50))
                                .overlay(Rectangle().stroke(WizardTheme.gold.opacity(session.selectedClass == wizard ? 0.75 : 0.18), lineWidth: 0.7))
                            }.buttonStyle(.plain)
                        }
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 5) {
                            Text("THE HOLLOW COURT").font(WizardTheme.serif(15)).foregroundStyle(WizardTheme.parchment)
                            Text("MIDNIGHT  /  WAXING MAGIC").font(.system(size: 8)).tracking(1.8).foregroundStyle(WizardTheme.muted)
                        }
                    }.frame(width: min(220, geometry.size.width * 0.29))
                }.padding(.horizontal, compact ? 28 : 48).padding(.vertical, compact ? 23 : 42)
            }
        }
        .sheet(isPresented: $settings) { SettingsView(session: session) }
        .sheet(isPresented: $grimoire) { GrimoireView() }
    }
}

struct LoadingView: View {
    @ObservedObject var session: GameSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                MoonlitBackdrop()
                WizardTheme.ink.opacity(0.40).ignoresSafeArea()
                EmberField(animate: !reduceMotion && !session.reducedMotion)
                VStack(spacing: 15) {
                    Spacer()
                    ArcaneSigil(size: geometry.size.height < 450 ? 65 : 110)
                    Text("THE HOLLOW COURT").font(WizardTheme.serif(26)).tracking(5).foregroundStyle(WizardTheme.parchment)
                    Text("BENEATH THE MOON, YOUR TRIAL AWAITS").font(.system(size: 9)).tracking(2).foregroundStyle(WizardTheme.muted)
                    Spacer()
                    VStack(spacing: 10) {
                        HStack {
                            Text(session.loadingMessage).font(WizardTheme.serif(13))
                            Spacer()
                            Text("\(Int(session.progress * 100))%").font(.system(size: 10, design: .monospaced))
                        }.foregroundStyle(WizardTheme.parchment)
                        GeometryReader { bar in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(WizardTheme.gold.opacity(0.15))
                                Rectangle().fill(WizardTheme.gold).frame(width: bar.size.width * session.progress)
                            }
                        }.frame(height: 2)
                        Text("Speak ‘Fireball’ clearly, then leave a brief silence. Your hands will follow.")
                            .font(.system(size: 10)).foregroundStyle(WizardTheme.muted).padding(.top, 3)
                    }.frame(maxWidth: 480)
                }.padding(.horizontal, 32).padding(.vertical, 30)
            }
        }.accessibilityElement(children: .combine)
    }
}

struct SettingsView: View {
    @ObservedObject var session: GameSession
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("The way you move") {
                    HStack { Text("Look sensitivity"); Spacer(); Text(String(format: "%.1f×", session.sensitivity)).foregroundStyle(.secondary) }
                    Slider(value: $session.sensitivity, in: 0.5...2, step: 0.1)
                    Toggle("Invert vertical look", isOn: $session.invertY)
                    Toggle("Reduce motion and floating embers", isOn: $session.reducedMotion)
                }
                Section("The sound of magic") {
                    Toggle("Spell sound effects", isOn: $session.soundEnabled)
                    Button("Test sound") { session.testSound() }
                    Text(session.audioStatus).font(.footnote).foregroundStyle(.secondary)
                    Text("This prototype has cast, impact, and damage sounds, but no background music yet. Test sound plays even when spell effects are switched off.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text(session.voiceStatus).font(.footnote).foregroundStyle(.secondary)
                    Text("Casting uses English on-device speech recognition. A short pause after ‘Fireball’ completes the incantation. No button casts a spell.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Open microphone permissions") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
                Section("Controls") {
                    Text("Touch: left thumbstick to move, drag the right half to look. Controllers: left stick to move, right stick to look, Menu to pause.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }.scrollContentBackground(.hidden).background(WizardTheme.ink)
                .navigationTitle("Ritual settings").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.tint(WizardTheme.parchment).preferredColorScheme(.dark)
    }
}

struct GrimoireView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Image(systemName: "flame").font(.system(size: 42, weight: .ultraLight)).foregroundStyle(.orange)
                    Text("IGNIS").font(WizardTheme.serif(35)).tracking(6)
                    Text("SPEAK  ‘FIREBALL’").font(.system(size: 12)).tracking(3).foregroundStyle(WizardTheme.gold)
                    Text("Draw an ember from the silence. Shape it in your palm.\nLet your voice give it flight.")
                        .font(WizardTheme.serif(17)).multilineTextAlignment(.center).lineSpacing(6)
                    Divider().overlay(WizardTheme.gold.opacity(0.25))
                    Text("50 DAMAGE     ·     2 SECOND BASE COOLDOWN").font(.system(size: 10)).tracking(1)
                    Text("Banish ten sentinels to master the trial. Each takes two hits and returns after six seconds. Sidestep their violet bolts. All three orders practice Fireball in this first trial; their health, movement and cooldown stats differ.")
                        .font(.system(size: 14)).foregroundStyle(WizardTheme.muted).multilineTextAlignment(.center)
                }.foregroundStyle(WizardTheme.parchment).padding(32).frame(maxWidth: 620)
            }.frame(maxWidth: .infinity).background(WizardTheme.ink)
                .navigationTitle("Your grimoire").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Close") { dismiss() } } }
        }.tint(WizardTheme.parchment).preferredColorScheme(.dark)
    }
}
