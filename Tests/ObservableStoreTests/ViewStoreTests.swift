//
//  ViewStoreTests.swift
//  
//
//  Created by Gordon Brander on 9/12/22.
//

import XCTest
import Combine
import SwiftUI
@testable import ObservableStore

class TestsViewStore: XCTestCase {
    enum ParentAction: Hashable {
        case child(ChildAction)
        case setText(String)
    }

    struct ParentModel: ModelProtocol {
        var child = ChildModel(text: "")
        var edits: Int = 0

        static func update(
            state: ParentModel,
            action: ParentAction,
            environment: Void
        ) -> Update<ParentModel> {
            switch action {
            case .child(let action):
                return ParentChildCursor.update(
                    state: state,
                    action: action,
                    environment: ()
                )
            case .setText(let text):
                var next = ParentChildCursor.update(
                    state: state,
                    action: .setText(text),
                    environment: ()
                )
                next.state.edits = next.state.edits + 1
                return next
            }
        }
    }

    enum ChildAction: Hashable {
        case setText(String)
    }

    struct ChildModel: ModelProtocol {
        var text: String

        static func update(
            state: ChildModel,
            action: ChildAction,
            environment: Void
        ) -> Update<ChildModel> {
            switch action {
            case .setText(let string):
                var model = state
                model.text = string
                return Update(state: model)
                    .animation(.default)
            }
        }
    }

    struct ParentChildCursor: CursorProtocol {
        static func get(state: ParentModel) -> ChildModel {
            state.child
        }

        static func set(state: ParentModel, inner: ChildModel) -> ParentModel {
            var model = state
            model.child = inner
            return model
        }

        static func tag(_ action: ChildAction) -> ParentAction {
            switch action {
            case .setText(let string):
                return .setText(string)
            }
        }
    }

    struct SimpleView: View {
        @Binding var text: String

        var body: some View {
            Text(text)
        }
    }

    func testViewStoreCursor() throws {
        let store = Store(
            state: ParentModel(),
            environment: ()
        )

        let viewStore: ViewStore<ChildModel> = ViewStore(
            store: store,
            cursor: ParentChildCursor.self
        )

        viewStore.send(.setText("Foo"))
        viewStore.send(.setText("Bar"))
        XCTAssertEqual(
            viewStore.state.text,
            "Bar"
        )
        XCTAssertEqual(
            store.state.child.text,
            "Bar"
        )
        XCTAssertEqual(
            store.state.edits,
            2
        )
    }

    func testViewStoreGetTag() throws {
        let store = Store(
            state: ParentModel(),
            environment: ()
        )

        let viewStore: ViewStore<ChildModel> = ViewStore(
            store: store,
            cursor: ParentChildCursor.self
        )

        viewStore.send(.setText("Foo"))
        viewStore.send(.setText("Bar"))
        XCTAssertEqual(
            viewStore.state.text,
            "Bar"
        )
        XCTAssertEqual(
            store.state.child.text,
            "Bar"
        )
        XCTAssertEqual(
            store.state.edits,
            2
        )
    }

    /// Test creating binding from a ViewStore
    func testViewStoreBinding() throws {
        let store = Store(
            state: ParentModel(),
            environment: ()
        )

        let viewStore: ViewStore<ChildModel> = ViewStore(
            store: store,
            cursor: ParentChildCursor.self
        )

        let binding = Binding(
            store: viewStore,
            get: \.text,
            tag: ChildAction.setText
        )

        let view = SimpleView(text: binding)

        view.text = "Foo"
        view.text = "Bar"

        XCTAssertEqual(
            viewStore.state.text,
            "Bar"
        )
        XCTAssertEqual(
            store.state.child.text,
            "Bar"
        )
        XCTAssertEqual(
            store.state.edits,
            2
        )
    }

    func testCursorUpdateTransaction() throws {
        let update = ParentChildCursor.update(
            state: ParentModel(),
            action: ChildAction.setText("Foo"),
            environment: ()
        )
        XCTAssertNotNil(
            update.transaction,
            "Transaction is preserved by cursor"
        )
    }
}
