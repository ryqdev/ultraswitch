//
//  SwitcherView.swift
//  ultraswitch
//

import SwiftUI

struct SwitcherView: View {
    @ObservedObject var windowManager = WindowManager.shared
    let selectedIndex: Int
    let onWindowSelected: (WindowInfo) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 16)
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            if windowManager.windows.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "macwindow.on.rectangle")
                        .font(.system(size: 64))
                        .foregroundColor(.white.opacity(0.5))
                    Text("No windows available")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.7))
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(Array(windowManager.windows.enumerated()), id: \.element.id) { index, window in
                                WindowThumbnailView(
                                    windowInfo: window,
                                    isSelected: index == selectedIndex,
                                    onTap: {
                                        onWindowSelected(window)
                                    }
                                )
                                .id(window.id)
                            }
                        }
                        .padding(32)
                    }
                    .onChange(of: selectedIndex) { _, newIndex in
                        if newIndex >= 0 && newIndex < windowManager.windows.count {
                            let windowID = windowManager.windows[newIndex].id
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(windowID, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
}
