import Foundation
import SwiftUI

struct AboutSection: View {
    // Placeholder until the repository is public.
    private static let sourceCode = URL(string: "https://github.com/pane-player/pane")
    private static let videoLAN = URL(string: "https://www.videolan.org/vlc/libvlc.html")
    private static let license = URL(string: "https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html")

    var body: some View {
        Section {
            LabeledContent("Version", value: version)
            if let sourceCode = Self.sourceCode {
                Link(destination: sourceCode) {
                    Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }
            if let videoLAN = Self.videoLAN {
                Link(destination: videoLAN) {
                    Label("VLCKit and libVLC by VideoLAN", systemImage: "play.rectangle")
                }
            }
            if let license = Self.license {
                Link(destination: license) {
                    Label("GNU LGPL 2.1", systemImage: "doc.text")
                }
            }
        } header: {
            Text("About")
        } footer: {
            Text("Pane plays video with VLCKit and libVLC from VideoLAN, used under the GNU Lesser General Public License, version 2.1 or later. You can get their source code from VideoLAN, and replace or modify them under the terms of that license.")
        }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        guard let build = info?["CFBundleVersion"] as? String else { return short }
        return "\(short) (\(build))"
    }
}
