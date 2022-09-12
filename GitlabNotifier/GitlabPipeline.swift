import Foundation

struct WebsocketMessage: Codable {
  let gitlab: GitlabMessage?
  let receivedAt: String
  let seq: Int
  let epoch: Int
  let version: Int

  enum CodingKeys: String, CodingKey {
    case gitlab, seq, epoch, version
    case receivedAt = "received_at"
  }
}

// MARK: - GitlabMessage

struct GitlabMessage: Codable {
  let objectKind: String
  let objectAttributes: ObjectAttributes
  let mergeRequest: String?
  let user: User
  let project: Project
  let commit: Commit
  let builds: [Build]

  enum CodingKeys: String, CodingKey {
    case objectKind = "object_kind"
    case objectAttributes = "object_attributes"
    case mergeRequest = "merge_request"
    case user, project, commit, builds
  }
}

// MARK: - Build
struct Build: Codable {
  let id: Int
  let stage, name, status, createdAt: String
  let startedAt: String?
  let finishedAt: String?
  let duration, queuedDuration: Double?
  let when: String
  let manual, allowFailure: Bool
  let user: User
  let runner: Runner?

  enum CodingKeys: String, CodingKey {
    case id, stage, name, status
    case createdAt = "created_at"
    case startedAt = "started_at"
    case finishedAt = "finished_at"
    case duration
    case queuedDuration = "queued_duration"
    case when, manual
    case allowFailure = "allow_failure"
    case user, runner
  }
}

// MARK: - Runner
struct Runner: Codable {
  let id: Int
  let runnerDescription, runnerType: String
  let active, isShared: Bool
  let tags: [String]

  enum CodingKeys: String, CodingKey {
    case id
    case runnerDescription = "description"
    case runnerType = "runner_type"
    case active
    case isShared = "is_shared"
    case tags
  }
}

// MARK: - User
struct User: Codable {
  let id: Int
  let name, username: String
  let avatarURL: String
  let email: String

  enum CodingKeys: String, CodingKey {
    case id, name, username
    case avatarURL = "avatar_url"
    case email
  }
}

// MARK: - Commit
struct Commit: Codable {
  let id, message, title: String
  let timestamp: String
  let url: String
  let author: Author
}

// MARK: - Author
struct Author: Codable {
  let name, email: String
}

// MARK: - ObjectAttributes
struct ObjectAttributes: Codable {
  let id: Int
  let ref: String
  let tag: Bool
  let sha, beforeSHA, source, status: String
  let detailedStatus: String
  let stages: [String]
  let createdAt: String
  let finishedAt: String?
  let duration, queuedDuration: Int?
  let variables: [JSONAny]

  enum CodingKeys: String, CodingKey {
    case id, ref, tag, sha
    case beforeSHA = "before_sha"
    case source, status
    case detailedStatus = "detailed_status"
    case stages
    case createdAt = "created_at"
    case finishedAt = "finished_at"
    case duration
    case queuedDuration = "queued_duration"
    case variables
  }
}

// MARK: - Project
struct Project: Codable {
  let id: Int
  let name, projectDescription: String
  let webURL: String
  let avatarURL: String?
  let gitSSHURL: String
  let gitHTTPURL: String
  let namespace: String
  let visibilityLevel: Int
  let pathWithNamespace, defaultBranch: String
  let ciConfigPath: String?

  enum CodingKeys: String, CodingKey {
    case id, name
    case projectDescription = "description"
    case webURL = "web_url"
    case avatarURL = "avatar_url"
    case gitSSHURL = "git_ssh_url"
    case gitHTTPURL = "git_http_url"
    case namespace
    case visibilityLevel = "visibility_level"
    case pathWithNamespace = "path_with_namespace"
    case defaultBranch = "default_branch"
    case ciConfigPath = "ci_config_path"
  }
}

// MARK: - Encode/decode helpers

class JSONNull: Codable, Hashable {

  public static func == (lhs: JSONNull, rhs: JSONNull) -> Bool {
    return true
  }

  public var hashValue: Int {
    return 0
  }

  public func hash(into hasher: inout Hasher) {
    // No-op
  }

  public init() {}

  public required init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if !container.decodeNil() {
      throw DecodingError.typeMismatch(
        JSONNull.self,
        DecodingError.Context(
          codingPath: decoder.codingPath, debugDescription: "Wrong type for JSONNull"))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encodeNil()
  }
}

class JSONCodingKey: CodingKey {
  let key: String

  required init?(intValue: Int) {
    return nil
  }

  required init?(stringValue: String) {
    key = stringValue
  }

  var intValue: Int? {
    return nil
  }

  var stringValue: String {
    return key
  }
}

class JSONAny: Codable {

  let value: Any

  static func decodingError(forCodingPath codingPath: [CodingKey]) -> DecodingError {
    let context = DecodingError.Context(
      codingPath: codingPath, debugDescription: "Cannot decode JSONAny")
    return DecodingError.typeMismatch(JSONAny.self, context)
  }

  static func encodingError(forValue value: Any, codingPath: [CodingKey]) -> EncodingError {
    let context = EncodingError.Context(
      codingPath: codingPath, debugDescription: "Cannot encode JSONAny")
    return EncodingError.invalidValue(value, context)
  }

  static func decode(from container: SingleValueDecodingContainer) throws -> Any {
    if let value = try? container.decode(Bool.self) {
      return value
    }
    if let value = try? container.decode(Int64.self) {
      return value
    }
    if let value = try? container.decode(Double.self) {
      return value
    }
    if let value = try? container.decode(String.self) {
      return value
    }
    if container.decodeNil() {
      return JSONNull()
    }
    throw decodingError(forCodingPath: container.codingPath)
  }

