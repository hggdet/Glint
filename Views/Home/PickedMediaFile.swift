import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct PickedMediaFile: Transferable, Sendable {
    let fileURL: URL
    let kind: PostMediaKind

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            try importFile(received.file, kind: .photo)
        }
        FileRepresentation(importedContentType: .movie) { received in
            try importFile(received.file, kind: .video)
        }
    }

    private static func importFile(_ sourceURL: URL, kind: PostMediaKind) throws -> PickedMediaFile {
        let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        guard let byteCount = (attributes[.size] as? NSNumber)?.intValue else {
            throw MediaImportError.fileSizeUnavailable
        }
        guard byteCount <= 50 * 1_024 * 1_024 else { throw MediaImportError.fileTooLarge }

        let ext = sourceURL.pathExtension.isEmpty ? (kind == .video ? "mov" : "jpg") : sourceURL.pathExtension
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("glint-import-\(UUID().uuidString)")
            .appendingPathExtension(ext)
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return PickedMediaFile(fileURL: destination, kind: kind)
    }
}

enum MediaImportError: Error {
    case fileTooLarge
    case fileSizeUnavailable
}
