import CoreGraphics
import Testing
@testable import HandTrack

private enum Pose { case open, pinch, fist }

/// A hand with fingers pointing up, wrist at the origin, palm about 9 units long, raised by `lift`.
private func hand(_ pose: Pose, lift: Double = 0) -> Hand {
    var hand: Hand = [.wrist: CGPoint(x: 0, y: 0), .thumbCMC: CGPoint(x: -2, y: 2), .thumbMP: CGPoint(x: -4, y: 4),
                      .thumbIP: CGPoint(x: -6, y: 6), .thumbTip: CGPoint(x: -7, y: 8)]
    let fingers: [(x: Double, joints: [Joint])] = [
        (-3, [.indexMCP, .indexPIP, .indexDIP, .indexTip]),
        (-1, [.middleMCP, .middlePIP, .middleDIP, .middleTip]),
        (1, [.ringMCP, .ringPIP, .ringDIP, .ringTip]),
        (3, [.littleMCP, .littlePIP, .littleDIP, .littleTip]),
    ]
    let heights = pose == .fist ? [9, 10, 8.5, 7] : [9, 13, 15.5, 17.5]
    for finger in fingers {
        for (joint, y) in zip(finger.joints, heights) { hand[joint] = CGPoint(x: finger.x, y: y) }
    }
    switch pose {
    case .open: break
    case .pinch:  // index bends over to meet the thumb, the other fingers stay up (an "OK" sign)
        hand[.indexPIP] = CGPoint(x: -4, y: 12)
        hand[.indexDIP] = CGPoint(x: -5, y: 13)
        hand[.indexTip] = CGPoint(x: -6, y: 12)
        hand[.thumbTip] = CGPoint(x: -6, y: 12)
    case .fist:  // thumb wraps across the curled fingers, close to the index tip
        hand[.thumbTip] = CGPoint(x: -2.5, y: 7.5)
    }
    return hand.mapValues { CGPoint(x: $0.x, y: $0.y + lift) }
}

private func dy(_ gesture: Gesture) -> Double? {
    if case .pinch(let dy) = gesture { dy } else { nil }
}

@Test func openHandIsNoGesture() {
    var recognizer = GestureRecognizer()
    #expect(recognizer.update(hand(.open), frameHeight: 100, time: 0).gesture == .none)
    #expect(recognizer.update(nil, frameHeight: 100, time: 0.1).gesture == .none)
}

@Test func pinchFollowsTheHandOnlyAfterSettling() throws {
    var recognizer = GestureRecognizer()
    #expect(recognizer.update(hand(.pinch), frameHeight: 100, time: 0).gesture == .pinch(dy: 0))
    // Movement while the pinch settles doesn't count...
    #expect(recognizer.update(hand(.pinch, lift: 5), frameHeight: 100, time: 0.1).gesture == .pinch(dy: 0))
    #expect(recognizer.update(hand(.pinch, lift: 5), frameHeight: 100, time: 0.3).gesture == .pinch(dy: 0))
    // ...movement after it does: 10 units up in a 100-unit frame.
    let moved = try #require(dy(recognizer.update(hand(.pinch, lift: 15), frameHeight: 100, time: 0.4).gesture))
    #expect(abs(moved - 0.1) < 1e-9)
}

@Test func holdingAFistTakesOneScreenshotAfterASecond() {
    var recognizer = GestureRecognizer()
    var shots: [Double] = []
    for t in stride(from: 0.0, through: 3.0, by: 1.0 / 30) {
        let (gesture, shoot) = recognizer.update(hand(.fist), frameHeight: 100, time: t)
        #expect(dy(gesture) == nil, "a fist must never read as a pinch")
        if shoot { shots.append(t) }
    }
    #expect(shots.count == 1)
    #expect(shots.allSatisfy { $0 >= 1 && $0 < 1.1 })
}

@Test func openingAndClosingTheFistAgainTakesAnother() {
    var recognizer = GestureRecognizer()
    var shots = 0
    for t in stride(from: 0.0, through: 3.5, by: 1.0 / 30) {
        let pose: Pose = (1.5..<2.0).contains(t) ? .open : .fist
        if recognizer.update(hand(pose), frameHeight: 100, time: t).shoot { shots += 1 }
    }
    #expect(shots == 2)
}

@Test func aTrackingBlipDoesNotRestartTheHold() {
    var recognizer = GestureRecognizer()
    var shotAt: Double?
    for t in stride(from: 0.0, through: 1.5, by: 1.0 / 30) {
        let lost = (0.5..<0.6).contains(t)
        if recognizer.update(lost ? nil : hand(.fist), frameHeight: 100, time: t).shoot { shotAt = t }
    }
    #expect(shotAt.map { $0 < 1.1 } == true)
}
