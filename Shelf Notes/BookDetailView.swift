//
//  BookDetailView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//  Split from ContentView.swift on 05.01.26.
//  Apple-Books-ish redesign on 05.01.26.
//  Parallax header + Apple-style toolbar on 05.01.26.
//

import SwiftUI
import SwiftData
import StoreKit
import Combine

#if canImport(PhotosUI)
import PhotosUI
#endif

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Detail
struct BookDetailView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Bindable var book: Book

    @State var tagsText: String = ""
    @State var tagDraft: String = ""

    // Cover upload (user photo)
    #if canImport(PhotosUI)
    @State var pickedCoverItem: PhotosPickerItem?
    @State var showingPhotoPicker: Bool = false
    #endif
    @State var isUploadingCover: Bool = false
    @State var coverUploadError: String? = nil

    // Online cover picker
    @State var showingOnlineCoverPicker: Bool = false

    // NavBar title reveal after header scroll
    @State var showCompactNavTitle: Bool = false

    // ✅ Collections
    @Query(sort: \BookCollection.name, order: .forward)
    var allCollections: [BookCollection]

    // ✅ Für Top-Tags: alle Bücher laden
    @Query var allBooks: [Book]

    @State var showingNewCollectionSheet = false
    @State var showingPaywall = false

    // Apple-Books-ish UX sheets
    @State var showingNotesSheet = false
    @State var showingCollectionsSheet = false
    @State var showingRatingSheet = false

    @State var isDescriptionExpanded = false
    @State var isMoreInfoExpanded = false

    // ✅ Reading Sessions (Quick-Log + per-book list)
    @State var showingAllSessionsSheet: Bool = false

    // Toolbar actions
    @State var showingDeleteConfirm = false
    #if canImport(UIKit)
    @State var showingShareSheet = false
    @State var shareItems: [Any] = []
    #endif

    @EnvironmentObject var pro: ProManager

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                heroHeaderParallax

                QuickChipsRow(
                    overallRating: displayedOverallRating,
                    overallText: displayedOverallRatingText,
                    showsUserBadge: hasUserRating,
                    pageCount: book.pageCount,
                    publishedDate: book.publishedDate,
                    language: book.language
                )

                statusCard
                sessionsCard

                if book.status == .finished {
                    readRangeCard
                    ratingSummaryCard
                } else {
                    ratingLockedCard
                }

                notesPreviewCard
                tagsCard
                collectionsPreviewCard
                moreInfoCard
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 18) // breathing room above bottom bar
        }
        .coordinateSpace(name: "BookDetailScroll")
        .background(appBackground)
        .navigationTitle(showCompactNavTitle ? "" : "Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onPreferenceChange(HeaderMinYPreferenceKey.self) { minY in
            let threshold: CGFloat = -160
            let shouldShow = minY < threshold
            if shouldShow != showCompactNavTitle {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showCompactNavTitle = shouldShow
                }
            }
        }
        .confirmationDialog(
            "Buch wirklich löschen?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                deleteBook()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Diese Aktion kann nicht rückgängig gemacht werden.")
        }
        .safeAreaInset(edge: .bottom) {
            bottomActionBar
        }
        .sheet(isPresented: $showingNotesSheet) {
            NotesEditorSheet(notes: $book.notes) {
                _ = modelContext.saveWithDiagnostics()
            }
        }
        .sheet(isPresented: $showingCollectionsSheet) {
            CollectionsPickerSheet(
                allCollections: allCollections,
                membershipBinding: membershipBinding(for:),
                onCreateNew: { requestNewCollection() }
            )
        }
        .sheet(isPresented: $showingRatingSheet) {
            RatingEditorSheet(
                book: book,
                onReset: { resetUserRating() },
                onSave: { _ = modelContext.saveWithDiagnostics() }
            )
        }
        .sheet(isPresented: $showingAllSessionsSheet) {
            AllSessionsListSheet(book: book)
        }
        .sheet(isPresented: $showingNewCollectionSheet) {
            InlineNewCollectionSheet { name in
                createAndAttachCollection(named: name)
            }
        }
        .sheet(isPresented: $showingPaywall) {
            ProPaywallView(onPurchased: {
                showingNewCollectionSheet = true
            })
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showingShareSheet) {
            ActivityView(activityItems: shareItems)
        }
        #endif
        .sheet(isPresented: $showingOnlineCoverPicker) {
            OnlineCoverPickerSheet(
                candidates: book.coverURLCandidates,
                selectedURLString: book.thumbnailURL,
                onSelect: { s in
                    Task { @MainActor in
                        await CoverThumbnailer.applyRemoteCover(urlString: s, to: book, modelContext: modelContext)
                    }
                }
            )
        }
        #if canImport(PhotosUI)
        .modifier(PhotoPickerPresenter(isPresented: $showingPhotoPicker, selection: $pickedCoverItem))
        #endif
        .onAppear {
            tagsText = book.tags.joined(separator: ", ")
            tagDraft = ""
        }
        #if canImport(PhotosUI)
        .onChange(of: pickedCoverItem) { _, newValue in
            handlePickedCoverItem(newValue)
        }
        #endif
        .onDisappear {
            _ = modelContext.saveWithDiagnostics()
        }
    }
}
