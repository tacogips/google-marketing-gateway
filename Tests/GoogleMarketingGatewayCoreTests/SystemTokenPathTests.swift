import Foundation
import Testing
@testable import GoogleMarketingGatewayCore

@Test func systemTemporaryAliasSupportsPrivateTokenLifecycle() throws {
  let root = URL(fileURLWithPath: "/tmp").appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let path = root.appendingPathComponent("token.json").path
  let bytes = Data("token-fixture".utf8)
  try SecureLocalFiles.ensurePrivateParent(ofPath: path)
  try SecureLocalFiles.writePrivateFile(bytes, path: path)
  #expect(try SecureLocalFiles.readRegularFile(path: path, maximumBytes: 1024,
    requireCurrentUser: true, requirePrivateMode: true, requirePrivateParent: true) == bytes)
  let removed = try SecureLocalFiles.readAndDeletePrivateFile(path: path, maximumBytes: 1024) { data in
    #expect(data == bytes)
  }
  #expect(removed)
  #expect(!FileManager.default.fileExists(atPath: path))
}

@Test func systemAliasDoesNotPermitUserControlledTokenSymlinks() throws {
  let root = URL(fileURLWithPath: "/tmp").appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let real = root.appendingPathComponent("real")
  let path = real.appendingPathComponent("token.json").path
  try SecureLocalFiles.ensurePrivateParent(ofPath: path)
  try SecureLocalFiles.writePrivateFile(Data("fixture".utf8), path: path)
  let link = root.appendingPathComponent("link")
  try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
  #expect(throws: (any Error).self) {
    try SecureLocalFiles.readRegularFile(path: link.appendingPathComponent("token.json").path, maximumBytes: 1024)
  }
  let leaf = real.appendingPathComponent("link.json")
  try FileManager.default.createSymbolicLink(atPath: leaf.path, withDestinationPath: path)
  #expect(throws: (any Error).self) {
    try SecureLocalFiles.readRegularFile(path: leaf.path, maximumBytes: 1024)
  }
}
