// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Charts
import MediaCore
import SwiftUI

/// Statistiche di ascolto locali: totali, grafico settimanale e giornaliero, top artisti, brani e player.
/// Tutto viene dalla cronologia sul Mac: niente account e niente rete.
struct StatisticsView: View {
    let model: AppModel

    enum Period: String, CaseIterable, Identifiable {
        case week, month, year, all
        var id: String { rawValue }

        var label: LocalizedStringKey {
            switch self {
            case .week: "7 giorni"
            case .month: "30 giorni"
            case .year: "12 mesi"
            case .all: "Sempre"
            }
        }

        var seconds: TimeInterval? {
            switch self {
            case .week: 7 * 86_400
            case .month: 30 * 86_400
            case .year: 365 * 86_400
            case .all: nil
            }
        }
    }

    @State private var period: Period = .week
    @State private var stats: ListeningStats?
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.l) {
                Picker("Periodo", selection: $period) {
                    ForEach(Period.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                if !model.settings.statisticsEnabled {
                    ContentUnavailableView(
                        "Statistiche spente", systemImage: "chart.bar.xaxis",
                        description: Text("Accendile in Impostazioni › Funzioni."))
                } else if let stats, stats.totalPlays > 0 || stats.weeks.contains(where: { $0.plays > 0 }) {
                    content(stats)
                } else if loading {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    ContentUnavailableView(
                        "Ancora nessun ascolto", systemImage: "music.note.list",
                        description: Text("Le statistiche si riempiono mentre ascolti musica."))
                }
            }
            .padding(DesignSystem.Spacing.l)
        }
        .frame(minWidth: DesignSystem.Size.discoverWindow.width, minHeight: DesignSystem.Size.discoverWindow.height)
        .task(id: period) { await reload() }
        .task(id: model.store.trackChangeCount) { await reload() }
    }

    private func reload() async {
        loading = true
        stats = await model.statistics(period: period.seconds)
        loading = false
    }

    @ViewBuilder
    private func content(_ stats: ListeningStats) -> some View {
        HStack(spacing: DesignSystem.Spacing.m) {
            tile("Ascolti", value: "\(stats.totalPlays)", symbol: "play.circle")
            tile("Ore", value: (stats.totalMinutes / 60).formatted(.number.precision(.fractionLength(1))), symbol: "clock")
            tile("Artisti", value: "\(stats.distinctArtists)", symbol: "person.2")
        }

        section("Ultime settimane") {
            Chart(stats.weeks) { bucket in
                BarMark(x: .value("Settimana", bucket.start, unit: .weekOfYear), y: .value("Ascolti", bucket.plays))
                    .foregroundStyle(.tint)
                    .cornerRadius(DesignSystem.Radius.tiny)
            }
            .chartXAxis { AxisMarks(values: .stride(by: .weekOfYear)) { AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
            .frame(height: 140)
        }

        section("Ultimi 7 giorni") {
            Chart(stats.days) { bucket in
                BarMark(x: .value("Giorno", bucket.start, unit: .day), y: .value("Minuti", bucket.minutes))
                    .foregroundStyle(.tint.opacity(0.7))
                    .cornerRadius(DesignSystem.Radius.tiny)
            }
            .chartXAxis { AxisMarks(values: .stride(by: .day)) { AxisValueLabel(format: .dateTime.weekday(.abbreviated)) } }
            .chartYAxisLabel("minuti")
            .frame(height: 110)
        }

        HStack(alignment: .top, spacing: DesignSystem.Spacing.l) {
            section("Top artisti") { ranking(stats.topArtists) }
            section("Top brani") { ranking(stats.topTracks) }
        }

        if stats.players.count > 1 {
            section("Player") {
                ranking(stats.players.map { ListeningStats.Ranked(name: PlayerApp.resolve(bundleID: $0.name).name, detail: nil, plays: $0.plays) })
            }
        }
    }

    private func tile(_ title: LocalizedStringKey, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            Label(title, systemImage: symbol)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.m)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: DesignSystem.Radius.medium))
        .accessibilityElement(children: .combine)
    }

    private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s) {
            Text(title).font(DesignSystem.Typography.sectionHeader).foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func ranking(_ items: [ListeningStats.Ranked]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            ForEach(Array(items.prefix(8).enumerated()), id: \.element.id) { index, item in
                HStack(spacing: DesignSystem.Spacing.s) {
                    Text("\(index + 1)")
                        .font(DesignSystem.Typography.time)
                        .foregroundStyle(.tertiary)
                        .frame(width: DesignSystem.Spacing.l, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.name).font(DesignSystem.Typography.subtitle).lineLimit(1)
                        if let detail = item.detail {
                            Text(detail).font(DesignSystem.Typography.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: DesignSystem.Spacing.s)
                    Text("\(item.plays)")
                        .font(DesignSystem.Typography.time)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Finestra «Statistiche», creata alla prima apertura.
@MainActor
final class StatisticsWindowController {
    private let model: AppModel
    private var window: NSWindow?

    init(model: AppModel) {
        self.model = model
    }

    func show() {
        let window = window ?? {
            let window = NSWindow(contentViewController: NSHostingController(rootView: StatisticsView(model: model)))
            window.title = String(localized: "Statistiche")
            window.subtitle = String(localized: "Ascolti su questo Mac")
            window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.setContentSize(DesignSystem.Size.discoverWindow)
            window.center()
            window.setFrameAutosaveName("Statistics")
            self.window = window
            return window
        }()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}

#Preview("Statistiche") {
    StatisticsView(model: .preview())
}
