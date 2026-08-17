import SwiftUI
import UIKit

/// The number pad, drawn as an ordinary view.
///
/// **This is not a keyboard.** It is not a keyboard extension and it is not a
/// `UITextField.inputView` — both of those still go through keyboard
/// presentation, which is the whole thing this view exists to delete. iOS will
/// not raise a keyboard while a modal presentation animation is in flight, so
/// the sheet's duration is *added* to the wait rather than hidden inside it
/// (docs/TODO.md items 11 and 12). Nothing here is raised, so nothing animates
/// and nothing is waited for: the pad is on screen in the same frame the sheet
/// is.
///
/// It types by handing characters back to whoever owns the value. There is no
/// text field behind it and no first responder involved in a tap.
struct NumberPad: View {

    /// The region's decimal separator, not a hardcoded `.`. Half the world
    /// types `1,5`, and a pad whose key disagrees with `NumberInput`'s idea of
    /// the separator produces a silently wrong number rather than an error.
    let separator: String
    /// Called with the character a key stands for.
    let insert: (String) -> Void
    /// Called with nothing to say, which is why it is separate from `insert`.
    let delete: () -> Void

    var body: some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            GridRow { digit("1"); digit("2"); digit("3") }
            GridRow { digit("4"); digit("5"); digit("6") }
            GridRow { digit("7"); digit("8"); digit("9") }
            GridRow {
                key(label: separatorLabel, action: { insert(separator) }) {
                    Text(separator)
                }
                digit("0")
                key(label: "Delete", action: delete) {
                    Image(systemName: "delete.backward")
                }
            }
        }
        .padding(6)
        // Same colour the form behind it uses for its own background, so the
        // pad reads as part of the sheet rather than as something that arrived
        // over the top of it — which is the honest description of what it is.
        .background(Color(uiColor: .systemGroupedBackground))
        // Every key is labelled individually below; this stops VoiceOver
        // reading the grid itself as one more thing to swipe past.
        .accessibilityElement(children: .contain)
    }

    /// What the separator key is called out loud. The character alone is read
    /// as "period" or "comma", which says what it looks like rather than what
    /// it does.
    private var separatorLabel: String {
        "Decimal separator"
    }

    private func digit(_ value: String) -> some View {
        key(label: value, action: { insert(value) }) { Text(value) }
    }

    private func key<Content: View>(
        label: String,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            content()
                // Fixed, like the system keypad's own glyphs, and for the same
                // reason item 11 fixed the chevrons and the card's +: the key
                // is a fixed frame, so a text style grows the label out of it.
                // A pad is not body text — 25pt is already far larger than
                // anything else on this screen, and at AX5 a grid that scaled
                // would push the fields it is for off the top of the sheet.
                .font(.system(size: 25))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(.rect)
        }
        .buttonStyle(KeyStyle())
        .accessibilityLabel(label)
    }
}

/// A key that visibly goes down when you press it.
///
/// `.plain` would draw nothing at all, and a pad whose keys do not react is
/// the one place a user cannot tell "nothing happened" from "the app is
/// stuck". This is feedback, not animation: it is a state change under the
/// thumb, with nothing to wait for.
private struct KeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                    ? Color(uiColor: .systemGray3)
                    : Color(uiColor: .secondarySystemGroupedBackground),
                in: .rect(cornerRadius: 8)
            )
    }
}

// MARK: - The hardware keyboard

/// Catches hardware key presses without raising anything.
///
/// Every simulator, every iPad with a keyboard and every Mac running this app
/// has a real keyboard, and until item 12 the amount fields were `TextField`s
/// that got it for free. Drawing our own pad takes the text field away, so a
/// typed `1` would land nowhere — which would make the app worse to develop
/// and test than it was before.
///
/// A `UIKeyCommand` on a first responder is the way back that does not undo
/// the item: key commands raise no keyboard and reserve no space. The view is
/// zero-sized on purpose — it is a place in the responder chain, not something
/// to look at — and it steps aside (`isActive == false`) while the name field
/// has the real keyboard, so typed letters go where the caret is.
struct HardwareKeys: UIViewRepresentable {

