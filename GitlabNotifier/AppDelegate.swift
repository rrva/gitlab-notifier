import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

  private var statusItem: NSStatusItem!
  var aboutWindowController: NSWindowController!

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    setupMenus()
  }

  func setupMenus() {
    let menu = NSMenu()
    menu.autoenablesItems = false

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    if let button = statusItem.button {
      button.image = NSImage(
        systemSymbolName: "ivfluid.bag", accessibilityDescription: "0")
    }

    let aboutMenuItem = NSMenuItem(
      title: "About", action: #selector(didTapAbout), keyEquivalent: "a")
    menu.addItem(aboutMenuItem)


    menu.addItem(
      NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

    statusItem.menu = menu
  }

  @objc func didTapAbout() {
    aboutViewVisibility.showLicense = false
    if aboutWindowController == nil {
      aboutWindowController = WindowController(
        hostedView: AboutView().environmentObject(aboutViewVisibility))
    }
    aboutWindowController.showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)
    self.aboutWindowController.window?.center()
    self.aboutWindowController.window?.makeKeyAndOrderFront(nil)
  }

  func applicationWillTerminate(_ aNotification: Notification) {

  }

  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }


}

let aboutViewVisibility = AboutViewVisibility(showLicense: false)
let about = About()
