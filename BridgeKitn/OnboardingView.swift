//
//  OnboardingView.swift
//  BridgeTeacherHandCompose
//
//  Created by Gerald Dawson on 9/1/2026.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var selection: Int = 0

    private let baseGreen = Color(red: 46.0/255.0, green: 123.0/255.0, blue: 96.0/255.0)

    var body: some View {
        ZStack {
            // Background, themed to match the deal display screen
            ZStack {
                Rectangle().fill(baseGreen)
                Rectangle().fill(.ultraThinMaterial).opacity(0.12)
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(red: 46.0/255.0, green: 123.0/255.0, blue: 96.0/255.0), location: 0.0),
                        .init(color: Color(red: 11.0/255.0, green: 61.0/255.0,  blue: 46.0/255.0), location: 0.55),
                        .init(color: Color(red: 6.0/255.0,  green: 40.0/255.0,  blue: 32.0/255.0), location: 1.0)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 900
                )
                .opacity(0.55)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Spacer()
                    Button("Skip") { hasCompletedOnboarding = true }
                        .buttonStyle(.plain)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
                        .padding()
                }

                // Pages
                TabView(selection: $selection) {
                    OnboardingPage(
                        title: "Welcome to BridgeCompose",
                        subtitle: { HStack(spacing: 0) { Text("Compose teaching "); Text("deals").foregroundStyle(.yellow); Text(" in seconds.") } },
                        bullets: [
                            AnyView(HStack(spacing: 0) { bullet(text: "Start a "); colored("New Session", .blue); bullet(text: ", name it, then "); colored("Save", .yellow) }),
                            AnyView(HStack(spacing: 0) { bullet(text: "Deal cards for N, E, S, W "); Text("♠️").foregroundStyle(.primary); Text("❤️").foregroundStyle(.red); Text("♦️").foregroundStyle(.red); Text("♣️").foregroundStyle(.primary) })
                        ],
                        symbol: "rectangle.stack.badge.plus",
                        accent: .yellow
                    )
                    .tag(0)

                    OnboardingPage(
                        title: "Organise Sessions",
                        subtitle: { HStack(spacing: 0) { Text("All hands saved as "); Text(".pbn").foregroundStyle(.orange); Text(" in your Documents.") } },
                        bullets: [
                            AnyView(bullet(text: "Create a dedicated folder per session automatically.")),
                            AnyView(HStack(spacing: 0) { bullet(text: "Use the "); colored("Board", .yellow); bullet(text: " counter to keep track.") })
                        ],
                        symbol: "folder.badge.plus",
                        accent: .orange
                    )
                    .tag(1)

                    OnboardingPage(
                        title: "Preview & Record",
                        subtitle: { HStack(spacing: 0) { Text("Review layouts and "); Text("Record").foregroundStyle(.red); Text(" snapshots.") } },
                        bullets: [
                            AnyView(bullet(text: "Preview any composed board instantly.")),
                            AnyView(HStack(spacing: 0) { bullet(text: "Tap "); colored("Record", .red); bullet(text: " to save notes and an image.") }),
                            AnyView(HStack(spacing: 0) { bullet(text: "Then choose "); colored("Next hand", .yellow); bullet(text: " to continue.") })
                        ],
                        symbol: "camera.badge.ellipsis",
                        accent: .red
                    )
                    .tag(2)
                }
                #if os(iOS)
                .tabViewStyle(.page)
                #else
                .tabViewStyle(.automatic)
                #endif
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom controls
                HStack {
                    Button {
                        withAnimation(.easeInOut) { selection = max(selection - 1, 0) }
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    .font(.title3)
                    .tint(.secondary)
                    .opacity(selection == 0 ? 0.35 : 1)
                    .disabled(selection == 0)

                    Spacer()

                    if selection < 2 {
                        Button {
                            withAnimation(.easeInOut) { selection = min(selection + 1, 2) }
                        } label: {
                            Label("Next", systemImage: "chevron.right")
                        }
                        .buttonStyle(.borderedProminent)
                        .font(.title3)
                    } else {
                        Button {
                            hasCompletedOnboarding = true
                        } label: {
                            Text("Get Started")
                                .font(.title3)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.yellow)
                    }
                }
                .padding()
            }
        }
    }

    private func bullet(text: String) -> Text { Text(text).foregroundStyle(.secondary) }
    private func colored(_ text: String, _ color: Color) -> Text { Text(text).foregroundStyle(color) }
}

private struct OnboardingPage<Subtitle: View>: View {
    let title: String
    let subtitle: () -> Subtitle
    let bullets: [AnyView]
    let symbol: String
    let accent: Color

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)

            Image(systemName: symbol)
                .font(.system(size: 80, weight: .regular))
                .foregroundStyle(accent)
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                .padding(.bottom, 8)

            Text(title)
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [accent, accent.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .multilineTextAlignment(.center)

            subtitle()
                .font(.title.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.95))

            VStack(alignment: .leading, spacing: 10) {
                ForEach(bullets.indices, id: \.self) { i in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle()
                            .fill(accent.opacity(0.9))
                            .frame(width: 8, height: 8)
                        bullets[i]
                    }
                }
            }
            .font(.title)
            .frame(maxWidth: 560)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    OnboardingView()
}

