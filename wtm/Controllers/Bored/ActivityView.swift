//
//  ActivityView.swift
//  wtm?
//

import SwiftUI

struct ActivityView: View {
    var onBack: () -> Void = {}
    var onSelect: (NotificationTitle) -> Void = { _ in }

    private let categories = PickerData.collectionViewData
    private let images = CategoryImages.categoryImages

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color("backgroundColors").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("i'm bored")
                    .font(.custom("SuperBasic-Bold", size: 48))
                    .foregroundStyle(Color("darkBlueOnLight"))
                    .padding(.horizontal, 16)
                    .padding(.top, 17)

                Text("what are you in the mood for?")
                    .font(.custom("SuperBasic-Regular", size: 15))
                    .foregroundStyle(Color("secondaryLabelColors"))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(categories.enumerated()), id: \.offset) { index, label in
                            Button {
                                if let mood = NotificationTitle(integer: index) {
                                    onSelect(mood)
                                }
                            } label: {
                                tile(image: images[index], label: label)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .padding(.top, 61)

            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color("darkBlueOnLight"))
                    .frame(width: 40, height: 40)
            }
            .padding(.leading, 16)
        }
        .navigationBarHidden(true)
    }

    @ViewBuilder
    private func tile(image: UIImage?, label: String) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color("secondaryLabelColors")
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )

            Text(label)
                .font(.custom("SuperBasic-Bold", size: 18))
                .foregroundStyle(.white)
                .padding(10)
        }
        .frame(height: 165)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private final class ActivityHostingController: UIHostingController<ActivityView>, UIGestureRecognizerDelegate {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

extension ActivityView {
    static func makeHostingController() -> UIViewController {
        let hc = ActivityHostingController(rootView: ActivityView())
        hc.rootView = ActivityView(
            onBack: { [weak hc] in
                hc?.navigationController?.popViewController(animated: true)
            },
            onSelect: { [weak hc] mood in
                let next = FriendSelectionView.makeHostingController(mood: mood)
                hc?.navigationController?.pushViewController(next, animated: true)
            }
        )
        return hc
    }
}
