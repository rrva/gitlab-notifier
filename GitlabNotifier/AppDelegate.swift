import Cocoa
import Foundation
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {

  private var statusItem: NSStatusItem!
  var aboutWindowController: NSWindowController!
  var prefsWindowController: NSWindowController!
  var logWindowController: NSWindowController!
  let pipelineListener = PipelineListener()

  lazy var prefsView = PrefsView(logger: logger, pipelineListener: pipelineListener)

  let un = UNUserNotificationCenter.current()

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    setupMenus()

    un.delegate = self

    if(prefsView.userSettings.backendURL == "") {
      didTapPrefs()
    } else {
      pipelineListener.start(url: prefsView.userSettings.backendURL)
    }



  }





  func setupMenus() {
    let menu = NSMenu()
    menu.autoenablesItems = false

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    if let button = statusItem.button {
      button.image = NSImage(
        systemSymbolName: "ivfluid.bag", accessibilityDescription: "0")
    }

    let logsMenuItem = NSMenuItem(title: "Logs", action: #selector(didTapLogs), keyEquivalent: "l")
    menu.addItem(logsMenuItem)

    let prefsMenuItem = NSMenuItem(
      title: "Preferences", action: #selector(didTapPrefs), keyEquivalent: "p")
    menu.addItem(prefsMenuItem)

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

  @objc func didTapLogs() {
    if logWindowController == nil {
      logWindowController = WindowController(
        hostedView: LogView(logs: logger.logs), resizable: true)
    }
    logWindowController.showWindow(nil)
    logWindowController.window?.center()

    NSApp.activate(ignoringOtherApps: true)
    logWindowController.window?.makeKeyAndOrderFront(nil)
  }

  @objc func didTapPrefs() {
    if prefsWindowController == nil {
      prefsWindowController = WindowController(hostedView: prefsView, onClose: { [weak self] in
        guard let self = self else { return }
        self.pipelineListener.start(url: self.prefsView.userSettings.backendURL)
      })
    }
    prefsWindowController.showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)
    self.prefsWindowController.window?.center()
    self.prefsWindowController.window?.makeKeyAndOrderFront(nil)
  }

  func applicationWillTerminate(_ aNotification: Notification) {

  }

  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }


}


extension AppDelegate: UNUserNotificationCenterDelegate {
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.list, .sound])
  }
}

let aboutViewVisibility = AboutViewVisibility(showLicense: false)
let about = About()
let logger = Logger()
