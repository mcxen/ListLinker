import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var videoCommandChannel: FlutterMethodChannel?
  private var captureShortcutEnabled = false

  override func awakeFromNib() {
    minSize = NSSize(width: 860, height: 560)
    setContentSize(NSSize(width: 1100, height: 700))
    title = "ListLinker"
    titleVisibility = .visible
    titlebarAppearsTransparent = false
    toolbarStyle = .unified

    let flutterViewController = FlutterViewController.init()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "com.github.listlinker.client/video_commands",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    videoCommandChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "setCaptureShortcutEnabled":
        self?.captureShortcutEnabled = call.arguments as? Bool ?? false
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    let shortcutModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
    let activeModifiers = event.modifierFlags.intersection(shortcutModifiers)
    if captureShortcutEnabled,
       event.type == .keyDown,
       activeModifiers == .command,
       event.charactersIgnoringModifiers?.lowercased() == "e" {
      videoCommandChannel?.invokeMethod("captureCurrentFrame", arguments: nil)
      return true
    }
    return super.performKeyEquivalent(with: event)
  }
}
