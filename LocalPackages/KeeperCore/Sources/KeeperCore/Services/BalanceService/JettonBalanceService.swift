import BigInt
import Foundation
import TonAPI
import TonSwift

protocol JettonBalanceService {
    func loadJettonsBalance(wallet: Wallet, currency: Currency) async throws -> [JettonBalance]
}

final class JettonBalanceServiceImplementation: JettonBalanceService {
    private let apiProvider: APIProvider

    init(apiProvider: APIProvider) {
        self.apiProvider = apiProvider
    }

    func loadJettonsBalance(wallet: Wallet, currency: Currency) async throws -> [JettonBalance] {
        guard !wallet.network.isTrioMainnet else { return [] }
        let currencies = Array(Set([Currency.USD, Currency.GRAM, currency]))
        let tokensBalance = try await apiProvider.api(wallet.network).getAccountJettonsBalances(
            address: wallet.address,
            currencies: currencies
        )
        return tokensBalance.filter { $0.item.jettonInfo.verification != .blacklist && !$0.quantity.isZero }
    }
}