    /// Whether the pad, rather than the name field, should receive keys.
    let isActive: Bool
    /// Bumped by the sheet whenever the user does something that means "digits
    /// go to the pad now" — tapping an amount row, stepping with a chevron,
    /// switching group.
    ///
    /// The responder is taken back on this changing and on nothing else.
    /// Taking it on every SwiftUI update instead was a race waiting to be
    /// lost: UIKit hands the responder to a tapped field before SwiftUI has
    /// propagated the state that says so, and any update landing in that
    /// window — a keyboard changing the safe area re-evaluates this sheet's
    /// body — would snatch it straight back and dismiss the keyboard the user
    /// had just asked for.
    let claim: Int
    let insert: (String) -> Void
    let delete: () -> Void
    let submit: () -> Void
    let next: () -> Void

    func makeUIView(context: Context) -> KeyCatcher {
        let view = KeyCatcher()
        apply(to: view)
        return view
    }

    func updateUIView(_ view: KeyCatcher, context: Context) {
        apply(to: view)
    }

    private func apply(to view: KeyCatcher) {
        view.insert = insert
        view.delete = delete
        view.submit = submit
        view.advance = next
        view.isActive = isActive
        view.claim = claim
        view.syncResponder()
    }

    final class KeyCatcher: UIView {
        var insert: ((String) -> Void)?
        var delete: (() -> Void)?
        var submit: (() -> Void)?
        /// Not `next`: `UIResponder` already has one, and it is the chain.
        var advance: (() -> Void)?
        var isActive = true
        var claim = 0
        /// The last claim acted on. Starts lower than any claim the sheet can
        /// pass, so being added to the window counts as the first one.
        private var claimed = -1

        override var canBecomeFirstResponder: Bool { isActive }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            syncResponder()
        }

        /// Take the responder when the pad is claimed, and give it up the
        /// moment something else is being typed into.
        ///
        /// Giving up is unconditional; taking is not. UIKit hands the
        /// responder to the name field on its own when it is tapped, and this
        /// is what returns it afterwards — so dismissing the real keyboard
        /// leaves the hardware one still typing digits, without this view
        /// competing for the responder every time the layout changes.
        func syncResponder() {
            guard window != nil else { return }
            guard isActive else {
                if isFirstResponder { resignFirstResponder() }
                return
            }
            guard claim != claimed else { return }
            claimed = claim
            if !isFirstResponder { becomeFirstResponder() }
        }

        override var keyCommands: [UIKeyCommand]? {
            // The separator is not here: `1,5` and `1.5` both have to work
            // whatever the region is, and both are covered by sending the
            // pressed character straight through to `NumberInput.appending`,
            // which drops the one that isn't this locale's separator.
            var commands = (0...9).map { digit in
                UIKeyCommand(input: "\(digit)", modifierFlags: [], action: #selector(typed))
            }
            commands += [".", ","].map {
                UIKeyCommand(input: $0, modifierFlags: [], action: #selector(typed))
            }
            commands.append(
                UIKeyCommand(input: "\u{8}", modifierFlags: [], action: #selector(backspace))
            )
            commands.append(
                UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(returned))
            )
            commands.append(
                UIKeyCommand(input: "\t", modifierFlags: [], action: #selector(tabbed))
            )
            for command in commands {
                // Otherwise the system eats Tab and Return for its own focus
                // handling before the app sees them.
                command.wantsPriorityOverSystemBehavior = true
            }
            return commands
        }

        @objc private func typed(_ command: UIKeyCommand) {
            guard let input = command.input else { return }
            insert?(input)
        }

        @objc private func backspace() { delete?() }
        @objc private func returned() { submit?() }
        @objc private func tabbed() { advance?() }
    }
}

#Preview {
    VStack {
        Spacer()
        NumberPad(separator: ".", insert: { _ in }, delete: {})
    }
}
