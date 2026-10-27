import SwiftUI
import AppKit

/// Owns the status item and a borderless panel for its dropdown, instead of using
/// SwiftUI's `MenuBarExtra(.window)` — that API anchors its panel to the status
/// item's *leading* edge with no way to change it, so on a status item that isn't
/// hard against the right screen edge the panel visibly hangs off to one side
/// instead of sitting under the icon. Doing this by hand lets us center it.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var globalClickMonitor: Any?

    let processStore = AudioProcessStore()
    let routing = RoutingManager()
    let systemAudio = SystemAudioController()
    let launchAtLogin = LaunchAtLoginController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessRouter.destroyLeakedAggregates()
        AudioCapturePermission.requestIfNeeded()
        processStore.start()
        systemAudio.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(togglePanel)
        }

        let content = MenuContentView()
            .environmentObject(processStore)
            .environmentObject(routing)
            .environmentObject(systemAudio)
            .environmentObject(launchAtLogin)
        let hosting = NSHostingController(rootView: AnyView(content))
        hosting.sizingOptions = [.intrinsicContentSize]

        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentViewController = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 10
        panel.contentView?.layer?.masksToBounds = true
    }

    @objc private func togglePanel() {
        if panel.isVisible {
            closePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }

        processStore.refresh()
        systemAudio.refresh()
        routing.pruneRouters(activeIDs: Set(processStore.processes.map(\.id)))
        routing.reapplySavedAssignments(processes: processStore.processes, availableDevices: OutputDevice.listAll())

        let size = panel.contentViewController?.view.fittingSize ?? panel.frame.size
        let buttonFrame = buttonWindow.convertToScreen(button.frame)
        let origin = NSPoint(x: buttonFrame.midX - size.width / 2, y: buttonFrame.minY - size.height - 4)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)

        panel.orderFrontRegardless()
        panel.makeKey()

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    private func closePanel() {
        panel.orderOut(nil)
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
        }
        globalClickMonitor = nil
    }
}

@main
struct AudioRouterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
