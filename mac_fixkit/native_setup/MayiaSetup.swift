import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let titleLabel = NSTextField(labelWithString: "Install Mayia")
    private let subtitleLabel = NSTextField(wrappingLabelWithString: "Self-contained native macOS installer")
    private let statusLabel = NSTextField(wrappingLabelWithString: "Ready to install Mayia into Applications.")
    private let progress = NSProgressIndicator()
    private let installButton = NSButton(title: "Install Mayia", target: nil, action: nil)
    private let openButton = NSButton(title: "Open Mayia", target: nil, action: nil)
    private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
    private var isInstalling = false
    private var downloadedPayloadRoot: URL?

    private let fallbackPayloadURL = URL(string: "https://github.com/letorfcook-max/Mayia/releases/download/mayia-v1/mayia-macos-arm64-app.zip")!

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildWindow()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildWindow() {
        let frame = NSRect(x: 0, y: 0, width: 680, height: 460)
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

        let hero = NSView(frame: NSRect(x: 0, y: 322, width: 680, height: 138))
        hero.wantsLayer = true
        hero.layer?.backgroundColor = NSColor(calibratedRed: 0.075, green: 0.065, blue: 0.15, alpha: 1.0).cgColor
        content.addSubview(hero)

        titleLabel.font = NSFont.systemFont(ofSize: 31, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.frame = NSRect(x: 38, y: 376, width: 600, height: 42)
        content.addSubview(titleLabel)

        subtitleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = NSColor(calibratedWhite: 0.84, alpha: 1.0)
        subtitleLabel.frame = NSRect(x: 40, y: 340, width: 600, height: 28)
        content.addSubview(subtitleLabel)

        let body = NSTextField(wrappingLabelWithString:
            "Mayia Setup carries its own Mayia.app payload, so it keeps working even if you copy Setup out of the DMG. Installation is staged safely in /Applications and never ejects the disk image while Setup is running."
        )
        body.font = NSFont.systemFont(ofSize: 14)
        body.frame = NSRect(x: 40, y: 236, width: 600, height: 72)
        content.addSubview(body)

        let safety = NSTextField(wrappingLabelWithString:
            "If the embedded payload is ever damaged or missing, Setup can repair itself by downloading the official macOS app package instead of failing with a missing-app message."
        )
        safety.font = NSFont.systemFont(ofSize: 13)
        safety.textColor = .secondaryLabelColor
        safety.frame = NSRect(x: 40, y: 190, width: 600, height: 42)
        content.addSubview(safety)

        statusLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        statusLabel.frame = NSRect(x: 40, y: 136, width: 600, height: 34)
        content.addSubview(statusLabel)

        progress.style = .bar
        progress.isIndeterminate = true
        progress.frame = NSRect(x: 40, y: 112, width: 600, height: 18)
        progress.isHidden = true
        content.addSubview(progress)

        installButton.target = self
        installButton.action = #selector(installPressed(_:))
        installButton.bezelStyle = .rounded
        installButton.keyEquivalent = "\r"
        installButton.frame = NSRect(x: 424, y: 44, width: 126, height: 34)
        content.addSubview(installButton)

        openButton.target = self
        openButton.action = #selector(openPressed(_:))
        openButton.bezelStyle = .rounded
        openButton.frame = NSRect(x: 286, y: 44, width: 128, height: 34)
        openButton.isEnabled = FileManager.default.fileExists(atPath: destinationURL().path)
        content.addSubview(openButton)

        cancelButton.target = self
        cancelButton.action = #selector(cancelPressed(_:))
        cancelButton.bezelStyle = .rounded
        cancelButton.frame = NSRect(x: 560, y: 44, width: 80, height: 34)
        content.addSubview(cancelButton)

        window.makeKeyAndOrderFront(nil)
    }

    private func destinationURL() -> URL {
        URL(fileURLWithPath: "/Applications/Mayia.app", isDirectory: true)
    }

    private func isValidApp(_ url: URL) -> Bool {
        let fm = FileManager.default
        let plist = url.appendingPathComponent("Contents/Info.plist")
        guard fm.fileExists(atPath: plist.path) else { return false }
        guard let info = NSDictionary(contentsOf: plist), let executable = info["CFBundleExecutable"] as? String else { return false }
        return fm.isExecutableFile(atPath: url.appendingPathComponent("Contents/MacOS/\(executable)").path)
    }

    private func localSourceURL() -> URL? {
        let fm = FileManager.default

        // M208 primary path: the complete Mayia.app is embedded INSIDE Setup itself.
        if let resources = Bundle.main.resourceURL {
            let embedded = resources.appendingPathComponent("Payload/Mayia.app", isDirectory: true)
            if isValidApp(embedded) { return embedded }
        }

        // Compatibility with older Mayia DMGs that put Mayia.app next to Setup.
        let setupBundle = Bundle.main.bundleURL
        let sibling = setupBundle.deletingLastPathComponent().appendingPathComponent("Mayia.app", isDirectory: true)
        if isValidApp(sibling) { return sibling }

        // If Setup was copied elsewhere while its original DMG is still mounted, find it there.
        let volumes = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        if let volumeURLs = try? fm.contentsOfDirectory(at: volumes, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for volume in volumeURLs {
                let direct = volume.appendingPathComponent("Mayia.app", isDirectory: true)
                if isValidApp(direct) { return direct }
                let payload = volume.appendingPathComponent("Mayia Setup.app/Contents/Resources/Payload/Mayia.app", isDirectory: true)
                if isValidApp(payload) { return payload }
            }
        }
        return nil
    }

    private func runProcess(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        try process.run()
        process.waitUntilExit()
        let out = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            let message = err.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(domain: "MayiaSetup", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: message.isEmpty ? "A required installer command failed." : message])
        }
        return out
    }

    private func findAppRecursively(in root: URL) -> URL? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return nil }
        for case let url as URL in enumerator {
            if url.lastPathComponent == "Mayia.app" && isValidApp(url) {
                return url
            }
        }
        // Enumerator with skipsPackageDescendants may not descend into wrapper package-like dirs. Try direct known locations too.
        for candidate in [
            root.appendingPathComponent("Mayia.app", isDirectory: true),
            root.appendingPathComponent("app/Mayia.app", isDirectory: true),
            root.appendingPathComponent("dist/Mayia.app", isDirectory: true)
        ] where isValidApp(candidate) { return candidate }
        return nil
    }

    private func downloadFallbackPayload() throws -> URL {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("Mayia-Setup-Payload-\(UUID().uuidString)", isDirectory: true)
        let zip = root.appendingPathComponent("mayia-macos-arm64-app.zip")
        let unpacked = root.appendingPathComponent("unpacked", isDirectory: true)
        try fm.createDirectory(at: unpacked, withIntermediateDirectories: true)
        downloadedPayloadRoot = root

        writeInstallLog("Embedded/local payload unavailable. Repair download started from \(fallbackPayloadURL.absoluteString)")
        _ = try runProcess("/usr/bin/curl", ["-fL", "--retry", "3", "--retry-delay", "2", "--connect-timeout", "20", "-o", zip.path, fallbackPayloadURL.absoluteString])
        let attrs = try fm.attributesOfItem(atPath: zip.path)
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        if size < 5_000_000 {
            throw NSError(domain: "MayiaSetup", code: 41, userInfo: [NSLocalizedDescriptionKey: "The downloaded Mayia package is unexpectedly small."])
        }
        _ = try runProcess("/usr/bin/ditto", ["-x", "-k", zip.path, unpacked.path])
        guard let app = findAppRecursively(in: unpacked) else {
            throw NSError(domain: "MayiaSetup", code: 42, userInfo: [NSLocalizedDescriptionKey: "The downloaded package did not contain a valid Mayia.app."])
        }
        return app
    }

    private func resolveSource() throws -> URL {
        if let local = localSourceURL() {
            writeInstallLog("Using local installer payload at \(local.path)")
            return local
        }
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.stringValue = "Installer payload needs repair. Downloading the official Mayia app…"
        }
        return try downloadFallbackPayload()
    }

    @objc private func installPressed(_ sender: Any?) {
        guard !isInstalling else { return }
        isInstalling = true
        installButton.isEnabled = false
        openButton.isEnabled = false
        cancelButton.isEnabled = false
        statusLabel.stringValue = "Preparing Mayia…"
        progress.isHidden = false
        progress.startAnimation(nil)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let source = try self.resolveSource()
                guard self.isValidApp(source) else {
                    throw NSError(domain: "MayiaSetup", code: 20, userInfo: [NSLocalizedDescriptionKey: "The Mayia.app payload is incomplete or invalid."])
                }
                DispatchQueue.main.async { self.statusLabel.stringValue = "Installing Mayia safely into Applications…" }
                try self.install(source: source, destination: self.destinationURL())
                try self.validateInstalledApp()
                self.writeInstallLog("Install completed successfully")
                DispatchQueue.main.async {
                    self.progress.stopAnimation(nil)
                    self.progress.isHidden = true
                    self.statusLabel.stringValue = "Mayia is installed and verified in Applications."
                    self.installButton.title = "Reinstall"
                    self.installButton.isEnabled = true
                    self.openButton.isEnabled = true
                    self.cancelButton.title = "Close"
                    self.cancelButton.isEnabled = true
                    self.isInstalling = false
                    self.cleanupDownloadedPayload()
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
                    self.cleanupDownloadedPayload()
                    self.showError("Mayia could not be installed.\n\n\(error.localizedDescription)\n\nLog: ~/Library/Logs/Mayia/setup.log")
                }
            }
        }
    }

    private func validateInstalledApp() throws {
        let destination = destinationURL()
        guard isValidApp(destination) else {
            throw NSError(domain: "MayiaSetup", code: 30, userInfo: [NSLocalizedDescriptionKey: "Mayia was copied, but the installed application failed validation."])
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
            if fm.fileExists(atPath: destination.path) { try fm.moveItem(at: destination, to: backup) }
            try fm.moveItem(at: staging, to: destination)
            guard isValidApp(destination) else { throw NSError(domain: "MayiaSetup", code: 31, userInfo: [NSLocalizedDescriptionKey: "Installed application validation failed."]) }
            try? fm.removeItem(at: backup)
            return
        } catch {
            try? fm.removeItem(at: staging)
            if !fm.fileExists(atPath: destination.path), fm.fileExists(atPath: backup.path) { try? fm.moveItem(at: backup, to: destination) }
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

    private func shellQuote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'" }

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
        if alert.runModal() == .alertFirstButtonReturn { openInstalledApp() }
    }

    @objc private func openPressed(_ sender: Any?) { openInstalledApp() }

    private func openInstalledApp() {
        let destination = destinationURL()
        guard isValidApp(destination) else { showError("Mayia is not installed correctly yet."); return }
        NSWorkspace.shared.open(destination)
    }

    @objc private func cancelPressed(_ sender: Any?) { if !isInstalling { NSApp.terminate(nil) } }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Mayia Setup"
        alert.informativeText = message
        alert.runModal()
    }

    private func cleanupDownloadedPayload() {
        if let root = downloadedPayloadRoot { try? FileManager.default.removeItem(at: root) }
        downloadedPayloadRoot = nil
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
