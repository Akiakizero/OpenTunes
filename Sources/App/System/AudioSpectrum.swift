// SPDX-License-Identifier: GPL-3.0-or-later
//
// Analisi dello spettro con l'algoritmo di cava (https://github.com/karlstav/cava, MIT, `cavacore.c`): bande in scala
// logaritmica, equalizzazione per frequenza, sensibilità automatica, caduta "a gravità" e filtro integrale.
// Codice riscritto in Swift con Core Audio e Accelerate.

import Accelerate
import CoreAudio
import Foundation
import os
import Synchronization

/// Spettro reale dell'audio di sistema per il visualizer.
///
/// Cattura l'uscita con un *process tap* di Core Audio (macOS 14.2+) collegato a un dispositivo aggregato privato:
/// nessun driver virtuale, l'audio non viene modificato né registrato. La prima volta macOS chiede il permesso
/// «Registrazione audio di sistema»; se è negato arrivano solo zeri e `isReceivingAudio` resta `false`
/// (il visualizer torna all'animazione).
///
/// L'FFT gira nel thread audio di Core Audio a ~30 analisi al secondo; le viste leggono `levels` sotto `Mutex`.
final class AudioSpectrum: Sendable {
    static let bandCount = 6

    private struct Capture {
        var tap = AudioObjectID(kAudioObjectUnknown)
        var aggregate = AudioObjectID(kAudioObjectUnknown)
        var ioProc: AudioDeviceIOProcID?
    }

    private let capture = Mutex(Capture())
    private let analyzer = Mutex(SpectrumAnalyzer(bands: AudioSpectrum.bandCount))
    private let logger = Logger(subsystem: "org.opentunes.OpenTunes", category: "Spectrum")

    var isRunning: Bool { capture.withLock { $0.ioProc != nil } }

    /// Livelli 0…1 delle bande, dalle basse alle alte.
    var levels: [Float] { analyzer.withLock { $0.levels } }

    /// `true` se nell'ultimo secondo è arrivato audio non silenzioso.
    var isReceivingAudio: Bool { analyzer.withLock { $0.isReceivingAudio } }

    func start() {
        guard !isRunning else { return }
        do {
            try capture.withLock { state in
                state = try Self.makeCapture { [weak self] samples, count, channels, rate in
                    self?.ingest(samples, frames: count, channels: channels, sampleRate: rate)
                }
            }
        } catch {
            logger.error("spettro non disponibile: \(String(describing: error), privacy: .public)")
            stop()
        }
    }

    /// Dal thread audio: il puntatore vale solo durante la chiamata e non esce dal lock.
    private func ingest(_ samples: UnsafePointer<Float>, frames: Int, channels: Int, sampleRate: Double) {
        nonisolated(unsafe) let pointer = samples
        analyzer.withLock { $0.process(pointer, frames: frames, channels: channels, sampleRate: sampleRate) }
    }

