import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let titleLabel = NSTextField(labelWithString: "Install Mayia")
    private let subtitleLabel = NSTextField(wrappingLabelWithString: "Native macOS installer — no Python or Qt is used by Setup.")
    private let statusLabel = NSTextField(wrappingLabelWithString: "Ready to install Mayia into Applications.")
    private let progress = NSProgressIndicator()
    private let installButton = NSButton(title: "Install Mayia", target: nil, action: nil)
    private let openButton = NSButton(title: "Open Mayia", target: nil, action: nil)
    private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
    private var isInstalling = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildWindow()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildWindow() {
        let frame = NSRect(x: 0, y: 0, width: 640, height: 430)
        window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Mayia Setup"
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        guard let content = window.contentView else { return }

        let hero = NSView(frame: NSRect(x: 0, y: 300, width: 640, height: 130))
        hero.wantsLayer = true
        hero.layer?.backgroundColor = NSColor(calibratedRed: 0.09, green: 0.08, blue: 0.16, alpha: 1.0).cgColor
        content.addSubview(hero)

        titleLabel.font = NSFont.systemFont(ofSize: 30, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.frame = NSRect(x: 36, y: 350, width: 560, height: 42)
        content.addSubview(titleLabel)

        subtitleLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = NSColor(calibratedWhite: 0.82, alpha: 1.0)
        subtitleLabel.frame = NSRect(x: 38, y: 316, width: 560, height: 28)
        content.addSubview(subtitleLabel)

        let body = NSTextField(wrappingLabelWithString:
            "Mayia Setup copies Mayia.app safely into /Applications. The installer never ejects or unmounts the disk image while it is running, and installation work runs in the background so the window remains responsive."
        )
        body.font = NSFont.systemFont(ofSize: 14)
        body.frame = NSRect(x: 38, y: 220, width: 564, height: 62)
        content.addSubview(body)

        statusLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        statusLabel.frame = NSRect(x: 38, y: 155, width: 564, height: 42)
        content.addSubview(statusLabel)

        progress.style = .bar
        progress.isIndeterminate = true
        progress.frame = NSRect(x: 38, y: 128, width: 564, height: 18)
        progress.isHidden = true
        content.addSubview(progress)

        installButton.target = self
        installButton.action = #selector(installPressed(_:))
        installButton.bezelStyle = .rounded
        installButton.keyEquivalent = "\r"
        installButton.frame = NSRect(x: 402, y: 44, width: 126, height: 34)
        content.addSubview(installButton)

        openButton.target = self
        openButton.action = #selector(openPressed(_:))
        openButton.bezelStyle = .rounded
        openButton.frame = NSRect(x: 270, y: 44, width: 122, height: 34)
        openButton.isEnabled = FileManager.default.fileExists(atPath: destinationURL().path)
        content.addSubview(openButton)

        cancelButton.target = self
        cancelButton.action = #selector(cancelPressed(_:))
        cancelButton.bezelStyle = .rounded
        cancelButton.frame = NSRect(x: 536, y: 44, width: 76, height: 34)
        content.addSubview(cancelButton)

        window.makeKeyAndOrderFront(nil)
    }

    private func destinationURL() -> URL {
        URL(fileURLWithPath: "/Applications/Mayia.app", isDirectory: true)
    }

    private func sourceURL() -> URL? {
        let fm = FileManager.default
        let setupBundle = Bundle.main.bundleURL
        let sibling = setupBundle.deletingLastPathComponent().appendingPathComponent("Mayia.app", isDirectory: true)
        if fm.fileExists(atPath: sibling.path) { return sibling }
        let embedded = Bundle.main.resourceURL?.appendingPathComponent("Mayia.app", isDirectory: true)
        if let embedded, fm.fileExists(atPath: embedded.path) { return embedded }
        return nil
    }

    @objc private func installPressed(_ sender: Any?) {
        guard !isInstalling else { return }
        guard let source = sourceURL() else {
            showError("Mayia.app is missing next to Mayia Setup.app. Re-download the official Mayia DMG.")
            return
        }
        guard FileManager.default.fileExists(atPath: source.appendingPathComponent("Contents/Info.plist").path) else {
            showError("The Mayia.app payload is incomplete.")
            return
        }

        isInstalling = true
        installButton.isEnabled = false
        openButton.isEnabled = false
        cancelButton.isEnabled = false
        statusLabel.stringValue = "Installing Mayia… You can keep using this window."
        progress.isHidden = false
        progress.startAnimation(nil)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                try self.install(source: source, destination: self.destinationURL())
                self.writeInstallLog("Install completed successfully")
                DispatchQueue.main.async {
                    self.progress.stopAnimation(nil)
                    self.progress.isHidden = true
                    self.statusLabel.stringValue = "Mayia is installed in Applications."
                    self.installButton.title = "Reinstall"
                    self.installButton.isEnabled = true
                    self.openButton.isEnabled = true
                    self.cancelButton.title = "Close"
                    self.cancelButton.isEnabled = true
                    self.isInstalling = false
                    self.askToOpen()
                }
            } catch {
                self.writeInstallLog("Install failed: \(error)")
                DispatchQueue.main.async {
                    self.progress.stopAnimation(nil)
                    self.progress.isHidden = true
                    self.statusLabel.stringValue = "Installation failed."
                    self.installButton.isEnabled = true
                    self.cancelButton.isEnabled = true
                    self.isInstalling = false
                    self.showError("Mayia could not be installed.\n\n\(error.localizedDescription)")
                }
            }
        }
    }

    private func install(source: URL, destination: URL) throws {
        let fm = FileManager.default
        let parent = destination.deletingLastPathComponent()
        let staging = parent.appendingPathComponent(".Mayia.app.installing-\(UUID().uuidString)", isDirectory: true)
        let backup = parent.appendingPathComponent(".Mayia.app.previous-\(UUID().uuidString)", isDirectory: true)

        do {
            try? fm.removeItem(at: staging)
            try fm.copyItem(at: source, to: staging)
            if fm.fileExists(atPath: destination.path) {
                try fm.moveItem(at: destination, to: backup)
            }
            try fm.moveItem(at: staging, to: destination)
            try? fm.removeItem(at: backup)
            return
        } catch {
            try? fm.removeItem(at: staging)
            if !fm.fileExists(atPath: destination.path), fm.fileExists(atPath: backup.path) {
                try? fm.moveItem(at: backup, to: destination)
            }
        }

        try privilegedInstall(source: source, destination: destination)
    }

    private func privilegedInstall(source: URL, destination: URL) throws {
        let qSource = shellQuote(source.path)
        let qDest = shellQuote(destination.path)
        let qParent = shellQuote(destination.deletingLastPathComponent().path)
        let token = UUID().uuidString
        let stagePath = destination.deletingLastPathComponent().appendingPathComponent(".Mayia.app.installing-\(token)").path
        let backupPath = destination.deletingLastPathComponent().appendingPathComponent(".Mayia.app.previous-\(token)").path
        let qStage = shellQuote(stagePath)
        let qBackup = shellQuote(backupPath)
        let command = """
        set -e
        /bin/mkdir -p \(qParent)
        /bin/rm -rf \(qStage) \(qBackup)
        /usr/bin/ditto \(qSource) \(qStage)
        if [ -d \(qDest) ]; then /bin/mv \(qDest) \(qBackup); fi
        if /bin/mv \(qStage) \(qDest); then
          /bin/rm -rf \(qBackup)
        else
          /bin/rm -rf \(qStage)
          if [ -d \(qBackup) ] && [ ! -d \(qDest) ]; then /bin/mv \(qBackup) \(qDest); fi
          exit 1
        fi
        """
        let script = "do shell script \(appleScriptLiteral(command)) with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let err = Pipe()
        process.standardError = err
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let data = err.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? "Administrator install failed."
            throw NSError(domain: "MayiaSetup", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: message.trimmingCharacters(in: .whitespacesAndNewlines)])
        }
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    private func appleScriptLiteral(_ value: String) -> String {
        var result = value.replacingOccurrences(of: "\\", with: "\\\\")
        result = result.replacingOccurrences(of: "\"", with: "\\\"")
        result = result.replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(result)\""
    }

    private func askToOpen() {
        let alert = NSAlert()
        alert.messageText = "Mayia is installed"
        alert.informativeText = "Open Mayia now?"
        alert.addButton(withTitle: "Open Mayia")
        alert.addButton(withTitle: "Not Now")
        if alert.runModal() == .alertFirstButtonReturn {
            openInstalledApp()
        }
    }

    @objc private func openPressed(_ sender: Any?) {
        openInstalledApp()
    }

    private func openInstalledApp() {
        let destination = destinationURL()
        guard FileManager.default.fileExists(atPath: destination.path) else {
            showError("Mayia is not installed yet.")
            return
        }
        NSWorkspace.shared.open(destination)
    }

    @objc private func cancelPressed(_ sender: Any?) {
        if !isInstalling { NSApp.terminate(nil) }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Mayia Setup"
        alert.informativeText = message
        alert.runModal()
    }

    private func writeInstallLog(_ message: String) {
        do {
            let logs = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Mayia", isDirectory: true)
            try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
            let log = logs.appendingPathComponent("setup.log")
            let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
            if FileManager.default.fileExists(atPath: log.path) {
                let handle = try FileHandle(forWritingTo: log)
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
                try handle.close()
            } else {
                try line.write(to: log, atomically: true, encoding: .utf8)
            }
        } catch { }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool { !isInstalling }
    func windowWillClose(_ notification: Notification) { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
