// SPDX-License-Identifier: GPL-3.0-or-later

import CoreAudio
import Foundation

/// Un dispositivo di uscita audio.
struct AudioOutputDevice: Identifiable, Equatable, Sendable {
    let id: AudioDeviceID
    let name: String
    /// Tipo di collegamento (per il simbolo: AirPlay, Bluetooth, altoparlanti integrati…).
    let transport: UInt32

    var symbol: String {
        switch transport {
        case kAudioDeviceTransportTypeAirPlay: "airplayaudio"
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: "headphones"
        case kAudioDeviceTransportTypeBuiltIn: "laptopcomputer"
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort: "tv"
        case kAudioDeviceTransportTypeUSB: "cable.connector"
        default: "hifispeaker"
        }
    }
}

/// Dispositivi di uscita e uscita predefinita del sistema via Core Audio (scelta dal popover).
enum AudioOutput {
    /// Dispositivi con almeno un canale di uscita, in ordine alfabetico.
    static func devices() -> [AudioOutputDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.filter(hasOutput)
            .compactMap { id in name(of: id).map { AudioOutputDevice(id: id, name: $0, transport: transport(of: id)) } }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static var defaultDeviceID: AudioDeviceID? {
        var address = defaultOutputAddress
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return status == noErr && device != 0 ? device : nil
    }

    /// Imposta l'uscita predefinita (anche quella degli effetti di sistema, come fa il menu Suono).
    @discardableResult
    static func setDefault(_ device: AudioDeviceID) -> Bool {
        var value = device
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var address = defaultOutputAddress
        let status = AudioObjectSetPropertyData(system, &address, 0, nil, size, &value)
        var effects = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        AudioObjectSetPropertyData(system, &effects, 0, nil, size, &value)
        return status == noErr
    }

    /// Notifiche di Core Audio quando cambiano l'uscita predefinita o l'elenco dei dispositivi.
    /// Il blocco gira sulla coda principale; il flusso finisce quando il consumatore smette di leggerlo.
    static func changes() -> AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let system = AudioObjectID(kAudioObjectSystemObject)
            // Lo stesso blocco (un riferimento Objective-C) serve per registrare e togliere il listener.
            let block = ListenerBlock { _, _ in continuation.yield() }
            var addresses = [
                defaultOutputAddress,
                AudioObjectPropertyAddress(
                    mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain),
            ]
            for index in addresses.indices {
                AudioObjectAddPropertyListenerBlock(system, &addresses[index], .main, block.block)
            }
            let registered = addresses
            continuation.onTermination = { _ in
                for var address in registered {
                    AudioObjectRemovePropertyListenerBlock(system, &address, .main, block.block)
                }
            }
        }
    }

    /// Il blocco di Core Audio non è `Sendable`, ma è immutabile e Core Audio lo chiama sulla coda principale.
    private struct ListenerBlock: @unchecked Sendable {
        let block: AudioObjectPropertyListenerBlock
        init(_ block: @escaping AudioObjectPropertyListenerBlock) { self.block = block }
    }

    // MARK: Proprietà

    private static var defaultOutputAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
    }

    private static func hasOutput(_ device: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func name(of device: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &name) == noErr, let value = name?.takeRetainedValue() else {
            return nil
        }
        return value as String
    }

    private static func transport(of device: AudioDeviceID) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        return value
    }
}
