import SwiftUI
import UniformTypeIdentifiers

private struct ShareableReelMovie: Transferable, Sendable {
    let sourceURL: URL
    let reelID: UUID

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .mpeg4Movie) { movie in
            let shareDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("GlintSharedReels", isDirectory: true)
            try FileManager.default.createDirectory(at: shareDirectory, withIntermediateDirectories: true)

            let destinationURL = shareDirectory
                .appendingPathComponent("reel-\(movie.reelID.uuidString).mp4")
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: movie.sourceURL, to: destinationURL)
            return SentTransferredFile(destinationURL)
        }
    }
}

private enum ReelShareItem {
    case movie(ShareableReelMovie)
    case link(URL)
}

struct ReelShareSheet: View {
    let reel: GlintPost
    @Environment(\.dismiss) private var dismiss

    private var shareItem: ReelShareItem? {
        guard let media = reel.media.first(where: { $0.kind == .video }) else { return nil }

        if let remoteURL = media.remoteURL,
           remoteURL.scheme?.lowercased() == "https" {
            return .link(remoteURL)
        }

        let localURL = media.localFileURL
            ?? media.assetName.flatMap { assetName in
                Bundle.main.url(forResource: assetName, withExtension: "mp4", subdirectory: "Media")
                    ?? Bundle.main.url(forResource: assetName, withExtension: "mp4", subdirectory: "Resources/Media")
                    ?? Bundle.main.url(forResource: assetName, withExtension: "mp4")
            }
        guard let localURL else { return nil }
        return .movie(ShareableReelMovie(sourceURL: localURL, reelID: reel.id))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "paperplane")
                    .font(.system(size: 34))
                    .foregroundStyle(GlintPalette.accent)
                Text("share.reel.title")
                    .font(.headline)

                switch shareItem {
                case .movie(let movie):
                    ShareLink(item: movie) {
                        Label("share.reel.button", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.horizontal)
                case .link(let url):
                    ShareLink(item: url) {
                        Label("share.reel.button", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.horizontal)
                case nil where !reel.caption.isEmpty:
                    Text("share.reel.captionOnly")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    ShareLink(item: reel.caption) {
                        Label("share.reel.button", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.horizontal)
                case nil:
                    Text("share.reel.unavailable")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.top, 28)
            .navigationTitle("share.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
