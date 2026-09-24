import Cocoa
import FlutterMacOS
import window_ext
import LaunchAtLogin
import CryptoKit

@main
class AppDelegate: FlutterAppDelegate {
    var statusBarController: StatusBarController?
    
    var flutterUIPopover = NSPopover.init()
    
    override init() {
        super.init()

        // SIGPIPE hardening (field incident: exit 141). When the DropwebCore
        // helper dies — e.g. `bad CPU type in executable` from a poisoned
        // Application Support core — the main app's next write to the now-dead
        // helper socket raises SIGPIPE, whose default disposition kills the
        // process instantly (128 + 13 = 141). The tray icon flashes for one
        // frame and the app vanishes with no error. Ignoring SIGPIPE turns that
        // write into a normal EPIPE error the socket code can surface/handle,
        // instead of a silent kill. Set here (earliest entry) so no early write
        // can race it. Darwin's signal()/SIG_IGN come in via Cocoa.
        signal(SIGPIPE, SIG_IGN)

        flutterUIPopover.behavior = NSPopover.Behavior.transient
    }
    
    override func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSLog("AppDelegate: applicationDidFinishLaunching called")
        
        setupCoreInApplicationSupport()
        
        
        guard let mainController = mainFlutterWindow?.contentViewController as? FlutterViewController else {
            NSLog("ERROR: Could not get FlutterViewController from mainFlutterWindow")
            return
        }
        
        
        let popoverContainer = PopoverContainerViewController(flutterViewController: mainController)
        
        flutterUIPopover.contentSize = NSSize(width: 375, height: 600)
        
        flutterUIPopover.contentViewController = popoverContainer
        
        statusBarController = StatusBarController.init(flutterUIPopover)
        
        setupStatusBarChannel(flutterViewController: mainController)
        
        super.applicationDidFinishLaunching(aNotification)
        
        mainFlutterWindow?.close()

