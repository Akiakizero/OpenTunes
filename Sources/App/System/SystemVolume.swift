// SPDX-License-Identifier: GPL-3.0-or-later

import AudioToolbox
import CoreAudio

/// Volume di uscita del sistema (dispositivo predefinito) via CoreAudio.
///
/// Si usa il volume di sistema e non quello del player: funziona con qualsiasi sorgente,
/// browser compresi, e l'adapter non espone un comando per il volume.
enum SystemVolume {
    /// Volume 0…1, `nil` se il dispositivo non lo supporta (es. uscita digitale).
    static var current: Float? {
        guard let device = defaultOutputDevice() else { return nil }
        var address = mainVolumeAddress
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    /// Imposta il volume (limitato a 0…1) e toglie il muto se si alza. Restituisce il valore applicato.
    @discardableResult
    static func set(_ volume: Float) -> Float? {
        guard let device = defaultOutputDevice() else { return nil }
        var address = mainVolumeAddress
        var isSettable: DarwinBoolean = false
        guard AudioObjectHasProperty(device, &address),
            AudioObjectIsPropertySettable(device, &address, &isSettable) == noErr, isSettable.boolValue
        else { return nil }
        var value = Float32(max(0, min(1, volume)))
        let status = AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
        if status == noErr, value > 0 { setMuted(false, device: device) }
        return status == noErr ? value : nil
    }

    /// Cambia il volume di `delta` (es. +0.0625 = un sedicesimo, come i tasti di sistema).
    @discardableResult
    static func change(by delta: Float) -> Float? {
        guard let now = current else { return nil }
        return set(now + delta)
    }

    static let step: Float = 1.0 / 16

    private static var mainVolumeAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
    }

    private static func setMuted(_ muted: Bool, device: AudioDeviceID) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectHasProperty(device, &address) else { return }
        var value: UInt32 = muted ? 1 : 0
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
    }

    private static func defaultOutputDevice() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return status == noErr && device != 0 ? device : nil
    }
}
