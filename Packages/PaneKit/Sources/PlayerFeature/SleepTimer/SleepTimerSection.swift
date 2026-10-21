import DesignSystem
import SwiftUI

struct SleepTimerSection: View {
    @Bindable var timer: SleepTimer

    var body: some View {
        OptionsSection(title: "Sleep Timer") {
            HStack {
                Picker("Sleep Timer", selection: $timer.setting) {
                    Text("Off").tag(SleepTimer.Setting?.none)
                    ForEach(SleepTimer.presets, id: \.self) { minutes in
                        Text(Duration.seconds(minutes * 60), format: .units(allowed: [.hours, .minutes], width: .abbreviated))
                            .tag(SleepTimer.Setting?.some(.minutes(minutes)))
                    }
                    Text("End of This Video").tag(SleepTimer.Setting?.some(.endOfItem))
                }
                .pickerStyle(.menu)
                .labelsHidden()
                Spacer()
                if let fireDate = timer.fireDate {
                    Text(timerInterval: Date.now...fireDate, countsDown: true)
                        .font(.indicatorValue)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Time left")
                }
            }
            if timer.hasFired {
                Text("Paused by the sleep timer.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
