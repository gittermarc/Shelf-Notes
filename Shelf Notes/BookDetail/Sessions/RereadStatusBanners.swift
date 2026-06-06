//
//  RereadStatusBanners.swift
//  Shelf Notes
//

import SwiftUI

struct ActiveRereadStatusBanner: View {
    let attemptName: String
    let detailLine: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("Lese ich wieder · \(attemptName)")
                    .font(.subheadline.weight(.semibold))

                Text(detailLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
        }
        .padding(10)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct RereadReadyBanner: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "book.closed.circle.fill")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Bereit für einen neuen Durchgang")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Starte einen Re-Read, ohne deinen bisherigen Abschluss zu überschreiben.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 3)
            }
            .padding(10)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
