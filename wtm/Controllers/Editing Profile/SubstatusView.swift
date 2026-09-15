//
//  SubstatusView.swift
//  wtm?
//

import SwiftUI

struct SubstatusView: View {
    let status: Status
    /// Called once the substatus has been saved, so the caller can unwind the
    /// whole editing flow rather than popping a single screen.
    var onFinished: () -> Void = {}

    @State private var isSaving = false
    @State private var saveFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("edit status")
                .font(.wtmLargeTitle)
                .foregroundStyle(Color.wtmDarkBlue)
                .accessibilityAddTraits(.isHeader)

            Text("pick a substatus to further personalize your rather lame profile.")
                .font(.wtmSubtitle)
                .foregroundStyle(Color.wtmSecondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            List {
                ForEach(status.substatuses, id: \.self) { substatus in
                    Button {
                        save(substatus)
                    } label: {
                        HStack {
                            Text(substatus)
                                .font(.wtmRegular(18, relativeTo: .body))
                                .foregroundStyle(Color.wtmDarkBlue)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.gray)
                        }
                        .frame(minHeight: 36)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.wtmBackground)
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .padding(.top, 8)
        }
        .padding(.horizontal, WTMLayout.sideMargin)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.wtmBackground)
        // Block a second tap while the write is in flight; the old version let
        // you queue up several.
        .disabled(isSaving)
        .alert("couldn't save", isPresented: $saveFailed) {
            Button("okay", role: .cancel) {}
        } message: {
            Text("we couldn't update your status. please try again.")
        }
    }

    private func save(_ substatus: String) {
        guard let uid = SecureStorage.uid else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await DatabaseManager.shared.updateUserStatus(
                    uid: uid,
                    status: status.rawValue,
                    substatus: substatus
                )
                UserDefaults.standard.set(substatus, forKey: "substatus")
                UserDefaults.standard.set(status.rawValue, forKey: "status")
                onFinished()
            } catch {
                Log.database.error("Failed to update status: \(error.localizedDescription, privacy: .public)")
                saveFailed = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        SubstatusView(status: .available)
    }
}
