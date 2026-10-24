import AVFoundation
import Combine
import SwiftUI
import UIKit

@MainActor
struct StoryVideoView: View {
    let url: URL
    let accessibilityLabel: Text
    let onAdvance: () -> Void
    @StateObject private var playback: StoryVideoPlayback

    init(url: URL, accessibilityLabel: Text, onAdvance: @escaping () -> Void) {
        self.url = url
        self.accessibilityLabel = accessibilityLabel
        self.onAdvance = onAdvance
        _playback = StateObject(wrappedValue: StoryVideoPlayback(url: url))
    }

    var body: some View {
        StoryPlayerLayer(player: playback.player)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { playback.play() }
            .onDisappear { playback.stop() }
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAction(named: Text("home.story.advance.action")) {
                onAdvance()
            }
    }
}

@MainActor
private final class StoryVideoPlayback: ObservableObject {
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    init(url: URL) {
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
    }

    func play() {
        player.play()
    }

    func stop() {
        player.pause()
    }
}

@MainActor
private struct StoryPlayerLayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> StoryPlayerLayerView {
        let view = StoryPlayerLayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: StoryPlayerLayerView, context: Context) {
        view.playerLayer.player = player
    }
}

private final class StoryPlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
