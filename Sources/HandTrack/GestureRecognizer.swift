import CoreGraphics
import Vision

typealias Joint = VNHumanHandPoseObservation.JointName

/// A detected hand: joint positions in pixels, mirrored like the on-screen view, origin bottom-left.
typealias Hand = [Joint: CGPoint]

enum Gesture: Equatable {
    case none
    /// Thumb and index touching. `dy` is how far the hand has moved since the pinch settled,
    /// in frame heights (up is positive).
    case pinch(dy: Double)
    /// A closed fist; `progress` runs 0...1 over the hold that takes a screenshot.
    case fist(progress: Double)
}

/// Turns a stream of hands into gestures. Pure logic, no camera or UI, so it can be tested.
struct GestureRecognizer {
    static let pinchOn = 0.3       // thumb–index gap, as a fraction of palm length, that starts a pinch
    static let pinchOff = 0.45     // ...and the wider gap that ends it, so it doesn't flicker
    static let pinchSettle = 0.2   // seconds a pinch is held before it moves the volume
    static let fistHold = 1.0      // seconds a fist is held to take a screenshot
    static let fistGrace = 0.25    // seconds the fist can drop out (tracking blips) before the hold resets

    private var pinchStart: (time: Double, y: Double)?
    private var fistStart: Double?
    private var lastFist = -Double.infinity
    private var fired = false

    /// Feeds one camera frame. `shoot` is true on the single frame a screenshot should be taken.
    mutating func update(_ hand: Hand?, frameHeight: Double, time: Double) -> (gesture: Gesture, shoot: Bool) {
        if time - lastFist > Self.fistGrace {
            fistStart = nil
            fired = false
        }
        guard let hand, let wrist = hand[.wrist], let indexMCP = hand[.indexMCP],
              let middleMCP = hand[.middleMCP], let littleMCP = hand[.littleMCP] else {
            pinchStart = nil
            return (.none, false)
        }

        if isFist(hand, wrist: wrist) {
            pinchStart = nil
            lastFist = time
            let start = fistStart ?? time
            fistStart = start
            let progress = min((time - start) / Self.fistHold, 1)
            let shoot = progress >= 1 && !fired
            if shoot { fired = true }
            return (.fist(progress: progress), shoot)
        }

        let palm = distance(wrist, middleMCP)
        guard palm > 0, let thumb = hand[.thumbTip], let index = hand[.indexTip],
              distance(thumb, index) / palm < (pinchStart == nil ? Self.pinchOn : Self.pinchOff) else {
            pinchStart = nil
            return (.none, false)
        }

        // Follow the palm, not the fingertips: it stays put while the fingers move.
        let y = (wrist.y + indexMCP.y + littleMCP.y) / 3 / frameHeight
        var start = pinchStart ?? (time, y)
        if time - start.time < Self.pinchSettle { start.y = y }
        pinchStart = start
        return (.pinch(dy: y - start.y), false)
    }

    /// All four fingertips are folded back to no farther from the wrist than their knuckles.
    private func isFist(_ hand: Hand, wrist: CGPoint) -> Bool {
        let fingers: [(tip: Joint, knuckle: Joint)] = [
            (.indexTip, .indexMCP), (.middleTip, .middleMCP), (.ringTip, .ringMCP), (.littleTip, .littleMCP),
        ]
        return fingers.allSatisfy { finger in
            guard let tip = hand[finger.tip], let knuckle = hand[finger.knuckle] else { return false }
            return distance(tip, wrist) < distance(knuckle, wrist) * 1.15
        }
    }
}

func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
    hypot(a.x - b.x, a.y - b.y)
}
