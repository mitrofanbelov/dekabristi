import Foundation
import SaveCore
import Social
import UniformTypeIdentifiers

final class LinkShareViewController: SLComposeServiceViewController {
    private let sessionStore = AuthSessionStore()
    private let pendingSharedLinkStore = PendingSharedLinkStore()
    private lazy var apiClient = APIClient(
        baseURL: SharedAppConfiguration.apiBaseURL(),
        sessionStore: sessionStore
    )

    override func isContentValid() -> Bool {
        if firstSupportedItemProvider() != nil {
            return true
        }

        guard let contentText = normalizedOptionalText(contentText) else {
            return false
        }

        return (try? LinkInputNormalizer.normalize(contentText)) != nil
    }

    override func didSelectPost() {
        Task { @MainActor in
            do {
                let sharedLink = try await resolveSharedLink()
                let normalizedURL = try LinkInputNormalizer.normalize(sharedLink.url)
                let preferredTitle = normalizedOptionalText(contentText) ?? sharedLink.title
                let pendingLink = PendingSharedLink(url: normalizedURL, title: preferredTitle)

                // Always stage the shared URL into the shared queue first so the host app
                // can finish the save flow even if the extension loses network/auth state.
                await pendingSharedLinkStore.enqueue(pendingLink)

                if await sessionStore.session() != nil {
                    do {
                        _ = try await apiClient.createLink(url: normalizedURL, title: preferredTitle)
                        await pendingSharedLinkStore.remove(pendingLink.id)
                        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                        return
                    } catch {
                        // Fall through to the shared queue so the host app can retry later.
                    }
                }

                extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            } catch {
                extensionContext?.cancelRequest(withError: error)
            }
        }
    }

#if os(iOS)
    override func configurationItems() -> [Any]! {
        []
    }
#endif

    private func resolveSharedLink() async throws -> PendingSharedLink {
        let inputItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []

        for item in inputItems {
            let extractedTitle = normalizedOptionalText(item.attributedTitle?.string)

            for provider in item.attachments ?? [] {
                if let urlString = try await loadURLString(from: provider) {
                    return PendingSharedLink(url: urlString, title: extractedTitle)
                }
            }
        }

        if let textURL = normalizedOptionalText(contentText) {
            return PendingSharedLink(url: textURL, title: nil)
        }

        throw ShareExtensionError.unsupportedContent
    }

    private func firstSupportedItemProvider() -> NSItemProvider? {
        let inputItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        for item in inputItems {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier)
                    || provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
                {
                    return provider
                }
            }
        }

        return nil
    }

    private func loadURLString(from provider: NSItemProvider) async throws -> String? {
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            let item = try await provider.loadItem(forTypeIdentifier: UTType.url.identifier)
            if let url = item as? URL {
                return url.absoluteString
            }
            if let url = item as? NSURL {
                return url.absoluteString
            }
            if let text = item as? String {
                return text
            }
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            let item = try await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
            if let text = item as? String {
                return text
            }
            if let attributedString = item as? NSAttributedString {
                return attributedString.string
            }
        }

        return nil
    }

    private func normalizedOptionalText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private enum ShareExtensionError: LocalizedError {
    case unsupportedContent

    var errorDescription: String? {
        switch self {
        case .unsupportedContent:
            return "Dekabristi can only save shared web links right now."
        }
    }
}

private extension NSItemProvider {
    func loadItem(forTypeIdentifier typeIdentifier: String) async throws -> NSSecureCoding? {
        try await withCheckedThrowingContinuation { continuation in
            loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: item)
                }
            }
        }
    }
}
