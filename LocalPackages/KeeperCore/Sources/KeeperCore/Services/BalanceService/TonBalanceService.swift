import Foundation
import TonAPI
import TonSwift

protocol TonBalanceService {
    func loadBalance(wallet: Wallet) async throws -> TonBalance
}

final class TonBalanceServiceImplementation: TonBalanceService {
    private let apiProvider: APIProvider
    private let trioNetworkClient: TrioNetworkClient

    init(apiProvider: APIProvider, trioNetworkClient: TrioNetworkClient = TrioNetworkClient()) {
        self.apiProvider = apiProvider
        self.trioNetworkClient = trioNetworkClient
    }

    func loadBalance(wallet: Wallet) async throws -> TonBalance {
        if wallet.network.isTrioMainnet {
            return TonBalance(amount: try await trioNetworkClient.loadAccountBalance(wallet: wallet))
        }
        let account = try await apiProvider.api(wallet.network).getAccountInfo(accountId: wallet.address.toRaw())
        return TonBalance(amount: account.balance)
    }
}
