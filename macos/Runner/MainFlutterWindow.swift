import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Size the window for the three-pane layout and prevent it shrinking below
    // a usable size.
    self.minSize = NSSize(width: 900, height: 600)
    let defaultSize = NSSize(width: 1180, height: 760)
    if let screen = self.screen ?? NSScreen.main {
      let visible = screen.visibleFrame
      let originX = visible.midX - defaultSize.width / 2
      let originY = visible.midY - defaultSize.height / 2
      self.setFrame(
        NSRect(x: originX, y: originY, width: defaultSize.width, height: defaultSize.height),
        display: true)
    } else {
      self.setContentSize(defaultSize)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
