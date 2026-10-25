import DesignSystem
import SwiftUI

struct SleepTimerSection: View {
    @Bindable var timer: SleepTimer

    var body: some View {
        Section {
            Picker("Stop Playing", selection: $timer.setting) {
                Text("Off").tag(SleepTimer.Setting?.none)
                ForEach(SleepTimer.presets, id: \.self) { minutes in
                    Text(Duration.seconds(minutes * 60), format: .units(allowed: [.hours, .minutes], width: .abbreviated))
                        .tag(SleepTimer.Setting?.some(.minutes(minutes)))
                }
                Text("End of This Video").tag(SleepTimer.Setting?.some(.endOfItem))
            }
            .pickerStyle(.menu)
            if let fireDate = timer.fireDate {
                LabeledContent("Time Left") {
                    Text(timerInterval: Date.now...fireDate, countsDown: true)
                        .font(.indicatorValue)
                }
            }
        } header: {
            Text("Sleep Timer")
        } footer: {
            if timer.hasFired {
                Text("Paused by the sleep timer.")
            }
        }
    }
}
