import AppKit
import AVFoundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 450),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered, defer: false)
    private let view = CameraView()
    private let camera = Camera()
    private var recognizer = GestureRecognizer()
    private var pinchBase: Int?        // the volume when the current pinch began
    private var volume: Int?
    private var savedUntil = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Hand Track", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let menuBar = NSMenu()
        menuBar.addItem(NSMenuItem())
        menuBar.items[0].submenu = appMenu
        NSApp.mainMenu = menuBar

        window.title = "Hand Track"
        window.contentView = view
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()

        camera.onFrame = { [weak self] image, hand in self?.show(image, hand) }
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    do { try self.camera.start() } catch { self.view.status = "Couldn't start the camera: \(error.localizedDescription)" }
                } else {
                    self.view.status = "Camera access is off: turn it on in System Settings › Privacy & Security › Camera"
                }
                self.view.needsDisplay = true
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func show(_ image: CGImage, _ hand: Hand?) {
        let (gesture, shoot) = recognizer.update(hand, frameHeight: Double(image.height), time: CACurrentMediaTime())

        if case .pinch(let dy) = gesture {
            if pinchBase == nil {
                pinchBase = SystemVolume.get()
                volume = pinchBase
            }
            if let base = pinchBase {
                // Moving the hand half the picture's height sweeps the whole range.
                let newVolume = max(0, min(100, base + Int((dy * 200).rounded())))
                if newVolume != volume {
                    SystemVolume.set(newVolume)
                    volume = newVolume
                }
            }
        } else {
            pinchBase = nil
        }
        if shoot { takeScreenshot() }

        view.image = image
        view.hand = hand
        view.gesture = gesture
        view.volume = volume
        view.status = switch gesture {
        case _ where Date.now < savedUntil: "Screenshot saved to your Desktop"
        case .pinch: volume.map { "Volume \($0)%" } ?? "This sound output has no volume control"
        case .fist: "Keep holding the fist for a screenshot"
        case .none where hand == nil: "Show your hand to the camera"
        case .none: "Pinch and move up or down for volume · Hold a fist for a screenshot"
        }
        view.needsDisplay = true
    }

    /// Saves a full-screen screenshot to the Desktop, hiding this window so the camera picture isn't in it.
    private func takeScreenshot() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        let file = desktop.appending(path: "Screenshot \(formatter.string(from: .now)).png")

        window.alphaValue = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let capture = Process()
            capture.executableURL = URL(filePath: "/usr/sbin/screencapture")
            capture.arguments = [file.path]
            capture.terminationHandler = { process in
                DispatchQueue.main.async {
                    self.window.alphaValue = 1
                    if process.terminationStatus == 0 { self.savedUntil = .now + 2 }
                }
            }
            do { try capture.run() } catch { self.window.alphaValue = 1 }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