    func stop() {
        capture.withLock { state in
            if let proc = state.ioProc {
                AudioDeviceStop(state.aggregate, proc)
                AudioDeviceDestroyIOProcID(state.aggregate, proc)
            }
            if state.aggregate != kAudioObjectUnknown { AudioHardwareDestroyAggregateDevice(state.aggregate) }
            if state.tap != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(state.tap) }
            state = Capture()
        }
        analyzer.withLock { $0.reset() }
    }

    deinit { stop() }

    // MARK: Core Audio

    struct CoreAudioError: Error, CustomStringConvertible {
        var step: String
        var status: OSStatus
        var description: String { "\(step): \(status)" }
    }

    private static func check(_ status: OSStatus, _ step: String) throws {
        if status != noErr { throw CoreAudioError(step: step, status: status) }
    }

    /// Tap globale (tutti i processi) + dispositivo aggregato privato con l'uscita predefinita + IOProc.
    private static func makeCapture(
        _ handler: @escaping @Sendable (UnsafePointer<Float>, Int, Int, Double) -> Void
    ) throws -> Capture {
        var result = Capture()
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.uuid = UUID()
        description.isPrivate = true
        description.muteBehavior = .unmuted
        try check(AudioHardwareCreateProcessTap(description, &result.tap), "tap")

        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var formatAddress = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        try check(AudioObjectGetPropertyData(result.tap, &formatAddress, 0, nil, &size, &format), "formato del tap")

        guard let output = AudioOutput.defaultDeviceID, let outputUID = deviceUID(output) else {
            throw CoreAudioError(step: "uscita predefinita", status: -1)
        }
        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "OpenTunes Spectrum",
            kAudioAggregateDeviceUIDKey: "org.opentunes.spectrum.\(UUID().uuidString)",
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [
                [kAudioSubTapDriftCompensationKey: true, kAudioSubTapUIDKey: description.uuid.uuidString]
            ],
        ]
        try check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &result.aggregate), "dispositivo aggregato")

        let rate = format.mSampleRate > 0 ? format.mSampleRate : 48_000
        // Blocco chiamato nel thread audio (coda `nil`): niente allocazioni oltre a quelle dell'analizzatore.
        // Nel dispositivo aggregato i flussi del tap vengono dopo gli ingressi dell'uscita (es. il microfono delle
        // AirPods): si legge l'ultimo buffer, che è sempre del tap. Con canali separati basta l'ultimo canale.
        try check(
            AudioDeviceCreateIOProcIDWithBlock(&result.ioProc, result.aggregate, nil) { _, input, _, _, _ in
                let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
                guard let last = buffers.last, let data = last.mData else { return }
                let channels = Int(max(1, last.mNumberChannels))
                let frames = Int(last.mDataByteSize) / MemoryLayout<Float>.size / channels
                handler(data.assumingMemoryBound(to: Float.self), frames, channels, rate)
            }, "IOProc")
        if let proc = result.ioProc { try check(AudioDeviceStart(result.aggregate, proc), "avvio") }
        return result
    }

    private static func deviceUID(_ device: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var uid: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &uid) == noErr, let value = uid?.takeRetainedValue() else {
            return nil
        }
        return value as String
    }
}

/// Dai campioni alle barre con la stessa catena di cava (`cavacore.c`):
/// FFT con finestra di Hann → bande con limiti in scala logaritmica → media delle ampiezze per banda moltiplicata per
/// `frequenza^0.85` (le alte hanno meno energia: senza correzione si muoverebbero solo i bassi) → sensibilità automatica
/// (scende del 2% quando una barra supera il massimo, sale piano altrimenti) → caduta "a gravità" → filtro integrale
/// (`noise_reduction`). Il risultato sono barre che seguono il ritmo senza tremolare.
///
/// Puro (niente Core Audio): si prova nei test con un seno. `@unchecked Sendable` per `vDSP.FFT` (una classe):
/// l'analizzatore si usa solo dentro il `Mutex` di `AudioSpectrum`. Tutti i buffer sono allocati una volta sola:
/// `process` gira nel thread audio.
struct SpectrumAnalyzer: @unchecked Sendable {
    /// 4096 campioni a 48 kHz: risoluzione di ~12 Hz, abbastanza per separare i bassi.
    static let fftSize = 4096
    /// Analisi al secondo (le barre si aggiornano a questa frequenza, come il `framerate` di cava).
    static let analysesPerSecond = 60.0
    /// Limiti predefiniti di cava.
    static let lowFrequency = 50.0
    static let highFrequency = 10_000.0
    /// `noise_reduction` di cava: più alto = barre più morbide e lente.
    static let noiseReduction = 0.77

    let bands: Int
    private(set) var levels: [Float]
    private(set) var isReceivingAudio = false

