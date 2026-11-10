
import Foundation
import TonAPI
import TonSwift

protocol AccountService {
    func loadAccount(network: Network, address: Address) async throws -> Account
    func loadAccount(network: Network, domain: String) async throws -> Account
}

final class AccountServiceImplementation: AccountService {
    private let apiProvider: APIProvider
    private let trioNetworkClient: TrioNetworkClient

    init(apiProvider: APIProvider, trioNetworkClient: TrioNetworkClient = TrioNetworkClient()) {
        self.apiProvider = apiProvider
        self.trioNetworkClient = trioNetworkClient
    }

    func loadAccount(network: Network, address: Address) async throws -> Account {
        if network.isTrioMainnet {
            return try await trioNetworkClient.loadAccount(address: address)
        }
        return try await apiProvider.api(network).getAccountInfo(accountId: address.toRaw())
    }

    func loadAccount(network: Network, domain: String) async throws -> Account {
        guard !network.isTrioMainnet else { throw TrioNetworkClient.ClientError.accountUnavailable }
        return try await apiProvider.api(network).getAccountInfo(accountId: domain)
    }
}
