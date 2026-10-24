import AVFoundation
import Combine
import SwiftUI
import UIKit

@MainActor
struct ReelVideoPlayerView: View {
    let url: URL
    let isPlaying: Bool
    let isMuted: Bool
    let accessibilityLabel: Text
    let onToggleMute: () -> Void
    let onLongPressReport: () -> Void

    @StateObject private var playback: ReelVideoPlayback

    init(
        url: URL,
        isPlaying: Bool,
        isMuted: Bool,
        accessibilityLabel: Text,
        onToggleMute: @escaping () -> Void,
        onLongPressReport: @escaping () -> Void
    ) {
        self.url = url
        self.isPlaying = isPlaying
        self.isMuted = isMuted
        self.accessibilityLabel = accessibilityLabel
        self.onToggleMute = onToggleMute
        self.onLongPressReport = onLongPressReport
        _playback = StateObject(wrappedValue: ReelVideoPlayback(url: url))
    }

    var body: some View {
        ReelPlayerLayer(player: playback.player)
            .background(.black)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { onToggleMute() }
            .onLongPressGesture(minimumDuration: 0.55, perform: onLongPressReport)
            .onChange(of: isPlaying) { _, active in
                active ? playback.play() : playback.pause()
            }
            .onChange(of: isMuted) { _, muted in playback.setMuted(muted) }
            .onAppear {
                playback.setMuted(isMuted)
                if isPlaying { playback.play() }
            }
            .onDisappear { playback.pause() }
            .accessibilityElement()
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(Text(isMuted ? "reels.sound.muted" : "reels.sound.on"))
            .accessibilityHint(Text("reels.video.hint"))
            .accessibilityAction(named: Text("reels.sound.toggle")) { onToggleMute() }
            .accessibilityAction(named: Text("reels.report.action")) { onLongPressReport() }
    }
}

@MainActor
private final class ReelVideoPlayback: ObservableObject {
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    init(url: URL) {
        player.isMuted = true
        player.actionAtItemEnd = .none
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
    }

    func play() { player.play() }
    func pause() { player.pause() }
    func setMuted(_ muted: Bool) { player.isMuted = muted }
}

@MainActor
private struct ReelPlayerLayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> ReelPlayerLayerView {
        let view = ReelPlayerLayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: ReelPlayerLayerView, context: Context) {
        view.playerLayer.player = player
    }
}

private final class ReelPlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
