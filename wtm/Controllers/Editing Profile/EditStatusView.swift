//
//  EditStatusView.swift
//  wtm?
//

import SwiftUI

struct EditStatusView: View {
    var onBack: () -> Void = {}
    var onSelect: (Status) -> Void = { _ in }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color("backgroundColors").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("edit status")
                    .font(.custom("SuperBasic-Bold", size: 48))
                    .foregroundStyle(Color("darkBlueOnLight"))
                    .padding(.horizontal, 23)
                    .padding(.top, 17)

                Text("what would you like to change your status to?")
                    .font(.custom("SuperBasic-Regular", size: 15))
                    .foregroundStyle(Color("secondaryLabelColors"))
                    .padding(.horizontal, 27)
                    .padding(.top, 8)

                VStack(spacing: 20) {
                    ForEach(Status.allCases) { status in
                        Button {
                            onSelect(status)
                        } label: {
                            statusRow(for: status)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 30)

                Spacer(minLength: 0)
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
    private func statusRow(for status: Status) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: status.iconName)
                .font(.system(size: 60, weight: .regular))
                .foregroundStyle(Color(status.iconColorName))
                .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(status.displayTitle)
                        .font(.custom("SuperBasic-Bold", size: 34))
                        .foregroundStyle(Color("secondaryBlack"))
                    if let trailing = status.titleTrailing {
                        Text(trailing)
                            .font(.custom("SuperBasic-Regular", size: 12))
                            .foregroundStyle(Color("secondaryBlack"))
                    }
                }
                Text(status.descriptionText)
                    .font(.custom("SuperBasic-Regular", size: 15))
                    .foregroundStyle(Color("secondaryBlack"))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color(status.backgroundColorName))
        .clipShape(RoundedRectangle(cornerRadius: 25))
    }
}

private final class EditStatusHostingController: UIHostingController<EditStatusView>, UIGestureRecognizerDelegate {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

extension EditStatusView {
    static func makeHostingController() -> UIViewController {
        let hc = EditStatusHostingController(rootView: EditStatusView())
        hc.rootView = EditStatusView(
            onBack: { [weak hc] in
                hc?.navigationController?.popViewController(animated: true)
            },
            onSelect: { [weak hc] status in
                UserDefaults.standard.set(status.rawValue, forKey: "status")
                let next = SubstatusView.makeHostingController(status: status)
                hc?.navigationController?.pushViewController(next, animated: true)
            }
        )
        return hc
    }
}

#Preview {
    EditStatusView()
}

