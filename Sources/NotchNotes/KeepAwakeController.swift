import Combine
import Foundation

struct CaffeinateCommand: Equatable {
    let appProcessID: Int32

    var executableURL: URL {
        URL(fileURLWithPath: "/usr/bin/caffeinate")
    }

    var arguments: [String] {
        ["-di", "-w", String(appProcessID)]
    }
}

@MainActor
final class KeepAwakeController: ObservableObject {
    @Published private(set) var isKeepingAwake = false
    @Published private(set) var errorMessage: String?

    private var process: Process?
    private var isStopping = false

    func toggle() {
        isKeepingAwake ? stop() : start()
    }

    func start() {
        guard process == nil else { return }

        errorMessage = nil
        let command = CaffeinateCommand(
            appProcessID: ProcessInfo.processInfo.processIdentifier
        )
        let process = Process()
        process.executableURL = command.executableURL
        process.arguments = command.arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self, weak process] _ in
            Task { @MainActor in
                guard let self, self.process === process else { return }
                let stoppedByUser = self.isStopping
                self.process = nil
                self.isStopping = false
                self.isKeepingAwake = false
                if !stoppedByUser {
                    self.errorMessage = "The system keep-awake process stopped unexpectedly."
                }
            }
        }

        do {
            try process.run()
            self.process = process
            isKeepingAwake = true
        } catch {
            self.process = nil
            errorMessage = "Could not start /usr/bin/caffeinate: \(error.localizedDescription)"
        }
    }

    func stop() {
        guard let process else {
            isKeepingAwake = false
            return
        }

        isStopping = true
        if process.isRunning {
            process.terminate()
        } else {
            self.process = nil
            isStopping = false
            isKeepingAwake = false
        }
    }

    func dismissError() {
        errorMessage = nil
    }
}
