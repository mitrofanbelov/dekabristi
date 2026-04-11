import Foundation

public enum LinkInputNormalizationError: LocalizedError {
    case empty
    case invalidFormat
    case unsupportedScheme
    case missingHost

    public var errorDescription: String? {
        switch self {
        case .empty:
            return "Enter a link before saving."
        case .invalidFormat:
            return "Enter a valid web address."
        case .unsupportedScheme:
            return "Only http and https links are supported right now."
        case .missingHost:
            return "The link must include a website address, for example example.com."
        }
    }
}

public enum LinkInputNormalizer {
    public static func normalize(_ rawValue: String) throws -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LinkInputNormalizationError.empty
        }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard var components = URLComponents(string: candidate) else {
            throw LinkInputNormalizationError.invalidFormat
        }

        guard let scheme = components.scheme?.lowercased() else {
            throw LinkInputNormalizationError.invalidFormat
        }
        guard scheme == "http" || scheme == "https" else {
            throw LinkInputNormalizationError.unsupportedScheme
        }
        components.scheme = scheme

        guard let host = components.host, !host.isEmpty else {
            throw LinkInputNormalizationError.missingHost
        }

        if components.url == nil {
            throw LinkInputNormalizationError.invalidFormat
        }

        return components.string ?? candidate
    }

    public static func firstWebLink(in rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let normalized = try? normalize(trimmed) {
            return normalized
        }

        guard
            let detector = try? NSDataDetector(
                types: NSTextCheckingResult.CheckingType.link.rawValue
            )
        else {
            return nil
        }

        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        for match in detector.matches(in: trimmed, options: [], range: range) {
            guard let url = match.url, let normalized = try? normalize(url.absoluteString) else {
                continue
            }
            return normalized
        }

        return nil
    }
}
