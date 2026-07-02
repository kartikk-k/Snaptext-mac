import AppKit
import Vision

/// Uses the built-in macOS `screencapture -i` interactive crop UI to grab a
/// region of the screen, then runs Apple's Vision OCR on the result.
final class TextCapture {
    enum Result {
        case text(String)   // recognized text, ready for the clipboard
        case empty          // capture succeeded but Vision found no text
        case cancelled      // user pressed Esc / clicked away during selection
        case failure(String)
    }

    /// Runs the interactive capture, performs OCR, and calls `completion` on the main queue.
    func captureAndRecognize(completion: @escaping (Result) -> Void) {
        captureInteractiveRegion { [weak self] image in
            guard let self else { return }
            guard let image else {
                DispatchQueue.main.async { completion(.cancelled) }
                return
            }
            self.recognizeText(in: image) { result in
                DispatchQueue.main.async { completion(result) }
            }
        }
    }

    // MARK: - Screen capture

    private func captureInteractiveRegion(completion: @escaping (CGImage?) -> Void) {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("snaptext-\(UUID().uuidString).png")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        // -i interactive, -r no shadow/decoration, -o no window shadow, -x no sound.
        process.arguments = ["-i", "-r", "-o", "-x", tmpURL.path]

        process.terminationHandler = { _ in
            defer { try? FileManager.default.removeItem(at: tmpURL) }

            // If the user cancels selection, screencapture writes no file.
            guard FileManager.default.fileExists(atPath: tmpURL.path),
                  let data = try? Data(contentsOf: tmpURL),
                  let nsImage = NSImage(data: data),
                  let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
            else {
                completion(nil)
                return
            }
            completion(cgImage)
        }

        do {
            try process.run()
        } catch {
            completion(nil)
        }
    }

    // MARK: - Vision OCR

    private func recognizeText(in image: CGImage, completion: @escaping (Result) -> Void) {
        let request = VNRecognizeTextRequest { request, error in
            if let error {
                completion(.failure(error.localizedDescription))
                return
            }
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  !observations.isEmpty else {
                completion(.empty)
                return
            }

            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            let joined = lines.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            completion(joined.isEmpty ? .empty : .text(joined))
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(.failure(error.localizedDescription))
            }
        }
    }
}
