//
//  ContentView.swift
//  Pane
//
//  Created by Allan on 20/10/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        #if DEBUG
        PlaybackDebugView()
        #else
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        #endif
    }
}

#Preview {
    ContentView()
}
