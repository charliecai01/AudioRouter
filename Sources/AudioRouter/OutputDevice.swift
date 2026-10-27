import AudioToolbox

struct OutputDevice: Identifiable, Hashable {
    let objectID: AudioObjectID
    let uid: String
    let name: String
    let transportType: UInt32

    var id: String { uid }

    /// SF Symbol matching the device's physical connection, mirroring how SoundSource
    /// distinguishes built-in speakers, headphones, Bluetooth, HDMI displays, etc.
    var symbolName: String {
        switch transportType {
        case kAudioDeviceTransportTypeBuiltIn:
            // The built-in output on a Mac laptop is the machine itself, not a
            // standalone speaker — a laptop glyph reads correctly at a glance.
            return "laptopcomputer"
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            // Most Bluetooth outputs people route to are standalone speakers, not
            // headphones — only show ear-worn glyphs for names that actually say so.
            let lowercased = name.lowercased()
            let headphoneKeywords = ["airpods", "buds", "headphone", "headset", "earphone"]
            return headphoneKeywords.contains(where: lowercased.contains) ? "headphones" : "hifispeaker.fill"
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort:
            return "tv"
        case kAudioDeviceTransportTypeUSB:
            return "cable.connector"
        case kAudioDeviceTransportTypeAirPlay:
            return "airplayaudio"
        default:
            return "speaker.wave.2.fill"
        }
    }

    /// True for speakers whose whole visual identity is a compact amp cabinet with
    /// a row of control knobs (Marshall's Bluetooth speaker line) — no stock SF
    /// Symbol reads as one, so these get a custom glyph instead of `symbolName`.
    var looksLikeAmpStyleSpeaker: Bool {
        let lowercased = name.lowercased()
        let ampStyleNames = ["marshall", "woburn", "kilburn", "stanmore", "acton", "tufton", "emberton", "willen"]
        return ampStyleNames.contains(where: lowercased.contains)
    }

    static func listAll() -> [OutputDevice] {
        guard let deviceIDs = try? SystemAudioObject.allDevices() else { return [] }
        return deviceIDs.compactMap { deviceID in
            guard deviceID.outputChannelCount() > 0,
                  let uid = deviceID.readString(kAudioDevicePropertyDeviceUID),
                  let name = deviceID.readString(kAudioObjectPropertyName),
                  !name.hasPrefix("AudioRouter-")
            else { return nil }
            let transportType = (try? deviceID.read(kAudioDevicePropertyTransportType, as: UInt32(0), context: "transportType")) ?? 0
            return OutputDevice(objectID: deviceID, uid: uid, name: name, transportType: transportType)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func systemDefault() -> OutputDevice? {
        guard let deviceID = try? SystemAudioObject.defaultOutputDevice(),
              deviceID.isValid,
              let uid = deviceID.readString(kAudioDevicePropertyDeviceUID),
              let name = deviceID.readString(kAudioObjectPropertyName)
        else { return nil }
        let transportType = (try? deviceID.read(kAudioDevicePropertyTransportType, as: UInt32(0), context: "transportType")) ?? 0
        return OutputDevice(objectID: deviceID, uid: uid, name: name, transportType: transportType)
    }
}
