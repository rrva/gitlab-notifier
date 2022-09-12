import AppKit
import Foundation
import UserNotifications

class PipelineListener {

  var userSettings: UserSettings
  var statusItem: NSStatusItem
  var pipelineStatuses: [String: PipelineStatus]
  var animationRunning: Bool
  var currentEpoch: Int
  var replayUntilSeq: Int

  init(userSettings: UserSettings, statusItem: NSStatusItem) {
    self.userSettings = userSettings
    self.statusItem = statusItem
    self.pipelineStatuses = [:]
    self.animationRunning = false
    self.currentEpoch = 0
    self.replayUntilSeq = 0
  }

  let un = UNUserNotificationCenter.current()

  var task: Task<Void, Error>?

  func animateStatusBar() {
    let imageView = statusItem.button

    if let layer = imageView?.layer {
      let animation = CABasicAnimation(keyPath: "opacity")
      animation.fromValue = 1.0
      animation.toValue = 0.3
      animation.duration = 2.0
      animation.repeatCount = Float.infinity
      animation.autoreverses = true
      animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)
      CATransaction.begin()
      layer.add(animation, forKey: "fade")
      CATransaction.commit()
    }
  }

  private func stopAnimation() {
    if let view = statusItem.button {
      view.subviews.forEach { $0.layer!.removeAllAnimations() }
      view.layer!.removeAllAnimations()
    }
  }

  func notify(event: WebsocketEvent) {
    if event.msg == nil {
      logger.log("Connected. Replay of old messages until seq \(event.seq)")
      self.replayUntilSeq = event.seq
      return
    }
    if let msg = event.msg {
      pipelineStatuses[msg.projectName] = PipelineStatus(
        status: msg.status, timeStamp: event.timestamp)
    }
    logger.log("statuses: \(pipelineStatuses)")
    if event.seq <= self.replayUntilSeq {
      logger.log("not notifying for old message. seq: \(event.seq)")
      return
    }
    guard let msg = event.msg else {
      return
    }
    if msg.status == "pending" {
      logger.log("ignoring pending status for \(msg.projectName)")
      return
    }
    if userSettings.namespace != msg.namespace {
      logger.log(
        "notification for namespace \(msg.namespace) is no \(userSettings.namespace), ignoring")
      return
    }
    if userSettings.ignore == msg.projectName {
      logger.log("notification for project \(msg.projectName) is \(userSettings.ignore), ignoring")
      return
    }

    if pipelinesStillRunning() {
      if !animationRunning {
        DispatchQueue.main.async { self.animateStatusBar() }
        animationRunning = true
      }
    } else {
      DispatchQueue.main.async { self.stopAnimation() }
      animationRunning = false
    }
    un.getNotificationSettings { settings in
      if settings.authorizationStatus == .authorized {
        let content = UNMutableNotificationContent()
        content.title = "Pipeline for " + msg.projectName + " " + msg.status
        content.body = msg.commitMessage
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

  func pipelinesStillRunning() -> Bool {
    return !pipelineStatuses.allSatisfy { key, value in
      value.status != "running"
        || (value.status == "running" && value.timeStamp.timeIntervalSinceNow > 300)
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
        self.task = Task.detached(priority: .userInitiated) { [weak self] in
          do {
            for try await message in stream {
              self?.notify(event: try message.message())
            }
          } catch let error as NSError {
            if !(error.domain == "NSPOSIXErrorDomain" && error.code == 57) {
              await logger.log("Oops something didn't go right: \(error)")
            }
            self?.connectionFailed(url: url)
          }
        }

      } else if !authorized {
        logger.log("Notifications not authorized")
      } else {
        logger.log(error?.localizedDescription ?? "Notifications request unknown error")
      }

    }

  }
}

struct PipelineStatus {
  var status: String
  var timeStamp: Date
}