  static func decode(from container: inout UnkeyedDecodingContainer) throws -> Any {
    if let value = try? container.decode(Bool.self) {
      return value
    }
    if let value = try? container.decode(Int64.self) {
      return value
    }
    if let value = try? container.decode(Double.self) {
      return value
    }
    if let value = try? container.decode(String.self) {
      return value
    }
    if let value = try? container.decodeNil() {
      if value {
        return JSONNull()
      }
    }
    if var container = try? container.nestedUnkeyedContainer() {
      return try decodeArray(from: &container)
    }
    if var container = try? container.nestedContainer(keyedBy: JSONCodingKey.self) {
      return try decodeDictionary(from: &container)
    }
    throw decodingError(forCodingPath: container.codingPath)
  }

  static func decode(
    from container: inout KeyedDecodingContainer<JSONCodingKey>, forKey key: JSONCodingKey
  ) throws -> Any {
    if let value = try? container.decode(Bool.self, forKey: key) {
      return value
    }
    if let value = try? container.decode(Int64.self, forKey: key) {
      return value
    }
    if let value = try? container.decode(Double.self, forKey: key) {
      return value
    }
    if let value = try? container.decode(String.self, forKey: key) {
      return value
    }
    if let value = try? container.decodeNil(forKey: key) {
      if value {
        return JSONNull()
      }
    }
    if var container = try? container.nestedUnkeyedContainer(forKey: key) {
      return try decodeArray(from: &container)
    }
    if var container = try? container.nestedContainer(keyedBy: JSONCodingKey.self, forKey: key) {
      return try decodeDictionary(from: &container)
    }
    throw decodingError(forCodingPath: container.codingPath)
  }

  static func decodeArray(from container: inout UnkeyedDecodingContainer) throws -> [Any] {
    var arr: [Any] = []
    while !container.isAtEnd {
      let value = try decode(from: &container)
      arr.append(value)
    }
    return arr
  }

  static func decodeDictionary(from container: inout KeyedDecodingContainer<JSONCodingKey>) throws
    -> [String: Any]
  {
    var dict = [String: Any]()
    for key in container.allKeys {
      let value = try decode(from: &container, forKey: key)
      dict[key.stringValue] = value
    }
    return dict
  }

  static func encode(to container: inout UnkeyedEncodingContainer, array: [Any]) throws {
    for value in array {
      if let value = value as? Bool {
        try container.encode(value)
      } else if let value = value as? Int64 {
        try container.encode(value)
      } else if let value = value as? Double {
        try container.encode(value)
      } else if let value = value as? String {
        try container.encode(value)
      } else if value is JSONNull {
        try container.encodeNil()
      } else if let value = value as? [Any] {
        var container = container.nestedUnkeyedContainer()
        try encode(to: &container, array: value)
      } else if let value = value as? [String: Any] {
        var container = container.nestedContainer(keyedBy: JSONCodingKey.self)
        try encode(to: &container, dictionary: value)
      } else {
        throw encodingError(forValue: value, codingPath: container.codingPath)
      }
    }
  }

  static func encode(
    to container: inout KeyedEncodingContainer<JSONCodingKey>, dictionary: [String: Any]
  ) throws {
    for (key, value) in dictionary {
      let key = JSONCodingKey(stringValue: key)!
      if let value = value as? Bool {
        try container.encode(value, forKey: key)
      } else if let value = value as? Int64 {
        try container.encode(value, forKey: key)
      } else if let value = value as? Double {
        try container.encode(value, forKey: key)
      } else if let value = value as? String {
        try container.encode(value, forKey: key)
      } else if value is JSONNull {
        try container.encodeNil(forKey: key)
      } else if let value = value as? [Any] {
        var container = container.nestedUnkeyedContainer(forKey: key)
        try encode(to: &container, array: value)
      } else if let value = value as? [String: Any] {
        var container = container.nestedContainer(keyedBy: JSONCodingKey.self, forKey: key)
        try encode(to: &container, dictionary: value)
      } else {
        throw encodingError(forValue: value, codingPath: container.codingPath)
      }
    }
  }

  static func encode(to container: inout SingleValueEncodingContainer, value: Any) throws {
    if let value = value as? Bool {
      try container.encode(value)
    } else if let value = value as? Int64 {
      try container.encode(value)
    } else if let value = value as? Double {
      try container.encode(value)
    } else if let value = value as? String {
      try container.encode(value)
    } else if value is JSONNull {
      try container.encodeNil()
    } else {
      throw encodingError(forValue: value, codingPath: container.codingPath)
    }
  }

  public required init(from decoder: Decoder) throws {
    if var arrayContainer = try? decoder.unkeyedContainer() {
      self.value = try JSONAny.decodeArray(from: &arrayContainer)
    } else if var container = try? decoder.container(keyedBy: JSONCodingKey.self) {
      self.value = try JSONAny.decodeDictionary(from: &container)
    } else {
      let container = try decoder.singleValueContainer()
      self.value = try JSONAny.decode(from: container)
    }
  }

  public func encode(to encoder: Encoder) throws {
    if let arr = self.value as? [Any] {
      var container = encoder.unkeyedContainer()
      try JSONAny.encode(to: &container, array: arr)
    } else if let dict = self.value as? [String: Any] {
      var container = encoder.container(keyedBy: JSONCodingKey.self)
      try JSONAny.encode(to: &container, dictionary: dict)
    } else {
      var container = encoder.singleValueContainer()
      try JSONAny.encode(to: &container, value: self.value)
    }
  }
}
