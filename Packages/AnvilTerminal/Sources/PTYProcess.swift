import Foundation
import Darwin

// MARK: - PTY Process

/// Manages a real pseudo-terminal process using forkpty().
public final class PTYProcess: @unchecked Sendable {

    public enum State: Sendable {
        case idle
        case running
        case exited(Int32)
    }

    private var masterFD: Int32 = -1
    private var childPID: pid_t = -1
    private var readSource: DispatchSourceRead?
    private let readQueue = DispatchQueue(label: "com.anvil.terminal.pty.read")
    private let writeQueue = DispatchQueue(label: "com.anvil.terminal.pty.write")

    public private(set) var state: State = .idle
    public var onOutput: (@Sendable (Data) -> Void)?
    public var onExit: (@Sendable (Int32) -> Void)?

    public init() {}

    deinit {
        terminate()
    }

    // MARK: - Spawn

    /// Spawns a new PTY process with the given shell and initial size.
    public func spawn(
        shell: String? = nil,
        columns: UInt16 = 80,
        rows: UInt16 = 24,
        environment: [String: String]? = nil,
        workingDirectory: String? = nil
    ) throws {
        guard case .idle = state else {
            throw PTYError.alreadyRunning
        }

        let shellPath = shell ?? ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

        var winSize = winsize(
            ws_row: rows,
            ws_col: columns,
            ws_xpixel: 0,
            ws_ypixel: 0
        )

        var masterFD: Int32 = -1
        let pid = forkpty(&masterFD, nil, nil, &winSize)

        if pid < 0 {
            throw PTYError.forkFailed(errno)
        }

        if pid == 0 {
            // Child process
            setupChildEnvironment(shell: shellPath, environment: environment, workingDirectory: workingDirectory)

            // exec the shell as a login shell
            let loginShellName = "-" + (shellPath as NSString).lastPathComponent
            let argv: [UnsafeMutablePointer<CChar>?] = [
                strdup(loginShellName),
                nil,
            ]
            execv(shellPath, argv)

            // If exec fails, exit child
            _exit(1)
        }

        // Parent process
        self.masterFD = masterFD
        self.childPID = pid
        self.state = .running

        // Make master FD non-blocking
        let flags = fcntl(masterFD, F_GETFL)
        _ = fcntl(masterFD, F_SETFL, flags | O_NONBLOCK)

        startReading()
        monitorChild()
    }

    // MARK: - Write

    /// Writes data to the PTY stdin.
    public func write(_ data: Data) {
        guard case .running = state, masterFD >= 0 else { return }
        writeQueue.async { [masterFD] in
            data.withUnsafeBytes { buffer in
                guard let ptr = buffer.baseAddress else { return }
                var written = 0
                let total = buffer.count
                while written < total {
                    let result = Darwin.write(masterFD, ptr.advanced(by: written), total - written)
                    if result < 0 {
                        if errno == EAGAIN || errno == EINTR { continue }
                        break
                    }
                    written += result
                }
            }
        }
    }

    /// Writes a string to the PTY stdin.
    public func write(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        write(data)
    }

    // MARK: - Resize

    /// Notifies the PTY of a terminal size change (TIOCSWINSZ).
    public func resize(columns: UInt16, rows: UInt16) {
        guard masterFD >= 0 else { return }
        var winSize = winsize(
            ws_row: rows,
            ws_col: columns,
            ws_xpixel: 0,
            ws_ypixel: 0
        )
        _ = ioctl(masterFD, TIOCSWINSZ, &winSize)

        // Send SIGWINCH to the child process group
        if childPID > 0 {
            kill(childPID, SIGWINCH)
        }
    }

    // MARK: - Terminate

    /// Terminates the PTY process.
    public func terminate() {
        readSource?.cancel()
        readSource = nil

        if masterFD >= 0 {
            close(masterFD)
            masterFD = -1
        }

        if childPID > 0 {
            kill(childPID, SIGHUP)
            kill(childPID, SIGTERM)
            var status: Int32 = 0
            waitpid(childPID, &status, WNOHANG)
            childPID = -1
        }

        state = .idle
    }

    // MARK: - Private

    private func setupChildEnvironment(shell: String, environment: [String: String]?, workingDirectory: String?) {
        if let dir = workingDirectory {
            chdir(dir)
        }

        // Set basic terminal environment
        setenv("TERM", "xterm-256color", 1)
        setenv("COLORTERM", "truecolor", 1)
        setenv("LANG", "en_US.UTF-8", 1)
        setenv("SHELL", shell, 1)

        // Merge additional environment variables
        if let env = environment {
            for (key, value) in env {
                setenv(key, value, 1)
            }
        }
    }

    private func startReading() {
        let source = DispatchSource.makeReadSource(fileDescriptor: masterFD, queue: readQueue)
        source.setEventHandler { [weak self] in
            self?.readAvailableData()
        }
        source.setCancelHandler { [weak self] in
            guard let self = self, self.masterFD >= 0 else { return }
            // Cleanup handled in terminate()
        }
        source.resume()
        self.readSource = source
    }

    private func readAvailableData() {
        guard masterFD >= 0 else { return }
        let bufferSize = 8192
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        let bytesRead = read(masterFD, &buffer, bufferSize)
        if bytesRead > 0 {
            let data = Data(buffer[0..<bytesRead])
            onOutput?(data)
        } else if bytesRead == 0 {
            // EOF
            readSource?.cancel()
            readSource = nil
        }
        // bytesRead < 0 with EAGAIN is normal for non-blocking
    }

    private func monitorChild() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            var status: Int32 = 0
            let result = waitpid(self.childPID, &status, 0)
            if result > 0 {
                let exitCode: Int32
                if (status & 0x7F) == 0 {
                    exitCode = (status >> 8) & 0xFF
                } else {
                    exitCode = -1
                }
                self.state = .exited(exitCode)
                self.onExit?(exitCode)
            }
        }
    }
}

// MARK: - Errors

public enum PTYError: Error, Sendable {
    case forkFailed(Int32)
    case alreadyRunning
    case notRunning
}
