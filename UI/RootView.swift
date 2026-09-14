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
        .alert("The realm is unavailable", isPresented: Binding(get: { session.errorMessage != nil },
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
                if session.selectedMap == .volcano {
                    LinearGradient(colors: [.black.opacity(0.2), .red.opacity(0.35), .black.opacity(0.65)],
                                   startPoint: .topTrailing, endPoint: .bottomLeading).ignoresSafeArea()
                }
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
                                Text(session.selectedMap.title.uppercased()).font(.system(size: 10)).tracking(2).foregroundStyle(WizardTheme.gold)
                            }
                            if !compact {
                                Text("The night listens.\nGive it something to fear.")
                                    .font(WizardTheme.serif(17)).lineSpacing(5).foregroundStyle(WizardTheme.muted).padding(.top, 8)
                            }
                        }
                        VStack(spacing: 7) {
                            ArcaneButton(title: "Enter the realm", subtitle: session.selectedMap.title, primary: true) { session.enterCourt() }
                            HStack(spacing: 7) {
                                ArcaneButton(title: "Grimoire", symbol: "book.closed") { grimoire = true }
                                ArcaneButton(title: "Settings", symbol: "slider.horizontal.3") { settings = true }
                            }
                        }
                        if session.selectedMap == .volcano {
                            Picker("Starting team", selection: $session.selectedTeam) {
                                ForEach(TeamID.allCases, id: \.rawValue) { team in Text(team.title).tag(team) }
                            }.pickerStyle(.segmented).accessibilityLabel("Choose starting castle team")
                        }
                        Spacer(minLength: 0)
                        HStack(spacing: 7) {
                            Circle().fill(WizardTheme.violet).frame(width: 4, height: 4)
                            Text("SOLO PRACTICE").tracking(1.5)
                            Text("·").padding(.horizontal, 3)
                            Text("v0.5 · Moonlit valley")
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
                            Text("SELECT MAP").font(.system(size: 9)).tracking(2).foregroundStyle(WizardTheme.muted)
                            Menu {
                                ForEach(MapID.playable, id: \.rawValue) { map in
                                    Button { session.selectedMap = map } label: {
                                        Label(map.title, systemImage: session.selectedMap == map ? "checkmark" : map.symbol)
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: session.selectedMap.symbol)
                                    Text(session.selectedMap.title).font(WizardTheme.serif(13))
                                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
                                }.foregroundStyle(WizardTheme.parchment).padding(12)
                                    .frame(minHeight: 44).background(WizardTheme.ink.opacity(0.85))
                                    .overlay(Rectangle().stroke(WizardTheme.gold.opacity(0.55), lineWidth: 1))
                            }.accessibilityLabel("Select map")
                            Text(session.selectedMap.subtitle).font(.system(size: 7)).tracking(0.5).foregroundStyle(WizardTheme.muted)
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
                    Text(session.selectedMap.title.uppercased()).font(WizardTheme.serif(26)).tracking(4).foregroundStyle(WizardTheme.parchment)
                    Text(session.selectedMap.subtitle).font(.system(size: 9)).tracking(2).foregroundStyle(WizardTheme.muted)
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
                        Text("Speak Fireball, Ice Shards, Mud Blast, or Shadow Bolt. Your book will follow.")
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
                    Toggle("Menu music", isOn: $session.musicEnabled)
                    Toggle("Spell sound effects", isOn: $session.soundEnabled)
                    Button("Test sound") { session.testSound() }
                    Text(session.audioStatus).font(.footnote).foregroundStyle(.secondary)
                    Text("Original ambient music plays in the menu. Test sound plays even when spell effects are switched off.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text(session.voiceStatus).font(.footnote).foregroundStyle(.secondary)
                    Text("Last speech diagnostic: \(session.speechDiagnostic)").font(.caption).textSelection(.enabled)
                    Text("Casting uses English on-device speech recognition. Say a spell name, then pause briefly. Page buttons only select; they never cast.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Open microphone permissions") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
                Section("Volcano graphics") {
                    Toggle("Legacy pixel filter", isOn: $session.retroEffectsEnabled)
                    Text("Off by default to preserve castle detail. Applies next time you enter the volcano. Moonlight, stars and localized mist work without it.").font(.footnote)
                    Text(session.graphicsStatus).font(.footnote).textSelection(.enabled)
                }
                Section("Controls") {
                    Text("Touch: left thumbstick to move, drag right to look; use page arrows or spell emblems to turn the book. Controller: sticks to move/look, LB/RB to turn pages, Menu to pause. Speaking any known spell selects and casts it when ready.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Build") {
                    Text("Nocturne 0.5.0 (6) · Detailed valley and grimoire").font(.footnote)
                    Text("Volcano: full-detail castles, moonlight, volcanic terrain and lava hazards. Hollow Court: original test arena.").font(.footnote)
                }
            }.scrollContentBackground(.hidden).background(WizardTheme.ink)
                .navigationTitle("Ritual settings").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.tint(WizardTheme.parchment).preferredColorScheme(.dark)
    }
}

struct GrimoireView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selected: SpellID = .fireball
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    HStack(spacing: 15) {
                        ForEach(SpellID.allCases, id: \.rawValue) { spell in
                            Button { selected = spell } label: {
                                SpellEmblem(spell: spell).frame(width: 48, height: 48)
                                    .opacity(selected == spell ? 1 : 0.45)
                            }.buttonStyle(.plain)
                        }
                    }
                    SpellEmblem(spell: selected).frame(width: 88, height: 88)
                    Text(PrototypeContent.definition(selected).presentation.bookPage.uppercased()).font(WizardTheme.serif(35)).tracking(6)
                    Text("SPEAK  ‘\(selected.title.uppercased())’").font(.system(size: 12)).tracking(3).foregroundStyle(Color(selected.color))
                    Text(selected.description)
                        .font(WizardTheme.serif(17)).multilineTextAlignment(.center).lineSpacing(6)
                    Divider().overlay(WizardTheme.gold.opacity(0.25))
                    Text(String(format: "%.1f SECOND BASE COOLDOWN", Double(PrototypeContent.definition(selected).baseCooldownTicks) / 60)).font(.system(size: 10)).tracking(1)
                    Text("All four spells are available to every order in practice. Speak a spell to change pages and cast it. A shared recovery prevents rapid page-switching from bypassing cooldowns. Banish ten sentinels; use the stone bridges to cross the volcano's lava.")
                        .font(.system(size: 14)).foregroundStyle(WizardTheme.muted).multilineTextAlignment(.center)
                }.foregroundStyle(WizardTheme.parchment).padding(32).frame(maxWidth: 620)
            }.frame(maxWidth: .infinity).background(WizardTheme.ink)
                .navigationTitle("Your grimoire").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Close") { dismiss() } } }
        }.tint(WizardTheme.parchment).preferredColorScheme(.dark)
    }
}
