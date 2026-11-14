import Darwin
import Foundation

enum SecureLocalFiles {
  /// Reads bounded request input from one no-follow descriptor and rejects any
  /// observable metadata change before its bytes can be decoded.
  static func readStableRegularFile(
    path: String,
    maximumBytes: Int,
    afterRead: (() throws -> Void)? = nil
  ) throws -> Data {
    let target = try Target(path: path)
    let directory = try openDirectory(target.directory)
    defer { close(directory) }
    // O_NONBLOCK makes FIFO and similar non-regular entries fail closed at the
    // fstat check below instead of allowing an attacker-controlled pathname to
    // stall the caller while opening it.
    let fd = openat(directory, target.name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
    guard fd >= 0 else { throw GatewayError("Unable to open request file", code: .invalidArgument, exitCode: 2) }
    defer { close(fd) }
    var before = stat()
    guard fstat(fd, &before) == 0, before.st_mode & S_IFMT == S_IFREG, before.st_size <= off_t(maximumBytes) else {
      throw GatewayError("Request file is not a bounded regular file", code: .invalidArgument, exitCode: 2)
    }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 16_384)
    while true {
      let count = read(fd, &buffer, buffer.count)
      guard count >= 0 else { throw GatewayError("Unable to read request file", code: .invalidArgument, exitCode: 2) }
      if count == 0 { break }
      guard data.count + count <= maximumBytes else { throw GatewayError("Request file exceeds the allowed size", code: .invalidArgument, exitCode: 2) }
      data.append(buffer, count: count)
    }
    try afterRead?()
    var after = stat()
    var currentEntry = stat()
    guard fstat(fd, &after) == 0,
      fstatat(directory, target.name, &currentEntry, AT_SYMLINK_NOFOLLOW) == 0,
      before.st_dev == after.st_dev, before.st_ino == after.st_ino,
      before.st_dev == currentEntry.st_dev, before.st_ino == currentEntry.st_ino,
      before.st_mode & S_IFMT == currentEntry.st_mode & S_IFMT,
      before.st_mode == after.st_mode, before.st_size == after.st_size,
      before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
      before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
      before.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec,
      before.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec else {
      throw GatewayError("Request file changed while being read", code: .invalidArgument, exitCode: 2)
    }
    return data
  }

