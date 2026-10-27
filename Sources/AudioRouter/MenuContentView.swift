import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject var processStore: AudioProcessStore
    @EnvironmentObject var routing: RoutingManager
    @EnvironmentObject var systemAudio: SystemAudioController
    @EnvironmentObject var launchAtLogin: LaunchAtLoginController

    private var devices: [OutputDevice] { OutputDevice.listAll() }

    private var audioProcesses: [AudioProcess] {
        processStore.processes.filter { $0.kind == .app && ($0.isRunningAudio || routing.activeRoutes[$0.id] != nil) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider().opacity(0.5)

            outputDevicesSection

            Divider().opacity(0.5)

            if let error = routing.lastError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .padding(9)
                Divider().opacity(0.5)
            }

            sectionLabel("APPS")

            if audioProcesses.isEmpty {
                Text("No app is playing audio right now.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            } else {
                VStack(spacing: 1) {
                    ForEach(audioProcesses) { process in
                        AppRow(process: process, devices: devices)
                    }
                }
                .padding(.bottom, 5)
            }
        }
        .frame(width: 340)
        #if SCREENSHOT_MODE
        // Build with `OTHER_SWIFT_FLAGS='-DSCREENSHOT_MODE'` for a solid background
        // instead of real vibrancy — screenshot tools don't composite the live blur
        // reliably, so this swaps in a flat approximation just for taking clean
        // marketing screenshots. Never used for real Debug/Release builds.
        .background(Color(red: 0.075, green: 0.075, blue: 0.09))
        #else
        .background(VisualEffectView())
        #endif
        .onAppear {
            processStore.refresh()
            systemAudio.refresh()
            routing.pruneRouters(activeIDs: Set(processStore.processes.map(\.id)))
            routing.reapplySavedAssignments(processes: processStore.processes, availableDevices: devices)
        }
    }

    private func sectionLabel(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(size: 9.5, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 9)
            .padding(.bottom, 3)
    }

    private var outputDevicesSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            sectionLabel("OUTPUT DEVICES")

            ForEach(devices) { device in
                OutputDeviceRow(device: device)
            }
        }
        .padding(.top, 3)
        .padding(.bottom, 5)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("AudioRouter")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// One row per connected output device: tap the leading circle to make it the
/// system default, adjust its own volume/mute independently of whether it's the
/// active device right now (Core Audio exposes both regardless of activity).
private struct OutputDeviceRow: View {
    let device: OutputDevice

    @EnvironmentObject var systemAudio: SystemAudioController
    @State private var isHovering = false