    private var ring: [Float]
    private var ringIndex = 0
    private var samplesSinceAnalysis = 0
    private var silentSamples = 0
    private let window: [Float]
    private let fft: vDSP.FFT<DSPSplitComplex>?
    private var ordered: [Float]
    private var real: [Float]
    private var imaginary: [Float]
    private var outputReal: [Float]
    private var outputImaginary: [Float]
    private var magnitudes: [Float]
    private var raw: [Double]
    /// Limiti delle bande in bin dell'FFT e peso di equalizzazione, ricalcolati se cambia la frequenza di campionamento.
    private var layout: (rate: Double, ranges: [ClosedRange<Int>], eq: [Double]) = (0, [], [])

    // Stato di cava per ogni barra.
    private var sensitivity = 1.0
    private var sensitivityInit = true
    private var peak: [Double]
    private var fall: [Double]
    private var previous: [Double]
    private var memory: [Double]

    init(bands: Int) {
        self.bands = bands
        levels = Array(repeating: 0, count: bands)
        peak = Array(repeating: 0, count: bands)
        fall = Array(repeating: 0, count: bands)
        previous = Array(repeating: 0, count: bands)
        memory = Array(repeating: 0, count: bands)
        raw = Array(repeating: 0, count: bands)
        ring = Array(repeating: 0, count: Self.fftSize)
        ordered = Array(repeating: 0, count: Self.fftSize)
        real = Array(repeating: 0, count: Self.fftSize / 2)
        imaginary = Array(repeating: 0, count: Self.fftSize / 2)
        outputReal = Array(repeating: 0, count: Self.fftSize / 2)
        outputImaginary = Array(repeating: 0, count: Self.fftSize / 2)
        magnitudes = Array(repeating: 0, count: Self.fftSize / 2)
        window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: Self.fftSize, isHalfWindow: false)
        fft = vDSP.FFT(log2n: vDSP_Length(log2(Double(Self.fftSize))), radix: .radix2, ofType: DSPSplitComplex.self)
    }

    mutating func reset() {
        for band in 0..<bands {
            levels[band] = 0
            peak[band] = 0
            fall[band] = 0
            previous[band] = 0
            memory[band] = 0
        }
        sensitivity = 1
        sensitivityInit = true
        isReceivingAudio = false
        silentSamples = 0
    }

    /// Aggiunge `frames` campioni (interleaved con `channels` canali: si mescolano in mono).
    mutating func process(_ samples: UnsafePointer<Float>, frames: Int, channels: Int, sampleRate: Double) {
        guard frames > 0, channels > 0 else { return }
        var loud = false
        for frame in 0..<frames {
            var value: Float = 0
            for channel in 0..<channels { value += samples[frame * channels + channel] }
            value /= Float(channels)
            if abs(value) > 1e-4 { loud = true }
            ring[ringIndex] = value
            ringIndex = (ringIndex + 1) % Self.fftSize
        }
        silentSamples = loud ? 0 : silentSamples + frames
        isReceivingAudio = silentSamples < Int(sampleRate)
        samplesSinceAnalysis += frames
        let hop = Int(sampleRate / Self.analysesPerSecond)
        while samplesSinceAnalysis >= hop {
            samplesSinceAnalysis -= hop
            analyze(sampleRate: sampleRate, silent: !loud)
        }
    }

    private mutating func analyze(sampleRate: Double, silent: Bool) {
        guard let fft else { return }
        if layout.rate != sampleRate { layout = Self.layout(bands: bands, sampleRate: sampleRate) }
        let n = Self.fftSize
        // Campioni in ordine cronologico, con la finestra di Hann.
        for i in 0..<n { ordered[i] = ring[(ringIndex + i) % n] * window[i] }
        // FFT non in-place: ingresso e uscita in buffer separati (in-place non è garantito su tutte le versioni).
        real.withUnsafeMutableBufferPointer { realBuffer in
            imaginary.withUnsafeMutableBufferPointer { imaginaryBuffer in
                outputReal.withUnsafeMutableBufferPointer { outRealBuffer in
                    outputImaginary.withUnsafeMutableBufferPointer { outImaginaryBuffer in
                        var split = DSPSplitComplex(realp: realBuffer.baseAddress!, imagp: imaginaryBuffer.baseAddress!)
                        var output = DSPSplitComplex(realp: outRealBuffer.baseAddress!, imagp: outImaginaryBuffer.baseAddress!)
                        ordered.withUnsafeBytes { bytes in
                            vDSP_ctoz(bytes.bindMemory(to: DSPComplex.self).baseAddress!, 2, &split, 1, vDSP_Length(n / 2))
                        }
                        fft.forward(input: split, output: &output)
                        magnitudes.withUnsafeMutableBufferPointer { vDSP.absolute(output, result: &$0) }
                    }
                }
            }
        }
        // Ampiezze riportate circa a 0…1 per un seno a piena scala.
        let scale = 4 / Double(n)
        for band in 0..<bands {
            var sum: Float = 0
            for bin in layout.ranges[band] { sum += magnitudes[bin] }
            let value = Double(sum) * scale * layout.eq[band]
            raw[band] = value.isFinite ? value : 0
        }
        smooth(silent: silent)
    }

    /// Sensibilità automatica, gravità e filtro integrale di cava (con `framerate` = `analysesPerSecond`).
    private mutating func smooth(silent: Bool) {
        let framerateMod = 66 / Self.analysesPerSecond
        let gravityMod = pow(framerateMod, 2.5) * 2 / Self.noiseReduction
        let integralMod = pow(framerateMod, 0.1)
        var overshoot = false
        for band in 0..<bands {
            var value = raw[band] * sensitivity
            // Gravità: quando il valore scende, la barra cade dal suo picco con accelerazione costante.
            if value < previous[band] {
                value = max(0, peak[band] * (1 - fall[band] * fall[band] * gravityMod))
                fall[band] += 0.028
            } else {
                peak[band] = value
                fall[band] = 0
            }
            if !value.isFinite { value = 0 }
            previous[band] = value
            // Integrale: media mobile esponenziale che toglie il tremolio.
            value = memory[band] * Self.noiseReduction / integralMod + value
            if !value.isFinite { value = 0 }
            memory[band] = value
            if value > 1 {
                overshoot = true
                value = 1
            }
            levels[band] = Float(value)
        }
        if overshoot {
            sensitivity *= 1 - 0.02 * framerateMod
            sensitivityInit = false
        } else if !silent {
            sensitivity *= 1 + 0.001 * framerateMod
            // All'avvio sale in fretta finché una barra non tocca il massimo.
            if sensitivityInit { sensitivity *= 1 + 0.1 * framerateMod }
        }
        sensitivity = sensitivity.isFinite ? min(max(sensitivity, 1e-4), 1e6) : 1
    }

    /// Limiti delle bande (bin dell'FFT) distribuiti in scala logaritmica tra `lowFrequency` e `highFrequency`,
    /// con almeno un bin per banda, e peso `frequenza_superiore^0.85 / numero di bin` (l'`eq` di cava).
    static func layout(bands: Int, sampleRate: Double) -> (rate: Double, ranges: [ClosedRange<Int>], eq: [Double]) {
        let binWidth = sampleRate / Double(fftSize)
        let ratio = highFrequency / lowFrequency
        var ranges: [ClosedRange<Int>] = []
        var eq: [Double] = []
        var nextFirst = 1
        for band in 0..<bands {
            let high = lowFrequency * pow(ratio, Double(band + 1) / Double(bands))
            let first = max(nextFirst, Int((lowFrequency * pow(ratio, Double(band) / Double(bands)) / binWidth).rounded()))
            let last = min(fftSize / 2 - 1, max(first, Int((high / binWidth).rounded()) - 1))
            ranges.append(first...last)
            nextFirst = last + 1
            eq.append(pow(high, 0.85) / Double(last - first + 1) / 100)
        }
        return (sampleRate, ranges, eq)
    }
}
