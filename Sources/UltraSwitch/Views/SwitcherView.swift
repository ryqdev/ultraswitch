//
//  SwitcherView.swift
//  ultraswitch
//

import SwiftUI

struct SwitcherView: View {
    @ObservedObject var windowManager = WindowManager.shared
    let selectedIndex: Int
    let onWindowSelected: (WindowInfo) -> Void

    private let maxThumbnailWidth: CGFloat = 200
    private let maxThumbnailHeight: CGFloat = 150
    private let itemPadding: CGFloat = 16
    private let horizontalPadding: CGFloat = 64

    private func calculateThumbnailSize(screenWidth: CGFloat, windowCount: Int) -> CGSize {
        guard windowCount > 0 else { return CGSize(width: maxThumbnailWidth, height: maxThumbnailHeight) }

        let availableWidth = screenWidth - horizontalPadding * 2
        let totalSpacing = itemPadding * CGFloat(windowCount - 1)
        let itemWidth = (availableWidth - totalSpacing) / CGFloat(windowCount)

        let finalWidth = min(itemWidth, maxThumbnailWidth)
        let scale = finalWidth / maxThumbnailWidth
        let finalHeight = maxThumbnailHeight * scale

        return CGSize(width: finalWidth, height: finalHeight)
    }

    var body: some View {
        ZStack {
            Color.clear
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
                GeometryReader { geometry in
                    let thumbnailSize = calculateThumbnailSize(
                        screenWidth: geometry.size.width,
                        windowCount: windowManager.windows.count
                    )

                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: itemPadding) {
                                ForEach(Array(windowManager.windows.enumerated()), id: \.element.id) { index, window in
                                    WindowThumbnailView(
                                        windowInfo: window,
                                        isSelected: index == selectedIndex,
                                        thumbnailSize: thumbnailSize,
                                        onTap: {
                                            onWindowSelected(window)
                                        }
                                    )
                                    .id(window.id)
                                }
                            }
                            .padding(.horizontal, horizontalPadding)
                            .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                        }
                        .onChange(of: selectedIndex) { _, newIndex in
                            if newIndex >= 0 && newIndex < windowManager.windows.count {
                                let windowID = windowManager.windows[newIndex].id
                                proxy.scrollTo(windowID, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
}
