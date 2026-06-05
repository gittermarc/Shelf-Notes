import Testing
@testable import Shelf_Notes

struct StorageModeTests {
    @Test func collectionRepairScopeMatchesPersistentStores() {
        #expect(StorageMode.cloudKit.collectionRepairScope == "cloudKit")
        #expect(StorageMode.localOnly.collectionRepairScope == "localOnly")
        #expect(StorageMode.inMemory.collectionRepairScope == nil)
    }

    @Test func modesRemainEquatableForTaskInvalidation() {
        #expect(StorageMode.cloudKit == .cloudKit)
        #expect(StorageMode.localOnly == .localOnly)
        #expect(StorageMode.inMemory == .inMemory)
        #expect(StorageMode.cloudKit != .localOnly)
        #expect(StorageMode.localOnly != .inMemory)
    }
}
