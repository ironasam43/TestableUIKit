import Foundation

public enum JSONValue: Codable, Hashable, Sendable {
  case null
  case bool(Bool)
  case int(Int)
  case double(Double)
  case string(String)
  case object([String: JSONValue])

  // MARK: - Codable (Single Value Container)

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    if container.decodeNil() {
      self = .null
    } else if let b = try? container.decode(Bool.self) {
      self = .bool(b)
    } else if let i = try? container.decode(Int.self) {
      self = .int(i)
    } else if let d = try? container.decode(Double.self) {
      self = .double(d)
    } else if let s = try? container.decode(String.self) {
      self = .string(s)
    } else if let o = try? container.decode([String: JSONValue].self) {
      self = .object(o)
    } else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Unknown JSON value")
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    switch self {
    case .null:
      try container.encodeNil()
    case .bool(let b):
      try container.encode(b)
    case .int(let i):
      try container.encode(i)
    case .double(let d):
      try container.encode(d)
    case .string(let s):
      try container.encode(s)
    case .object(let o):
      try container.encode(o)
    }
  }
}
