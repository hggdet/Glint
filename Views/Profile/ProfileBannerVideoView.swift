import AVFoundation
import SwiftUI
import UIKit

@MainActor
struct ProfileBannerVideoView: View {
    let url: URL
    var isActive = true
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var player: AVPlayer?
    @State private var looper: AVPlayerLooper?
    @State private var isPlaying = false

    private var shouldAutoplay: Bool {
        isActive && scenePhase == .active && !reduceMotion
    }
    private var canPlay: Bool {
        isActive && scenePhase == .active
    }

    var body: some View {
        Group {
            if let player {
                ZStack {
                    ProfilePlayerLayerView(player: player)
                    if !isPlaying {
                        Button {
                            guard canPlay else { return }
                            player.seek(to: .zero)
                            player.play()
                            isPlaying = true
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 52, height: 52)
                                .glassEffect(.regular, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("profile.banner.play"))
                    }
                }
            } else {
                Rectangle().fill(GlintPalette.surface.gradient)
            }
        }
        .task(id: url) {
            player?.pause()
            player = nil
            looper = nil
            isPlaying = false
            if reduceMotion {
                player = AVPlayer(url: url)
            } else {
                let queue = AVQueuePlayer()
                queue.isMuted = true
                let item = AVPlayerItem(url: url)
                looper = AVPlayerLooper(player: queue, templateItem: item)
                player = queue
            }
            if shouldAutoplay {
                player?.play()
                isPlaying = true
            }
        }
        .onChange(of: canPlay) { _, canPlay in
            guard let player else { return }
            if !canPlay {
                player.pause()
                isPlaying = false
            } else if !reduceMotion {
                player.play()
                isPlaying = true
            }
        }
        .onChange(of: reduceMotion) { _, prefersReducedMotion in
            guard player != nil else { return }
            if prefersReducedMotion {
                player?.pause()
                player = AVPlayer(url: url)
                looper = nil
                isPlaying = false
            } else {
                let queue = AVQueuePlayer()
                queue.isMuted = true
                let playerLooper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
                player = queue
                looper = playerLooper
                if shouldAutoplay {
                    queue.play()
                    isPlaying = true
                } else {
                    isPlaying = false
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            guard reduceMotion,
                  let item = notification.object as? AVPlayerItem,
                  let currentItem = player?.currentItem,
                  item === currentItem else { return }
            isPlaying = false
        }
        .onDisappear {
            player?.pause()
            player = nil
            looper = nil
            isPlaying = false
        }
        .accessibilityLabel(Text("profile.banner.video"))
    }
}

private struct ProfilePlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerContainer {
        let view = PlayerLayerContainer()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PlayerLayerContainer, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class PlayerLayerContainer: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
