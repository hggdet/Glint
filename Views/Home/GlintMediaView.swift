import AVKit
import SwiftUI
import UIKit

struct GlintMediaView: View {
    let media: PostMedia
    var cornerRadius: CGFloat = 18
    @State private var player: AVPlayer?

    var videoURL: URL? {
        if let localFileURL = media.localFileURL { return localFileURL }
        guard media.kind == .video, let assetName = media.assetName else { return nil }
        return Bundle.main.url(forResource: assetName, withExtension: "mp4", subdirectory: "Media")
            ?? Bundle.main.url(forResource: assetName, withExtension: "mp4", subdirectory: "Resources/Media")
            ?? Bundle.main.url(forResource: assetName, withExtension: "mp4")
    }

    private var image: UIImage? {
        if let localFileURL = media.localFileURL, let image = UIImage(contentsOfFile: localFileURL.path) {
            return image
        }
        if let assetName = media.assetName {
            return UIImage(named: assetName)
        }
        return nil
    }

    var accessibilityText: Text {
        if let assetName = media.assetName {
            switch assetName {
            case "sample_post_rainy_city": return Text("media.rainyCity")
            case "sample_reel_pasta": return Text("media.pasta")
            case "sample_post_sketchbook": return Text("media.sketchbook")
            case "sample_post_mountain_trail": return Text("media.mountainTrail")
            case "sample_reel_studio": return Text("media.artStudio")
            case "sample_post_blue_hour": return Text("media.blueHour")
            case "sample_post_lemon_rice": return Text("media.lemonRice")
            case "sample_reel_private_weekend": return Text("media.privateWeekend")
            case "sample_reel_coffee": return Text("media.coffeeReel")
            case "sample_reel_baghdad": return Text("media.baghdadReel")
            case "sample_story_maya": return Text("media.mayaStory")
            case "sample_story_leo": return Text("media.leoStory")
            case "sample_story_samira": return Text("media.samiraStory")
            case "sample_story_zara": return Text("media.zaraStory")
            default: break
            }
        }
        return media.accessibilityDescription.isEmpty
            ? Text("home.media")
            : Text(verbatim: media.accessibilityDescription)
    }

    private var placeholderSymbol: String {
        if media.kind == .video { return "play.rectangle.fill" }
        guard let assetName = media.assetName else { return "sparkles" }
        switch assetName {
        case "sample_post_rainy_city": return "building.2.crop.circle"
        case "sample_post_sketchbook": return "paintpalette.fill"
        case "sample_post_mountain_trail": return "mountain.2.fill"
        case "sample_post_blue_hour": return "moon.stars.fill"
        case "sample_post_lemon_rice": return "fork.knife"
        default: return "sparkles"
        }
    }

    var body: some View {
        ZStack {
            if media.kind == .video, let player {
                VideoPlayer(player: player)
            } else if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [GlintPalette.accent.opacity(0.62), GlintPalette.secondaryAccent.opacity(0.45), GlintPalette.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: placeholderSymbol)
                        .font(.system(size: 42, weight: .light))
                        .foregroundStyle(.white.opacity(0.92))
                        .accessibilityHidden(true)
                }
            }

            if media.kind == .video && player == nil {
                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.black.opacity(0.34), in: Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(12)
                    .accessibilityHidden(true)
            }
        }
        .aspectRatio(media.aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityLabel(accessibilityText)
        .task(id: videoURL) {
            guard media.kind == .video, let videoURL else {
                player = nil
                return
            }
            player = AVPlayer(url: videoURL)
        }
        .onDisappear { player?.pause() }
    }
}