    private var isDefault: Bool { systemAudio.defaultDeviceUID == device.uid }
    private var isMuted: Bool { systemAudio.deviceMutes[device.uid] ?? false }
    private var volumeBinding: Binding<Float> {
        Binding(
            get: { systemAudio.deviceVolumes[device.uid] ?? 1 },
            set: { systemAudio.setVolume($0, for: device) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Button {
                    systemAudio.setDefaultDevice(device)
                } label: {
                    Image(systemName: isDefault ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12))
                        .foregroundStyle(isDefault ? Color.accentColor : Color.secondary.opacity(0.45))
                }
                .buttonStyle(.plain)

                Group {
                    if device.looksLikeAmpStyleSpeaker {
                        AmpSpeakerIcon()
                            .fill(.secondary, style: FillStyle(eoFill: true))
                            .frame(width: 13, height: 10)
                    } else {
                        Image(systemName: device.symbolName)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 14)

                Text(device.name)
                    .font(.system(size: 12.5))
                    .lineLimit(1)

                Spacer(minLength: 6)

                Text("\(Int(volumeBinding.wrappedValue * 100))%")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 7) {
                Button {
                    systemAudio.toggleMute(for: device)
                } label: {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(isMuted ? Color.red : Color.secondary)
                        .frame(width: 14)
                }
                .buttonStyle(.plain)

                FlatSlider(value: volumeBinding, range: 0...1)
                    .disabled(isMuted)
                    .opacity(isMuted ? 0.35 : 1)
            }
            .padding(.leading, 22)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(isHovering ? Color.white.opacity(0.05) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { isHovering = $0 }
    }
}

private struct AppRow: View {
    let process: AudioProcess
    let devices: [OutputDevice]

    @EnvironmentObject var routing: RoutingManager
    @State private var isHovering = false

    private var currentDevice: OutputDevice? { routing.activeRoutes[process.id] }
    private var isMuted: Bool { (routing.gains[process.id] ?? 1) <= 0 }
    private var gainBinding: Binding<Float> {
        Binding(
            get: { routing.gains[process.id] ?? 1.0 },
            set: { routing.setGain($0, for: process.id) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(nsImage: process.icon)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                Text(process.name)
                    .font(.system(size: 12))
                    .lineLimit(1)

                Spacer(minLength: 6)

                deviceMenu
            }

            HStack(spacing: 7) {
                Button {
                    routing.toggleMute(for: process.id)
                } label: {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(isMuted ? Color.red : Color.secondary)
                        .frame(width: 14)
                }
                .buttonStyle(.plain)
                .disabled(currentDevice == nil)

                FlatSlider(value: gainBinding)
                    .disabled(currentDevice == nil)

                Text("\(Int(gainBinding.wrappedValue * 100))%")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 30, alignment: .trailing)

                LevelMeterView(level: routing.levels[process.id] ?? 0)
            }
            .opacity(currentDevice == nil ? 0.35 : 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovering ? Color.white.opacity(0.06) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .padding(.horizontal, 5)
        .onHover { isHovering = $0 }
    }

    private var deviceMenu: some View {
        DevicePicker(
            devices: devices,
            includeSystemDefaultOption: true,
            selectedUID: Binding(
                get: { currentDevice?.uid },
                set: { uid in
                    if let uid, let device = devices.first(where: { $0.uid == uid }) {
                        routing.route(process: process, to: device)
                    } else {
                        routing.resetToDefault(process: process)
                    }
                }
            )
        )
    }
}

/// Plain, native macOS pop-up button (`NSPopUpButton` under the hood) — no custom
/// drawing at all, so it renders exactly like every other dropdown in the system.
private struct DevicePicker: View {
    let devices: [OutputDevice]
    let includeSystemDefaultOption: Bool
    @Binding var selectedUID: String?

    var body: some View {
        Picker("", selection: $selectedUID) {
            if includeSystemDefaultOption {
                Text("System Default").tag(String?.none)
            }
            ForEach(devices) { device in
                Text(device.name).tag(Optional(device.uid))
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .controlSize(.small)
        .fixedSize()
    }
}

/// A compact "amp cabinet with control knobs" glyph for Marshall-style Bluetooth
/// speakers — their signature look is the row of brass knobs on the front, which
/// no stock SF Symbol captures. The knobs are punched out of the solid body via
/// an even-odd fill, so they read as holes rather than needing a second color.
private struct AmpSpeakerIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = rect.width / 24

        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: 3 * scale, y: 9 * scale, width: 18 * scale, height: 11 * scale),
            cornerSize: CGSize(width: 2.5 * scale, height: 2.5 * scale)
        )
        for cx: CGFloat in [8, 12, 16] {
            let r: CGFloat = 1.3 * scale
            path.addEllipse(in: CGRect(x: cx * scale - r, y: 13 * scale - r, width: r * 2, height: r * 2))
        }
        return path
    }
}

/// Classic single-bar VU meter. Only shows real data — fills with the live peak level
/// while the app is routed through our own tap; sits empty otherwise (no invented
/// animation when there's no actual signal to show, e.g. "System Default").
private struct LevelMeterView: View {
    var level: Float

    private let width: CGFloat = 7
    private let height: CGFloat = 14
    private let cornerRadius: CGFloat = 3.5

    var body: some View {
        // sqrt boosts quiet moments instead of only reacting to loud peaks — reads as
        // a much livelier, more sensitive meter.
        let fraction = level > 0.001 ? min(sqrt(CGFloat(level)) * 1.5, 1) : 0

        bar(fraction: fraction)
            .animation(.easeOut(duration: 0.06), value: level)
            .frame(width: width, height: height)
    }

    private func bar(fraction: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.white.opacity(0.12))

            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(fraction > 0.85 ? AnyShapeStyle(Color.red.gradient) : AnyShapeStyle(Color.accentColor.gradient))
                .frame(height: height * fraction)
        }
    }
}

#Preview {
    let processStore = AudioProcessStore()
    let routing = RoutingManager()
    let systemAudio = SystemAudioController()
    let launchAtLogin = LaunchAtLoginController()

    return MenuContentView()
        .environmentObject(processStore)
        .environmentObject(routing)
        .environmentObject(systemAudio)
        .environmentObject(launchAtLogin)
        .onAppear {
            processStore.start()
            systemAudio.start()
        }
}
