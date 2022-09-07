import Foundation
import UserNotifications

class PipelineListener {

  var userSettings: UserSettings

  init(userSettings: UserSettings) {
    self.userSettings = userSettings
  }

  let un = UNUserNotificationCenter.current()

  var task: Task<Void, Error>?

  func notify(msg: PipelineEvent) {
    if(msg.status == "pending") {
      logger.log("ignoring pending status for \(msg.projectName)")
      return
    }
    if(userSettings.namespace != msg.namespace) {
      logger.log("notification for namespace \(msg.namespace) is no \(userSettings.namespace), ignoring")
      return
    }
    if(userSettings.ignore == msg.projectName) {
      logger.log("notification for project \(msg.projectName) is \(userSettings.ignore), ignoring")
      return
    }
    un.getNotificationSettings { settings in
      if settings.authorizationStatus == .authorized {
        let content = UNMutableNotificationContent()
        content.title = "Pipeline for " + msg.projectName + " " + msg.status
        content.body = "Commit: \(msg.commitMessage)"
        content.sound = UNNotificationSound.default
        content.interruptionLevel = UNNotificationInterruptionLevel.active
        content.userInfo = ["projectUrl": "\(msg.projectUrl)", "pipelineId": "\(msg.pipelineId)"]

        let id = UUID().uuidString
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        self.un.add(request) { (error) in
          if error != nil { logger.log(error?.localizedDescription ?? "u") }
        }
      }
    }
  }

  func connectionFailed(url: String) {
    let oneSecond = TimeInterval(1_000_000_000)
    let delay = UInt64(oneSecond * 1)
    Task {
      try await Task.sleep(nanoseconds: delay)
      await logger.log("Retry connect")
      start(url: url)
    }
  }

  func start(url: String) {
    logger.log("Listening to \(url)")
    task?.cancel()
    task = nil
    let stream = WebSocketStream(url: url)
    un.requestAuthorization(options: [.alert, .sound]) { authorized, error in
      if authorized {
        logger.log("Notifications authorized")
        self.task = Task.detached(priority: .userInitiated) { [weak self] in
          do {
            for try await message in stream {
              self?.notify(msg: try message.message())
            }
          } catch {
            await logger.log("Oops something didn't go right: \(error)")
          }
          self?.connectionFailed(url: url)
        }

      } else if !authorized {
        logger.log("Notifications not authorized")
      } else {
        logger.log(error?.localizedDescription ?? "Notifications request unknown error")
      }

    }

  }
}
