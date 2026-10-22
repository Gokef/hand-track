import AppKit
import AVFoundation

/// Shows the camera picture with the tracked hand, the gesture's feedback and a status line.
final class CameraView: NSView {
    var image: CGImage?
    var hand: Hand?
    var gesture = Gesture.none
    var volume: Int?
    var status = "Starting the camera…"

    private static let fingers: [[Joint]] = [
        [.wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip],
        [.wrist, .indexMCP, .indexPIP, .indexDIP, .indexTip],
        [.wrist, .middleMCP, .middlePIP, .middleDIP, .middleTip],
        [.wrist, .ringMCP, .ringPIP, .ringDIP, .ringTip],
        [.wrist, .littleMCP, .littlePIP, .littleDIP, .littleTip],
    ]

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        bounds.fill()

        if let image, let context = NSGraphicsContext.current?.cgContext {
            let size = CGSize(width: image.width, height: image.height)
            let frame = AVMakeRect(aspectRatio: size, insideRect: bounds)
            context.draw(image, in: frame)
            if let hand {
                // Joint positions are in image pixels; scale them onto the drawn picture.
                let place = { (p: CGPoint) in
                    CGPoint(x: frame.minX + p.x / size.width * frame.width, y: frame.minY + p.y / size.height * frame.height)
                }
                drawHand(hand, place: place)
            }
            if case .pinch = gesture, let volume { drawVolumeBar(volume, in: frame) }
        }
        drawStatus()
    }

    private func drawHand(_ hand: Hand, place: (CGPoint) -> CGPoint) {
        let color: NSColor = switch gesture {
        case .none: .white
        case .pinch: .systemGreen
        case .fist: .systemOrange
        }
        color.set()
        for finger in Self.fingers {
            let points = finger.compactMap { hand[$0].map(place) }
            let line = NSBezierPath()
            line.lineWidth = 3
            for (i, point) in points.enumerated() {
                if i == 0 { line.move(to: point) } else { line.line(to: point) }
            }
            line.stroke()
            for point in points {
                NSBezierPath(ovalIn: NSRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)).fill()
            }
        }

        // A ring around the palm that fills up while a fist is held.
        if case .fist(let progress) = gesture,
           let wrist = hand[.wrist], let index = hand[.indexMCP], let little = hand[.littleMCP] {
            let palm = place(CGPoint(x: (wrist.x + index.x + little.x) / 3, y: (wrist.y + index.y + little.y) / 3))
            let ring = NSBezierPath()
            ring.lineWidth = 8
            ring.appendArc(withCenter: palm, radius: 50, startAngle: 90, endAngle: 90 - 360 * progress, clockwise: true)
            ring.stroke()
        }
    }

    private func drawVolumeBar(_ volume: Int, in frame: NSRect) {
        let track = NSRect(x: frame.maxX - 40, y: frame.minY + 60, width: 16, height: frame.height - 120)
        NSColor.black.withAlphaComponent(0.5).setFill()
        NSBezierPath(roundedRect: track, xRadius: 8, yRadius: 8).fill()
        var level = track
        level.size.height = track.height * CGFloat(volume) / 100
        NSColor.systemGreen.setFill()
        NSBezierPath(roundedRect: level, xRadius: 8, yRadius: 8).fill()
    }

    private func drawStatus() {
        let text = NSAttributedString(string: status, attributes: [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: NSColor.white,
        ])
        let size = text.size()
        let pill = NSRect(x: bounds.midX - size.width / 2 - 14, y: 16, width: size.width + 28, height: size.height + 12)
        NSColor.black.withAlphaComponent(0.6).setFill()
        NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()
        text.draw(at: NSPoint(x: pill.minX + 14, y: pill.minY + 6))
    }
}
