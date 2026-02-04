//
//  WindowThumbnailView.swift
//  ultraswitch
//

import SwiftUI

struct WindowThumbnailView: View {
    let windowInfo: WindowInfo
    let isSelected: Bool
    let thumbnailSize: CGSize
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            thumbnailImage
                .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.3), lineWidth: isSelected ? 3 : 1)
                )
                .shadow(color: Color.black.opacity(0.5), radius: 8)
                .scaleEffect(isSelected ? 1.05 : 1.0)

            HStack(spacing: 6) {
                if let icon = windowInfo.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                }

                Text(windowInfo.displayTitle)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 2)
            }
            .frame(maxWidth: thumbnailSize.width)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.3), radius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
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
