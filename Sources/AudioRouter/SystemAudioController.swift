import Foundation
import OSLog

private let systemAudioLog = Logger(subsystem: "io.github.charliecai01.audiorouter", category: "SystemAudio")

/// Controls every connected output device's volume/mute directly via Core Audio
/// (so each one is independently adjustable, not just whichever is currently
/// active), plus the system default device.
@MainActor
final class SystemAudioController: ObservableObject {
    @Published private(set) var defaultDeviceUID: String?
    @Published private(set) var deviceVolumes: [String: Float] = [:]
    @Published private(set) var deviceMutes: [String: Bool] = [:]

    private var refreshTimer: Timer?

    func start() {
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        defaultDeviceUID = OutputDevice.systemDefault()?.uid
        for device in OutputDevice.listAll() {
            if let volume = device.objectID.readOutputVolume() {
                deviceVolumes[device.uid] = volume
            }
            deviceMutes[device.uid] = device.objectID.readOutputMuted()
        }
    }

    func setDefaultDevice(_ device: OutputDevice) {
        do {
            try SystemAudioObject.setDefaultOutputDevice(device.objectID)
            defaultDeviceUID = device.uid
        } catch {
            systemAudioLog.error("failed to set default output device: \(error, privacy: .public)")
        }
    }

    func setVolume(_ value: Float, for device: OutputDevice) {
        deviceVolumes[device.uid] = value
        device.objectID.setOutputVolume(value)
    }

    func toggleMute(for device: OutputDevice) {
        let newValue = !(deviceMutes[device.uid] ?? false)
        deviceMutes[device.uid] = newValue
        device.objectID.setOutputMuted(newValue)
    }

}
