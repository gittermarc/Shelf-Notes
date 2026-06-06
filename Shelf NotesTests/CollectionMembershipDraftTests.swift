import Foundation
import Testing
@testable import Shelf_Notes

struct CollectionMembershipDraftTests {

    @Test func initializesSelectionFromExistingCollectionIDs() {
        let first = UUID()
        let second = UUID()

        let draft = CollectionMembershipDraft(collectionIDs: [first, second, first])

        #expect(draft.contains(first))
        #expect(draft.contains(second))
        #expect(draft.selectedCollectionIDs == Set([first, second]))
        #expect(!draft.hasChanges)
        #expect(draft.change.isEmpty)
    }

    @Test func settingMembershipOnlyUpdatesDraftState() {
        let kept = UUID()
        let added = UUID()
        var draft = CollectionMembershipDraft(collectionIDs: [kept])

        draft.setMembership(true, for: added)
        draft.setMembership(false, for: kept)

        #expect(!draft.contains(kept))
        #expect(draft.contains(added))
        #expect(draft.originalCollectionIDs == Set([kept]))
        #expect(draft.selectedCollectionIDs == Set([added]))
    }

    @Test func repeatedTogglesKeepTheFinalSelectionState() {
        let collectionID = UUID()
        var draft = CollectionMembershipDraft(collectionIDs: [])

        draft.toggleMembership(for: collectionID)
        draft.toggleMembership(for: collectionID)
        draft.toggleMembership(for: collectionID)

        #expect(draft.contains(collectionID))
        #expect(draft.change.addedCollectionIDs == Set([collectionID]))
        #expect(draft.change.removedCollectionIDs.isEmpty)
    }

    @Test func diffSeparatesAddedAndRemovedCollectionIDs() {
        let kept = UUID()
        let removed = UUID()
        let added = UUID()
        var draft = CollectionMembershipDraft(collectionIDs: [kept, removed])

        draft.setMembership(false, for: removed)
        draft.setMembership(true, for: added)

        #expect(draft.hasChanges)
        #expect(draft.change.addedCollectionIDs == Set([added]))
        #expect(draft.change.removedCollectionIDs == Set([removed]))
    }

    @Test func revertingToOriginalSelectionProducesNoChange() {
        let collectionID = UUID()
        var draft = CollectionMembershipDraft(collectionIDs: [collectionID])

        draft.setMembership(false, for: collectionID)
        draft.setMembership(true, for: collectionID)

        #expect(!draft.hasChanges)
        #expect(draft.change.isEmpty)
    }

    @Test func markAppliedTurnsCurrentSelectionIntoNewBaseline() {
        let original = UUID()
        let added = UUID()
        var draft = CollectionMembershipDraft(collectionIDs: [original])

        draft.setMembership(true, for: added)
        draft.markApplied()

        #expect(!draft.hasChanges)
        #expect(draft.originalCollectionIDs == Set([original, added]))
        #expect(draft.selectedCollectionIDs == Set([original, added]))
        #expect(draft.change.isEmpty)
    }
}
