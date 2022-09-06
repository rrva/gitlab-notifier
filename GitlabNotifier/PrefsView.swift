import Foundation
import SwiftUI

@available(macOS 12.0, *)
struct PrefsView: View {
  @ObservedObject var userSettings = UserSettings()
  private let pipelineListener: PipelineListener
  private var logger: Logger
  init(logger: Logger, pipelineListener: PipelineListener) {
    self.logger = logger
    self.pipelineListener = pipelineListener
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

  init() {
    let backendURLStr =
      UserDefaults.standard.object(forKey: "backendURL") as? String
      ?? "wss://pipeline-notifier.foo.example.com/events"
    backendURL = backendURLStr
  }
}