  static func readRegularFile(
    path: String,
    maximumBytes: Int,
    requireCurrentUser: Bool = false,
    requirePrivateMode: Bool = false,
    requirePrivateParent: Bool = false
  ) throws -> Data {
    let target = try Target(path: path)
    let directory = try openDirectory(target.directory)
    defer { close(directory) }
    if requirePrivateParent { try validatePrivateDirectory(directory) }
    let fd = openat(directory, target.name, O_RDONLY | O_NOFOLLOW)
    guard fd >= 0 else { throw GatewayError("Unable to open configured file", code: .invalidConfiguration, exitCode: 2) }
    defer { close(fd) }
    var metadata = stat()
    guard fstat(fd, &metadata) == 0, metadata.st_mode & S_IFMT == S_IFREG,
      !requireCurrentUser || metadata.st_uid == getuid(),
      !requirePrivateMode || metadata.st_mode & 0o077 == 0 else {
      throw GatewayError("Configured path is not a regular file", code: .invalidConfiguration, exitCode: 2)
    }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 16_384)
    while true {
      let count = read(fd, &buffer, buffer.count)
      guard count >= 0 else { throw GatewayError("Unable to read configured file", code: .invalidConfiguration, exitCode: 2) }
      if count == 0 { break }
      guard data.count + count <= maximumBytes else { throw GatewayError("Configured file exceeds the allowed size", code: .invalidArgument, exitCode: 2) }
      data.append(buffer, count: count)
    }
    var verified = stat()
    guard fstat(fd, &verified) == 0, metadata.st_dev == verified.st_dev, metadata.st_ino == verified.st_ino else {
      throw GatewayError("Configured file changed while being read", code: .invalidConfiguration, exitCode: 2)
    }
    return data
  }

  static func writePrivateFile(_ data: Data, path: String) throws {
    let target = try Target(path: path)
    let directory = try openDirectory(target.directory)
    defer { close(directory) }
    try validatePrivateDirectory(directory)
    var original = stat()
    let originalResult = fstatat(directory, target.name, &original, AT_SYMLINK_NOFOLLOW)
    let replacing: Bool
    if originalResult == 0 {
      guard (original.st_mode & S_IFMT) == S_IFREG, original.st_uid == getuid(), (original.st_mode & 0o077) == 0 else {
        throw GatewayError("OAuth token store is not a private regular file", code: .invalidConfiguration, exitCode: 2)
      }
      replacing = true
    } else if errno == ENOENT {
      replacing = false
    } else {
      throw GatewayError("Unable to inspect token store destination", code: .invalidConfiguration, exitCode: 2)
    }
    let temporary = ".gateway-token-\(UUID().uuidString)"
    let fd = openat(directory, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR)
    guard fd >= 0 else { throw GatewayError("Unable to create token store", code: .invalidConfiguration, exitCode: 2) }
    defer { close(fd) }
    var offset = 0
    try data.withUnsafeBytes { raw in
      while offset < data.count {
        let count = write(fd, raw.baseAddress!.advanced(by: offset), data.count - offset)
        guard count > 0 else { throw GatewayError("Unable to write token store", code: .invalidConfiguration, exitCode: 2) }
        offset += count
      }
    }
    guard fsync(fd) == 0 else {
      unlinkat(directory, temporary, 0)
      throw GatewayError("Unable to persist token store", code: .invalidConfiguration, exitCode: 2)
    }
    if replacing {
      var current = stat()
      guard fstatat(directory, target.name, &current, AT_SYMLINK_NOFOLLOW) == 0,
        (current.st_mode & S_IFMT) == S_IFREG,
        current.st_dev == original.st_dev, current.st_ino == original.st_ino,
        current.st_uid == getuid(), (current.st_mode & 0o077) == 0,
        renameat(directory, temporary, directory, target.name) == 0 else {
        unlinkat(directory, temporary, 0)
        throw GatewayError("OAuth token store destination changed before replacement", code: .invalidConfiguration, exitCode: 2)
      }
    } else {
      // linkat creates the destination only when it is still absent, so a file
      // appearing after validation cannot be overwritten by this persistence step.
      guard linkat(directory, temporary, directory, target.name, 0) == 0 else {
        unlinkat(directory, temporary, 0)
        throw GatewayError("OAuth token store destination already exists or changed", code: .invalidConfiguration, exitCode: 2)
      }
      guard unlinkat(directory, temporary, 0) == 0 else {
        throw GatewayError("Unable to finalize token store", code: .invalidConfiguration, exitCode: 2)
      }
    }
    guard fsync(directory) == 0 else {
      throw GatewayError("Unable to finalize token store", code: .invalidConfiguration, exitCode: 2)
    }
  }

  static func deleteRegularFile(path: String) throws -> Bool {
    try readAndDeletePrivateFile(path: path, maximumBytes: 0) { _ in }
  }

  static func readAndDeletePrivateFile(
    path: String,
    maximumBytes: Int,
    validate: (Data) throws -> Void
  ) throws -> Bool {
    let target = try Target(path: path)
    let directory = try openDirectory(target.directory)
    defer { close(directory) }
    try validatePrivateDirectory(directory)
    let fd = openat(directory, target.name, O_RDONLY | O_NOFOLLOW)
    if fd < 0 {
      if errno == ENOENT { return false }
      throw GatewayError("Unable to inspect token store", code: .invalidConfiguration, exitCode: 2)
    }
    defer { close(fd) }
    var metadata = stat()
    guard fstat(fd, &metadata) == 0, (metadata.st_mode & S_IFMT) == S_IFREG,
      metadata.st_uid == getuid(), (metadata.st_mode & 0o077) == 0 else {
      throw GatewayError("OAuth token store is not a regular file", code: .invalidConfiguration, exitCode: 2)
    }
    var data = Data()
    if maximumBytes > 0 {
      var buffer = [UInt8](repeating: 0, count: 16_384)
      while true {
        let count = read(fd, &buffer, buffer.count)
        guard count >= 0 else { throw GatewayError("Unable to read token store", code: .invalidConfiguration, exitCode: 2) }
        if count == 0 { break }
        guard data.count + count <= maximumBytes else {
          throw GatewayError("OAuth token store exceeds the allowed size", code: .invalidArgument, exitCode: 2)
        }
        data.append(buffer, count: count)
      }
    }
    try validate(data)
    var verified = stat()
    guard fstat(fd, &verified) == 0,
      metadata.st_dev == verified.st_dev, metadata.st_ino == verified.st_ino else {
      throw GatewayError("OAuth token store changed before deletion", code: .invalidConfiguration, exitCode: 2)
    }
    var entry = stat()
    guard fstatat(directory, target.name, &entry, AT_SYMLINK_NOFOLLOW) == 0,
      (entry.st_mode & S_IFMT) == S_IFREG,
      entry.st_dev == metadata.st_dev, entry.st_ino == metadata.st_ino else {
      throw GatewayError("OAuth token store changed before deletion", code: .invalidConfiguration, exitCode: 2)
    }
    guard unlinkat(directory, target.name, 0) == 0 else { throw GatewayError("Unable to remove token store", code: .invalidConfiguration, exitCode: 2) }
    return true
  }

  static func pathEntryExists(path: String) -> Bool {
    var metadata = stat()
    return lstat(path, &metadata) == 0
  }

  private static func validatePrivateDirectory(_ fd: Int32) throws {
    var metadata = stat()
    guard fstat(fd, &metadata) == 0, (metadata.st_mode & S_IFMT) == S_IFDIR,
      metadata.st_uid == getuid(), (metadata.st_mode & 0o077) == 0 else {
      throw GatewayError("OAuth token-store directory is not private", code: .invalidConfiguration, exitCode: 2)
    }
  }

  private static func openDirectory(_ components: [String]) throws -> Int32 {
    var fd = open("/", O_RDONLY | O_DIRECTORY)
    guard fd >= 0 else { throw GatewayError("Unable to open filesystem root", code: .invalidConfiguration, exitCode: 2) }
    for component in components {
      let next = openat(fd, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
      close(fd)
      guard next >= 0 else { throw GatewayError("Configured path contains an unsafe directory", code: .invalidConfiguration, exitCode: 2) }
      fd = next
    }
    return fd
  }

  private struct Target {
    let directory: [String]
    let name: String
    init(path: String) throws {
      guard CredentialProfileConfiguration.isSafePath(path) else { throw GatewayError("Configured path is invalid", code: .invalidArgument, exitCode: 2) }
      let resolved = path.hasPrefix("/") ? path : FileManager.default.currentDirectoryPath + "/" + path
      let parts = resolved.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
      guard !parts.isEmpty, parts.allSatisfy({ $0 != "." && $0 != ".." }), let name = parts.last else {
        throw GatewayError("Configured path is invalid", code: .invalidArgument, exitCode: 2)
      }
      directory = Array(parts.dropLast())
      self.name = name
    }
  }
}
