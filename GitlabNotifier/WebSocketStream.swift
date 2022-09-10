import Foundation

class WebSocketStream: AsyncSequence {

  typealias Element = URLSessionWebSocketTask.Message
  typealias AsyncIterator = AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>.Iterator

  private var stream: AsyncThrowingStream<Element, Error>?
  private var continuation: AsyncThrowingStream<Element, Error>.Continuation?
  private let socket: URLSessionWebSocketTask

  init(url: String, session: URLSession = URLSession.shared) {
    socket = session.webSocketTask(with: URL(string: url)!)
    socket.sendPing(pongReceiveHandler: { error in
      if error != nil {
        logger.log("Pong received with error \(String(describing: error))")
      } else {
        logger.log("Pong received")
      }

    })

    stream = AsyncThrowingStream { continuation in
      self.continuation = continuation
      self.continuation?.onTermination = { @Sendable [socket] _ in
        socket.cancel()
      }
    }
  }

  func makeAsyncIterator() -> AsyncIterator {
    guard let stream = stream else {
      fatalError("stream was not initialized")
    }
    socket.resume()
    listenForMessages()
    return stream.makeAsyncIterator()
  }

  private func listenForMessages() {
    socket.receive { [unowned self] result in
      switch result {
      case .success(let message):
        logger.log("got socket message")
        continuation?.yield(message)
        listenForMessages()
      case .failure(let error):
        continuation?.finish(throwing: error)
      }
    }
  }

}

enum WebSocketError: Error {
  case invalidFormat
}

extension URLSessionWebSocketTask.Message {

  func message() throws -> PipelineEvent {
    switch self {
    case .string(let json):
      let decoder = JSONDecoder()
      guard let data = json.data(using: .utf8) else {
        throw WebSocketError.invalidFormat
      }

      logger.log(String(data: data, encoding: .utf8) ?? "nil")
      let message = try decoder.decode(Welcome.self, from: data)
      return PipelineEvent(
        pipelineId: message.objectAttributes.id, projectName: message.project.name,
        projectId: message.project.id, status: message.objectAttributes.status,
        projectUrl: message.project.webURL,
        commitMessage: message.commit.message,
        namespace: message.project.namespace,
        timestamp: iso8601Formatter.date(from: message.receivedAt) ?? Date(),
        epoch: message.epoch,
        seq: message.seq)
    case .data:
      throw WebSocketError.invalidFormat
    @unknown default:
      throw WebSocketError.invalidFormat
    }
  }
}

func createISO8601Formatter() -> ISO8601DateFormatter {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions.insert(.withFractionalSeconds)
  return formatter
}

let iso8601Formatter = createISO8601Formatter()

struct PipelineEvent {
  let pipelineId: Int
  let projectName: String
  let projectId: Int
  let status: String
  let projectUrl: String
  let commitMessage: String
  let namespace: String
  let timestamp: Date
  let epoch: Int
  let seq: Int
}
