import Foundation

struct TrioBridgeRateQuote: Equatable, Sendable {
    let usdPrice: Decimal
    let validUntil: Date
}

actor TrioBridgeRateClient {
    private struct Response: Decodable {
        let base: String
        let quote: String
        let price: String
        let observedAt: String
        let validUntil: String
        let source: String
        let method: String
        let windowSeconds: Int
        let liquidityUsd: String
        let volume24hUsd: String
        let finalizedBlock: Int64
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func loadUSDQuote() async -> TrioBridgeRateQuote? {
        guard let url = TrioNetworkConfiguration.bridgeRateURL else { return nil }

        var request = URLRequest(url: url, timeoutInterval: 8)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            let receivedAt = Date()
            guard
                let response = response as? HTTPURLResponse,
                response.statusCode == 200,
                response.url?.scheme == "https",
                response.url?.host == url.host,
                let payload = try? JSONDecoder().decode(Response.self, from: data),
                payload.base == "TRI",
                payload.quote == "USD",
                payload.source == "ton-trio-bridge",
                payload.method == "bridge-reserve-twap",
                payload.windowSeconds > 0,
                payload.finalizedBlock >= 0,
                let observedAt = Self.date(payload.observedAt),
                observedAt <= receivedAt,
                let validUntil = Self.date(payload.validUntil),
                validUntil > receivedAt,
                validUntil > observedAt,
                let price = Decimal(string: payload.price, locale: Locale(identifier: "en_US_POSIX")),
                price > .zero,
                NSDecimalNumber(decimal: price).doubleValue.isFinite
            else {
                return nil
            }

            return TrioBridgeRateQuote(usdPrice: price, validUntil: validUntil)
        } catch {
            return nil
        }
    }

    private static func date(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

