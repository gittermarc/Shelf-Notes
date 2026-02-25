import SwiftUI

#if canImport(PhotosUI)
import PhotosUI
#endif

// MARK: - Photos Picker Presenter

#if canImport(PhotosUI)
struct PhotoPickerPresenter: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var selection: PhotosPickerItem?

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .photosPicker(isPresented: $isPresented, selection: $selection, matching: .images)
        } else {
            // Fallback: PhotosPicker in a sheet for older iOS versions
            content
                .sheet(isPresented: $isPresented) {
                    PhotosPicker(selection: $selection, matching: .images) {
                        VStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                            Text("Fotos auswählen")
                                .font(.headline)
                        }
                        .padding(24)
                    }
                    .padding()
                }
        }
    }
}
#endif

// MARK: - Online Cover Picker Sheet

struct OnlineCoverPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let candidates: [String]
    let selectedURLString: String?
    let onSelect: (String) -> Void

    private var selectedNormalized: String {
        (selectedURLString ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Tippe ein Cover an, um es zu setzen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.top, 10)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 80), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(candidates, id: \.self) { s in
                            Button {
                                onSelect(s)
                                dismiss()
                            } label: {
                                CoverThumb(
                                    urlString: s,
                                    isSelected: selectedNormalized == s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 18)
                }
            }
            .navigationTitle("Online-Cover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Cover Thumb

struct CoverThumb: View {
    let urlString: String
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .opacity(0.12)

            if let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    BookCoverPlaceholder(cornerRadius: 10)
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(systemName: "book")
                    .opacity(0.45)
            }

            if isSelected {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(lineWidth: 2)
                    .foregroundStyle(.primary.opacity(0.35))
            }
        }
        .frame(width: 56, height: 84)
        .clipped()
    }
}
