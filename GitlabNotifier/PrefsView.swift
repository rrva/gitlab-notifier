import Foundation
import SwiftUI

@available(macOS 12.0, *)
struct PrefsView: View {
  @ObservedObject var userSettings: UserSettings
  private var logger: Logger
  init(logger: Logger, userSettings: UserSettings) {
    self.logger = logger
    self.userSettings = userSettings
  }

  func getUserSettings() -> UserSettings {
    userSettings
  }

  var shouldShowPrompt: Bool {
    userSettings.backendURL == ""
  }

  var body: some View {
    VStack {
      Text("Configure these settings").padding()
      Form {
        TextField(text: $userSettings.backendURL, prompt: Text("Notifier service URL")) {
          Text("Backend URL")
        }.textFieldStyle(.roundedBorder)
        TextField(text: $userSettings.namespace, prompt: Text("Namespace")) {
          Text("Namespace")
        }.textFieldStyle(.roundedBorder)
        TextField(text: $userSettings.ignore, prompt: Text("Ignore")) {
          Text("Ignore")
        }.textFieldStyle(.roundedBorder)
        Spacer().frame(idealHeight: 0)
      }
    }.frame(minWidth: 120, maxWidth: .infinity, minHeight: 150, maxHeight: 150).padding(24)

  }
}

class UserSettings: ObservableObject {
  @Published var backendURL: String {
    didSet {
      UserDefaults.standard.set(backendURL, forKey: "backendURL")
    }
  }
  @Published var namespace: String {
    didSet {
      UserDefaults.standard.set(namespace, forKey: "namespace")
    }
  }
  @Published var ignore: String {
    didSet {
      UserDefaults.standard.set(ignore, forKey: "ignore")
    }
  }

  init() {
    backendURL =
      UserDefaults.standard.object(forKey: "backendURL") as? String
      ?? ""
    namespace =
    UserDefaults.standard.object(forKey: "namespace") as? String
      ?? "videocollab"
    ignore = UserDefaults.standard.object(forKey: "ignore") as? String
    ?? "Junk"

  }
}
