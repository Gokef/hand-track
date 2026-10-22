import AVFoundation
import CoreImage
import Vision

/// Runs the camera and finds a hand in each frame.
final class Camera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    /// Called on the main thread with each mirrored frame and the hand in it, if any.
    var onFrame: ((CGImage, Hand?) -> Void)?

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "camera")
    private let ciContext = CIContext()
    private let request: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        return request
    }()

    func start() throws {
        guard let device = AVCaptureDevice.default(for: .video) else {
            throw NSError(domain: "HandTrack", code: 1, userInfo: [NSLocalizedDescriptionKey: "No camera found."])
        }
        let input = try AVCaptureDeviceInput(device: device)
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)

        session.beginConfiguration()
        if session.canSetSessionPreset(.hd1280x720) { session.sessionPreset = .hd1280x720 }
        session.addInput(input)
        session.addOutput(output)
        session.commitConfiguration()
        queue.async { self.session.startRunning() }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let width = Double(CVPixelBufferGetWidth(pixels))
        let height = Double(CVPixelBufferGetHeight(pixels))

        try? VNImageRequestHandler(cvPixelBuffer: pixels, orientation: .up).perform([request])
        let hand: Hand? = request.results?.first.flatMap { observation in
            guard let points = try? observation.recognizedPoints(.all) else { return nil }
            var hand = Hand()
            for (joint, point) in points where point.confidence > 0.3 {
                // Mirror x so the hand lines up with the mirrored picture.
                hand[joint] = CGPoint(x: (1 - point.location.x) * width, y: point.location.y * height)
            }
            return hand
        }

        let mirrored = CIImage(cvPixelBuffer: pixels).oriented(.upMirrored)
        guard let image = ciContext.createCGImage(mirrored, from: mirrored.extent) else { return }
        DispatchQueue.main.async { self.onFrame?(image, hand) }
    }
}
