import Darwin
import Foundation

/// The open descriptor owns the lock. Never unlink the file: replacing its
/// inode would let two processes acquire different locks for the same app.
@MainActor
final class SingleInstanceLock {
    private let fileURL: URL
    private var descriptor: Int32?

    init(fileURL: URL) { self.fileURL = fileURL }

    deinit { if let descriptor { Darwin.close(descriptor) } }

    static func fileURL(bundleIdentifier: String) throws -> URL {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let name = bundleIdentifier.replacingOccurrences(of: "/", with: "_")
        return support.appendingPathComponent(name, isDirectory: true).appendingPathComponent("single-instance.lock")
    }

    func acquire() throws -> Bool {
        if descriptor != nil { return true }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let fd = Darwin.open(fileURL.path, O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW, mode_t(0o600))
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        var keepDescriptor = false
        defer { if !keepDescriptor { Darwin.close(fd) } }
        var metadata = stat()
        guard fstat(fd, &metadata) == 0,
              metadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
              metadata.st_uid == geteuid(), metadata.st_nlink == 1 else {
            throw POSIXError(.EINVAL)
        }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            let code = errno
            if code == EWOULDBLOCK || code == EAGAIN { return false }
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }
        let pid = Data("\(getpid())\n".utf8)
        guard ftruncate(fd, 0) == 0 else { throw POSIXError(.EIO) }
        let written = pid.withUnsafeBytes { Darwin.write(fd, $0.baseAddress, $0.count) }
        guard written == pid.count else { throw POSIXError(.EIO) }
        descriptor = fd
        keepDescriptor = true
        return true
    }

    var ownerPID: pid_t? {
        guard let file = try? FileHandle(forReadingFrom: fileURL) else { return nil }
        defer { try? file.close() }
        guard let data = try? file.read(upToCount: 32),
              let text = String(data: data, encoding: .utf8),
              let pid = pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines)), pid > 0 else { return nil }
        return pid
    }

    func release() {
        if let descriptor { Darwin.close(descriptor) }
        descriptor = nil
    }
}
