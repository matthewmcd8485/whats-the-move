//
//  SubstatusView.swift
//  wtm?
//

import SwiftUI

struct SubstatusView: View {
    let status: Status
    var onBack: () -> Void = {}
    var onSelect: (String) -> Void = { _ in }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color("backgroundColors").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("edit status")
                    .font(.custom("SuperBasic-Bold", size: 48))
                    .foregroundStyle(Color("darkBlueOnLight"))
                    .padding(.horizontal, 23)
                    .padding(.top, 17)

                Text("pick a substatus to further personalize your rather lame profile.")
                    .font(.custom("SuperBasic-Regular", size: 15))
                    .foregroundStyle(Color("secondaryLabelColors"))
                    .padding(.horizontal, 27)
                    .padding(.top, 8)

                List {
                    ForEach(status.substatuses, id: \.self) { substatus in
                        Button {
                            onSelect(substatus)
                        } label: {
                            HStack {
                                Text(substatus)
                                    .font(.custom("SuperBasic-Regular", size: 18))
                                    .foregroundStyle(Color("darkBlueOnLight"))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.gray)
                            }
                            .frame(height: 36)
                        }
                        .listRowBackground(Color("backgroundColors"))
                        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color("backgroundColors"))
                .padding(.top, 8)
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
}

private final class SubstatusHostingController: UIHostingController<SubstatusView>, UIGestureRecognizerDelegate {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

extension SubstatusView {
    static func makeHostingController(status: Status) -> UIViewController {
        let hc = SubstatusHostingController(rootView: SubstatusView(status: status))
        hc.rootView = SubstatusView(
            status: status,
            onBack: { [weak hc] in
                hc?.navigationController?.popViewController(animated: true)
            },
            onSelect: { [weak hc] substatus in
                UserDefaults.standard.set(substatus, forKey: "substatus")
                guard let uid = SecureStorage.uid else { return }
                Task { @MainActor in
                    do {
                        try await DatabaseManager.shared.updateUserStatus(uid: uid, status: status.rawValue, substatus: substatus)
                        hc?.navigationController?.popToRootViewController(animated: true)
                    } catch {
                        print("Error updating status in Firestore: \(error)")
                    }
                }
            }
        )
        return hc
    }
}
