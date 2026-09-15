//
//  ActivityView.swift
//  wtm?
//

import SwiftUI

struct ActivityView: View {
    var onSelect: (NotificationTitle) -> Void = { _ in }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScreenScaffold(
            title: "i'm bored",
            subtitle: "what are you in the mood for?",
            scrolls: false
        ) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    // Driven straight off the enum now, so the labels, images
                    // and cases can't drift out of alignment.
                    ForEach(NotificationTitle.allCases) { mood in
                        Button {
                            onSelect(mood)
                        } label: {
                            tile(mood: mood)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, WTMLayout.sideMargin)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private func tile(mood: NotificationTitle) -> some View {
        // Sized and clipped before the scrim and label go on, so both anchor to
        // the visible 165pt rather than the overflowing image's bounds.
        Image(mood.imageName)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 165)
            .clipped()
            // An even dim rather than a gradient: the label is centred, so
            // there's no one edge to darken, and the artwork varies enough in
            // brightness that a uniform floor is what keeps it readable.
            .dimmedArtwork()
            .overlay {
                Text(mood.label)
                    .font(.wtmBold(18, relativeTo: .body))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(mood.label)
    }
}

#Preview {
    NavigationStack {
        ActivityView()
    }
}
