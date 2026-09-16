//
//  ImportContactsView.swift
//  wtm?
//
//  Replaces ImportContactsViewController: cross-references the device's
//  contacts against the app's user list and lists whoever matches.
//
//  The original matched numbers by running both sides through an AnyFormatKit
//  pattern formatter, which only worked for numbers that happened to fit the
//  pattern. Comparing the trailing digits instead handles the "+1", "1" and
//  bare-10-digit variants that actually show up in a contacts database.
//

import SwiftUI
import Contacts

// MARK: - Model

@Observable
@MainActor
final class ImportContactsModel {
    /// A contact who already has an account, ready to show in the list.
    struct Match: Identifiable {
        let id: String
        let name: String
        let phoneNumber: String
    }

    var matches: [Match] = []
    var isLoading = true
    var failed = false

    func load() async {
        defer { isLoading = false }

        // Reading the address book touches the Contacts framework, so keep it
        // off the main actor.
        let contacts = await Task.detached { () -> [ContactSnapshot] in
            PhoneContacts.getContacts(filter: .message).flatMap { contact in
                contact.phoneNumbers.compactMap { number in
                    let digits = number.value.stringValue.filter(\.isNumber)
                    guard !digits.isEmpty else { return nil }
                    let name = "\(contact.givenName) \(contact.familyName)"
                        .trimmingCharacters(in: .whitespaces)
                    return ContactSnapshot(name: name, digits: digits)
                }
            }
        }.value

        guard !contacts.isEmpty else { return }

        let users: [User]
        do {
            users = try await DatabaseManager.shared.downloadAllUsers()
        } catch {
            Log.database.error("error downloading users for contact match: \(error.localizedDescription, privacy: .public)")
            failed = true
            return
        }

        // Index accounts by their last 10 digits so "+16308706109",
        // "16308706109" and "6308706109" all collide on the same key.
        let accountsByKey = Dictionary(
            users.map { (Self.matchKey($0.phoneNumber), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let myKey = Self.matchKey(SecureStorage.phoneNumber ?? "")
        var seen = Set<String>()
        var found: [Match] = []

        for contact in contacts {
            let key = Self.matchKey(contact.digits)
            guard !key.isEmpty, key != myKey,
                  let account = accountsByKey[key],
                  seen.insert(key).inserted
            else { continue }
            found.append(Match(id: account.uid, name: contact.name, phoneNumber: account.phoneNumber))
        }

        matches = found.sorted { $0.name.sortsBefore($1.name) }
    }

    /// Last 10 digits, which is the part that identifies a subscriber
    /// regardless of how the country code was written.
    private static func matchKey(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        return String(digits.suffix(10))
    }

    /// Sendable snapshot so contact data can cross out of the detached task.
    struct ContactSnapshot: Sendable {
        let name: String
        let digits: String
    }
}

// MARK: - View

struct ImportContactsView: View {
    var onSelect: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var model = ImportContactsModel()

    var body: some View {
        ScreenScaffold(
            title: "add friends",
            subtitle: "this list shows friends you do not have added yet.",
            scrolls: false
        ) {
            Text("imported contacts")
                .font(.wtmBold(22, relativeTo: .title3))
                .foregroundStyle(Color.wtmDarkBlue)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)

            content
        }
        .task { await model.load() }
        .alert("error loading contacts", isPresented: Bindable(model).failed) {
            Button("okay") { dismiss() }
        } message: {
            Text("something went wrong when loading your contacts.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            CenteredMessage(text: "loading...", color: .wtmDarkBlue)
        } else if model.matches.isEmpty {
            CenteredMessage(
                text: "we couldn't find any users in your contacts list.\n\ndon't worry, though. we won't judge you for having no friends.",
                font: .wtmRegular(15, relativeTo: .subheadline)
            )
        } else {
            List(model.matches) { match in
                Button {
                    onSelect(match.phoneNumber)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(match.name.lowercased())
                                .font(.wtmBold(20, relativeTo: .body))
                                .foregroundStyle(Color.wtmDarkBlue)
                            Text(match.phoneNumber)
                                .font(.wtmThin(13, relativeTo: .footnote))
                                .foregroundStyle(Color.wtmSecondaryLabel)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.gray)
                    }
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.wtmBackground)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
    }
}

#Preview {
    NavigationStack {
        ImportContactsView()
    }
}
