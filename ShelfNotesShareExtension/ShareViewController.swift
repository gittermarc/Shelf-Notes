//
//  ShareViewController.swift
//  ShelfNotesShareExtension
//

import UIKit

final class ShareViewController: UIViewController {
    private let statusView = ShareExtensionStatusView()

    override func loadView() {
        view = statusView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        statusView.showLoading()

        Task { @MainActor in
            await captureShare()
        }
    }

    private func captureShare() async {
        let inputItems = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        let readResult = await ShareExtensionItemReader.read(extensionItems: inputItems)

        do {
            let payload = try ReadingSharePayloadParser.parse(
                title: readResult.title,
                text: readResult.text,
                url: readResult.url
            )
            let item = ReadingShareInboxItem(payload: payload)
            let store = try ReadingShareInboxStore()
            let result = try store.append(item)
            statusView.showSuccess(inserted: result.inserted)
            openShelfNotesInboxIfPossible()
            completeAfterDelay()
        } catch ReadingSharePayloadParserError.unsupportedURL {
            statusView.showFailure("Dieser Link wird nicht unterstützt. Shelf Notes öffnet nur sichere HTTPS-Buchlinks.")
            completeAfterDelay()
        } catch ReadingSharePayloadParserError.empty {
            statusView.showFailure("Der Share enthält keinen lesbaren Link oder Text.")
            completeAfterDelay()
        } catch {
            statusView.showFailure("Die App-Group-Inbox konnte nicht beschrieben werden.")
            completeAfterDelay()
        }
    }

    private func openShelfNotesInboxIfPossible() {
        guard let url = URL(string: "shelfnotes://share-inbox") else { return }
        extensionContext?.open(url, completionHandler: nil)
    }

    private func completeAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }
}
