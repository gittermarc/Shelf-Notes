import Foundation
import Testing
@testable import Shelf_Notes

@MainActor
struct ModelContextSaveDebouncerTests {
    @Test func scheduleDoesNotSaveImmediately() {
        var saveCount = 0
        let debouncer = ModelContextSaveDebouncer(delayNanoseconds: 10_000_000)

        debouncer.schedule {
            saveCount += 1
        }

        #expect(saveCount == 0)
        #expect(debouncer.hasPendingSave)
        debouncer.cancel()
    }

    @Test func flushSavesLatestScheduledActionOnce() {
        var savedValue = 0
        let debouncer = ModelContextSaveDebouncer(delayNanoseconds: 10_000_000)

        debouncer.schedule {
            savedValue = 1
        }
        debouncer.schedule {
            savedValue = 2
        }
        debouncer.schedule {
            savedValue = 3
        }

        #expect(savedValue == 0)
        debouncer.flush()

        #expect(savedValue == 3)
        #expect(!debouncer.hasPendingSave)
    }

    @Test func cancelDropsPendingSave() {
        var saveCount = 0
        let debouncer = ModelContextSaveDebouncer(delayNanoseconds: 10_000_000)

        debouncer.schedule {
            saveCount += 1
        }
        debouncer.cancel()
        debouncer.flush()

        #expect(saveCount == 0)
        #expect(!debouncer.hasPendingSave)
    }
}
