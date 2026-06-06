import Foundation

struct CollectionMembershipDraft: Equatable {
    private(set) var originalCollectionIDs: Set<UUID>
    private(set) var selectedCollectionIDs: Set<UUID>

    init(originalCollectionIDs: Set<UUID>, selectedCollectionIDs: Set<UUID>? = nil) {
        self.originalCollectionIDs = originalCollectionIDs
        self.selectedCollectionIDs = selectedCollectionIDs ?? originalCollectionIDs
    }

    init(collectionIDs: [UUID]) {
        let ids = Set(collectionIDs)
        self.init(originalCollectionIDs: ids)
    }

    static var empty: CollectionMembershipDraft {
        CollectionMembershipDraft(originalCollectionIDs: [])
    }

    var hasChanges: Bool {
        originalCollectionIDs != selectedCollectionIDs
    }

    var change: CollectionMembershipDraftChange {
        CollectionMembershipDraftChange(
            addedCollectionIDs: selectedCollectionIDs.subtracting(originalCollectionIDs),
            removedCollectionIDs: originalCollectionIDs.subtracting(selectedCollectionIDs)
        )
    }

    func contains(_ collectionID: UUID) -> Bool {
        selectedCollectionIDs.contains(collectionID)
    }

    mutating func setMembership(_ isMember: Bool, for collectionID: UUID) {
        if isMember {
            selectedCollectionIDs.insert(collectionID)
        } else {
            selectedCollectionIDs.remove(collectionID)
        }
    }

    mutating func toggleMembership(for collectionID: UUID) {
        setMembership(!contains(collectionID), for: collectionID)
    }

    mutating func reset(to collectionIDs: [UUID]) {
        let ids = Set(collectionIDs)
        originalCollectionIDs = ids
        selectedCollectionIDs = ids
    }

    mutating func markApplied() {
        originalCollectionIDs = selectedCollectionIDs
    }
}

struct CollectionMembershipDraftChange: Equatable {
    let addedCollectionIDs: Set<UUID>
    let removedCollectionIDs: Set<UUID>

    var isEmpty: Bool {
        addedCollectionIDs.isEmpty && removedCollectionIDs.isEmpty
    }
}
