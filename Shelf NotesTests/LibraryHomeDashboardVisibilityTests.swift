import Testing
@testable import Shelf_Notes

struct LibraryHomeDashboardVisibilityTests {
    @Test func dashboardShowsOnlyInHomeStateWithVisibleHeaderAndBooks() {
        #expect(LibraryView.LibraryHomeDashboardVisibility.shouldShow(
            isHomeState: true,
            isSelectionMode: false,
            bookCount: 5,
            headerStyle: .standard,
            homeMode: .compact
        ))
    }

    @Test func dashboardHidesForSelectionModeFiltersAndAppearanceSettings() {
        #expect(!LibraryView.LibraryHomeDashboardVisibility.shouldShow(
            isHomeState: false,
            isSelectionMode: false,
            bookCount: 5,
            headerStyle: .standard,
            homeMode: .compact
        ))
        #expect(!LibraryView.LibraryHomeDashboardVisibility.shouldShow(
            isHomeState: true,
            isSelectionMode: true,
            bookCount: 5,
            headerStyle: .standard,
            homeMode: .compact
        ))
        #expect(!LibraryView.LibraryHomeDashboardVisibility.shouldShow(
            isHomeState: true,
            isSelectionMode: false,
            bookCount: 0,
            headerStyle: .standard,
            homeMode: .compact
        ))
        #expect(!LibraryView.LibraryHomeDashboardVisibility.shouldShow(
            isHomeState: true,
            isSelectionMode: false,
            bookCount: 5,
            headerStyle: .hidden,
            homeMode: .compact
        ))
        #expect(!LibraryView.LibraryHomeDashboardVisibility.shouldShow(
            isHomeState: true,
            isSelectionMode: false,
            bookCount: 5,
            headerStyle: .standard,
            homeMode: .hidden
        ))
    }
}
