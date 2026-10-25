import Domain
import SwiftUI

struct ChapterSection: View {
    let model: PlayerModel

    var body: some View {
        Section("Chapters") {
            ForEach(model.chapters) { chapter in
                ChapterRow(chapter: chapter, isCurrent: model.currentChapter == chapter, onSelect: model.seek(toChapter:))
            }
        }
    }
}
