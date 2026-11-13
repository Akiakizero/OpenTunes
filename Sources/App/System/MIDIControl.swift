// SPDX-License-Identifier: GPL-3.0-or-later

import CoreMIDI
import Foundation
import Observation
import os

/// Azioni che si possono assegnare a un pad o a una manopola MIDI.
enum MIDIAction: String, CaseIterable, Identifiable, Sendable {
    case playPause, next, previous, love, volumeUp, volumeDown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .playPause: String(localized: "Play/pausa")
        case .next: String(localized: "Brano successivo")
        case .previous: String(localized: "Brano precedente")
        case .love: String(localized: "Love")
        case .volumeUp: String(localized: "Alza il volume")
        case .volumeDown: String(localized: "Abbassa il volume")
        }
    }
}

/// Un messaggio MIDI che può attivare un'azione: nota premuta o Control Change con valore > 0.
struct MIDITrigger: Equatable, Sendable {
    enum Kind: Int, Sendable { case note = 1, controlChange = 2 }
    var kind: Kind
    var number: Int

    /// Codice salvato nelle preferenze (`kind << 8 | number`).
    var code: Int { kind.rawValue << 8 | number }

    init(kind: Kind, number: Int) {
        self.kind = kind
        self.number = number
    }

    init?(code: Int) {
        guard let kind = Kind(rawValue: code >> 8) else { return nil }
        self.init(kind: kind, number: code & 0xFF)
    }

    var label: String {
        switch kind {
        case .note: String(localized: "Nota \(number)")
        case .controlChange: String(localized: "CC \(number)")
        }
    }

    /// Da una parola UMP di tipo 2 (voce di canale MIDI 1.0): `0x2g sn dd vv`. Note-on con velocità 0 = note-off.
    static func parse(ump word: UInt32) -> MIDITrigger? {
        guard word >> 28 == 0x2 else { return nil }
        let status = (word >> 16) & 0xF0
        let data1 = Int((word >> 8) & 0x7F)
        let data2 = Int(word & 0x7F)
        switch status {
        case 0x90 where data2 > 0: return MIDITrigger(kind: .note, number: data1)
        case 0xB0 where data2 > 0: return MIDITrigger(kind: .controlChange, number: data1)
        default: return nil
        }
    }
}

/// Controllo da MIDI (es. i pad di un MPD218): ascolta tutte le sorgenti MIDI collegate e lancia le azioni
/// assegnate nelle impostazioni. Con «Impara» il prossimo pad premuto viene assegnato all'azione scelta.
@MainActor
@Observable
final class MIDIControl {
    private let model: AppModel
    @ObservationIgnored private var client = MIDIClientRef()
    @ObservationIgnored private var port = MIDIPortRef()
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []
    @ObservationIgnored private let logger = Logger(subsystem: "org.opentunes.OpenTunes", category: "MIDI")
    /// Azione in attesa di un pad («Impara»).
    var learning: MIDIAction?
    /// Ultimo messaggio ricevuto (per le impostazioni).
    private(set) var lastTrigger: MIDITrigger?
    private(set) var sourceNames: [String] = []

    init(model: AppModel) {
        self.model = model
    }

    func start() {
        tasks.append(observeChanges({ [weak self] in self?.model.settings.midiEnabled ?? false }) { [weak self] enabled in
            if enabled { self?.connect() } else { self?.disconnect() }
        })
    }

    func trigger(for action: MIDIAction) -> MIDITrigger? {
        model.settings.midiMappings[action.rawValue].flatMap(MIDITrigger.init(code:))
    }

    func clear(_ action: MIDIAction) {
        model.settings.midiMappings[action.rawValue] = nil
    }

    private func connect() {
        guard client == 0 else { return }
        let status = MIDIClientCreateWithBlock("OpenTunes" as CFString, &client) { [weak self] notification in
            // Dispositivi collegati o scollegati: si ricollegano le sorgenti.
            guard notification.pointee.messageID == .msgSetupChanged else { return }
            Task { @MainActor in self?.connectSources() }
        }
        guard status == noErr else {
            logger.error("client MIDI non creato: \(status)")
            return
        }
        let portStatus = MIDIInputPortCreateWithProtocol(client, "OpenTunes Input" as CFString, ._1_0, &port) { [weak self] list, _ in
            // Thread di CoreMIDI: si estraggono i messaggi e si passa al main actor.
            var triggers: [MIDITrigger] = []
            for packet in list.unsafeSequence() {
                let words = MIDIEventPacket.WordCollection(packet)
                triggers.append(contentsOf: words.compactMap(MIDITrigger.parse(ump:)))
            }
            guard !triggers.isEmpty else { return }
            Task { @MainActor in triggers.forEach { self?.handle($0) } }
        }
        guard portStatus == noErr else {
            logger.error("porta MIDI non creata: \(portStatus)")
            return
        }
        connectSources()
    }

    private func connectSources() {
        guard port != 0 else { return }
        var names: [String] = []
        for index in 0..<MIDIGetNumberOfSources() {
            let source = MIDIGetSource(index)
            MIDIPortConnectSource(port, source, nil)
            var name: Unmanaged<CFString>?
            if MIDIObjectGetStringProperty(source, kMIDIPropertyDisplayName, &name) == noErr, let value = name?.takeRetainedValue() {
                names.append(value as String)
            }
        }
        sourceNames = names
    }

    private func disconnect() {
        if port != 0 { MIDIPortDispose(port) }
        if client != 0 { MIDIClientDispose(client) }
        port = 0
        client = 0
        sourceNames = []
        learning = nil
    }

    private func handle(_ trigger: MIDITrigger) {
        lastTrigger = trigger
        if let action = learning {
            // Un pad fa una cosa sola: lo si toglie dalle altre azioni.
            for (key, code) in model.settings.midiMappings where code == trigger.code { model.settings.midiMappings[key] = nil }
            model.settings.midiMappings[action.rawValue] = trigger.code
            learning = nil
            return
        }
        guard model.settings.midiEnabled,
            let action = MIDIAction.allCases.first(where: { model.settings.midiMappings[$0.rawValue] == trigger.code })
        else { return }
        switch action {
        case .playPause: model.perform(.playPause)
        case .next: model.perform(.next)
        case .previous: model.perform(.previous)
        case .love: model.toggleLove(feedback: true)
        case .volumeUp: model.changeVolume(by: SystemVolume.step)
        case .volumeDown: model.changeVolume(by: -SystemVolume.step)
        }
    }
}
