import Foundation

struct ScreenshotCapture {

    /// Launches `screencapture -i` interactively and returns the saved file URL,
    /// or `nil` if the user cancelled (pressed Escape).
    ///
    /// Blocks the calling thread until the user completes or cancels selection.
    /// Always call this from a background thread.
    static func capture() -> URL? {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let path = "/tmp/screenshotrouter_\(timestamp).png"

        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        // -i = interactive (crosshair + window click), writes to path
        task.arguments = ["-i", path]

        do {
            try task.run()
        } catch {
            print("ScreenshotCapture: failed to launch screencapture: \(error)")
            return nil
        }
        task.waitUntilExit()

        // screencapture exits 0 even on Esc; detect cancel via file absence
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: path) ? url : nil
    }
}
