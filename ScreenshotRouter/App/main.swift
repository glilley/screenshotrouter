import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // must happen before run loop starts
let delegate = AppDelegate()
app.delegate = delegate
print("[SR] Starting run loop")
app.run()
