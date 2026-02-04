//
//  WindowThumbnailView.swift
//  ultraswitch
//

import SwiftUI

struct WindowThumbnailView: View {
    let windowInfo: WindowInfo
    let isSelected: Bool
    let onTap: () -> Void

    private let maxThumbnailWidth: CGFloat = 200
    private let maxThumbnailHeight: CGFloat = 150

    var body: some View {
        VStack(spacing: 8) {
            thumbnailImage
                .frame(width: maxThumbnailWidth, height: maxThumbnailHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                )
                .shadow(color: isSelected ? Color.accentColor.opacity(0.5) : Color.black.opacity(0.3),
                        radius: isSelected ? 10 : 5)
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isSelected)

            HStack(spacing: 6) {
                if let icon = windowInfo.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 16, height: 16)
                }

                Text(windowInfo.displayTitle)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: maxThumbnailWidth)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.white.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    @ViewBuilder
    private var thumbnailImage: some View {
        if let thumbnail = windowInfo.thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))

                if let icon = windowInfo.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 48, height: 48)
                        .opacity(0.5)
                } else {
                    Image(systemName: "macwindow")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                }
            }
        }
    }
}