        // Status-bar app: there is no window, so after launch/install the UI
        // stays invisible until the user clicks the menu-bar icon — the
        // recurring "app doesn't open after install" complaint. Open the
        // popover once, on launch. Deferred a beat so NSApp.activate + the show
        // land AFTER the launch settles; a transient popover shown too early
        // gets auto-dismissed the moment focus settles (why the Dart-side
        // StatusBarManager.showWindow() call alone didn't stick).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self = self, let controller = self.statusBarController else { return }
            NSApp.activate(ignoringOtherApps: true)
            if !self.flutterUIPopover.isShown {
                controller.showPopover(self)
            }
        }
    }
    
    func setupStatusBarChannel(flutterViewController: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: "status_bar_icon",
            binaryMessenger: flutterViewController.engine.binaryMessenger
        )
        
        channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "updateIcon":
                if let args = call.arguments as? [String: Any],
                   let isConnected = args["isConnected"] as? Bool {
                    self?.statusBarController?.updateIcon(isVpnConnected: isConnected)
                    result(true)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                }
            case "showWindow":
                // Bring the status-bar popover to the foreground (e.g. on a
                // deep-link import) so an in-app dialog is actually visible.
                NSApp.activate(ignoringOtherApps: true)
                if let strongSelf = self, !strongSelf.flutterUIPopover.isShown {
                    strongSelf.statusBarController?.showPopover(strongSelf)
                }
                result(true)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        NSLog("StatusBar channel set up successfully")
    }
    
    func setupCoreInApplicationSupport() {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("ERROR: Could not get Application Support directory")
            return
        }
        
        let bundleURL = Bundle.main.bundleURL
        let bundleCorePath = bundleURL.appendingPathComponent("Contents/MacOS/DropwebCore")
        let appSupportCorePath = appSupportURL.appendingPathComponent("app.dropweb/cores/DropwebCore")
        let appSupportDir = appSupportCorePath.deletingLastPathComponent()
        
        do {
            try FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
            print("Directory created: \(appSupportDir.path)")
            
            let coreExists = FileManager.default.fileExists(atPath: appSupportCorePath.path)
            let needsUpdate = !coreExists || coreContentDiffers(bundlePath: bundleCorePath.path, appSupportPath: appSupportCorePath.path)
            
            if needsUpdate {
                try? FileManager.default.removeItem(at: appSupportCorePath)
                
                try FileManager.default.copyItem(at: bundleCorePath, to: appSupportCorePath)
                
                if setCorePermissions(corePath: appSupportCorePath.path) {
                    print("Core binary updated to: \(appSupportCorePath.path)")
                }
            } else {
                let attrs = try? FileManager.default.attributesOfItem(atPath: appSupportCorePath.path)
                if let posixPerms = attrs?[.posixPermissions] as? NSNumber {
                    // Check if setuid bit is set (04000 in octal)
                    if (posixPerms.uint16Value & 0o4000) == 0 {
                        print("Permissions not set, setting them now...")
                        let _ = setCorePermissions(corePath: appSupportCorePath.path)
                    } else {
                        print("Core binary already up-to-date with correct permissions")
                    }
                }
            }
        } catch {
            print("Failed to setup core: \(error)")
        }
    }
    
    func setCorePermissions(corePath: String) -> Bool {
        let script = """
        do shell script "chown root:admin '\(corePath)' && chmod +sx '\(corePath)'" with administrator privileges
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                if let errorCode = error["NSAppleScriptErrorNumber"] as? Int, errorCode == -128 {
                    print("User cancelled password prompt")
                    showPermissionRequiredAlert()
                    NSApplication.shared.terminate(nil)
                    return false
                }
                print("Failed to set permissions: \(error)")
                return false
            } else {
                print("Permissions set successfully for: \(corePath)")
                return true
            }
        }
        return false
    }
    
    func showPermissionRequiredAlert() {
        let alert = NSAlert()
        alert.messageText = "Administrator Access Required"
        alert.informativeText = "dropweb requires administrator privileges to set up the network core. The application cannot run without these permissions.\n\nPlease restart the application and grant administrator access when prompted."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Quit")
        alert.runModal()
    }
    
    // Decide whether the Application Support core must be replaced by the
    // bundle's, by CONTENT identity (SHA-256) rather than mtime. The old
    // mtime heuristic (bundleDate > appSupportDate) is why a wrong-arch core
    // poisoned into Application Support survived every later correct install:
    // a freshly installed bundle core is not "newer" than the already-copied
    // one, so it was never re-copied, and the app kept launching an arm64-only
    // core on an Intel Mac (`bad CPU type`). Content comparison replaces the
    // core whenever the bytes differ — covering wrong-arch AND version bumps —
    // so a poisoned/stale core self-heals on the next launch (the admin prompt
    // re-appears, which is correct: the binary genuinely changed). Fast path:
    // a size mismatch means differ without hashing; equal sizes fall through to
    // the SHA-256 compare (~30-50MB read at launch, acceptable). On any read
    // failure we return true (update) — fail toward a known-good bundle core.
    func coreContentDiffers(bundlePath: String, appSupportPath: String) -> Bool {
        let fm = FileManager.default
        if let bundleSize = (try? fm.attributesOfItem(atPath: bundlePath))?[.size] as? Int,
           let appSupportSize = (try? fm.attributesOfItem(atPath: appSupportPath))?[.size] as? Int,
           bundleSize != appSupportSize {
            return true
        }
        guard let bundleData = try? Data(contentsOf: URL(fileURLWithPath: bundlePath)),
              let appSupportData = try? Data(contentsOf: URL(fileURLWithPath: appSupportPath)) else {
            return true
        }
        return SHA256.hash(data: bundleData) != SHA256.hash(data: appSupportData)
    }
    
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Dart's handleExit restores DNS / the system proxy, stops the core and
        // then exits the process itself. Defer instead of cancel: returning
        // .terminateCancel made dropweb abort every logout, restart and
        // shutdown. Flutter's platform runner is scheduled in the common run
        // loop modes, so the channel keeps working while AppKit waits. The
        // fallback reply lets the session continue if the Dart side is wedged
        // (its own watchdog exits after 5 s).
        WindowExtPlugin.instance?.handleShouldTerminate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
      return true
    }
    
    override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag, let controller = statusBarController {
            if !flutterUIPopover.isShown {
                controller.showPopover(self)
            }
        }
        return true
    }
}
