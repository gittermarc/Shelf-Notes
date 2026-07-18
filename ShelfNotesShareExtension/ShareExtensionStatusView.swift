//
//  ShareExtensionStatusView.swift
//  ShelfNotesShareExtension
//

import UIKit

final class ShareExtensionStatusView: UIView {
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func showLoading() {
        titleLabel.text = "Wird an Shelf Notes übergeben"
        detailLabel.text = "Der Inhalt wird sicher in der App-Group-Inbox gespeichert."
        activityIndicator.startAnimating()
    }

    func showSuccess(inserted: Bool) {
        titleLabel.text = inserted ? "In Shelf Notes gespeichert" : "Bereits in Shelf Notes vorgemerkt"
        detailLabel.text = "Öffne Shelf Notes, um den Inhalt einem Buch zuzuordnen."
        activityIndicator.stopAnimating()
    }

    func showFailure(_ message: String) {
        titleLabel.text = "Nicht gespeichert"
        detailLabel.text = message
        activityIndicator.stopAnimating()
    }

    private func configure() {
        backgroundColor = .systemBackground

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        detailLabel.font = .preferredFont(forTextStyle: .footnote)
        detailLabel.textColor = .secondaryLabel
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [activityIndicator, titleLabel, detailLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
