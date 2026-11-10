import Foundation
import TonSwift

struct TrioNetworkClient {
    enum ClientError: LocalizedError {
        case invalidWalletAddress
        case invalidResponse
        case unexpectedStatus(Int)
        case walletAddressMismatch
        case invalidSeqno
        case accountUnavailable
        case invalidBalance
        case invalidMessage
        case unsupportedBatch
        case wrongNetwork
        case genesisUnverified

        var errorDescription: String? {
            switch self {
            case .invalidWalletAddress:
                "Could not encode the Trio wallet address."
            case .invalidResponse:
                "The Trio RPC returned an invalid response."
            case let .unexpectedStatus(status):
                "The Trio RPC returned HTTP status \(status)."
            case .walletAddressMismatch:
                "The Trio RPC response did not match the requested wallet."
            case .invalidSeqno:
                "The Trio RPC returned an invalid wallet sequence number."
            case .accountUnavailable:
                "The Trio RPC does not have this account state indexed."
            case .invalidBalance:
                "The Trio RPC returned an invalid account balance."
            case .invalidMessage:
                "The signed message is not valid base64."
            case .unsupportedBatch:
                "Trio RPC accepts one signed external message at a time."
            case .wrongNetwork:
                "The configured endpoint is not reporting the Trio network."
            case .genesisUnverified:
                "The Trio genesis identity has not been verified by the RPC."
            }
        }
    }

    private struct PublicNetworkStatus: Decodable {
        let status: String
        let chainId: Int32

        enum CodingKeys: String, CodingKey {
            case status
            case chainId
        }
    }

    private struct TrioNetworkIdentity: Decodable {
        struct Genesis: Decodable {
            let rootHash: String
            let fileHash: String

            enum CodingKeys: String, CodingKey {
                case rootHash = "root_hash"
                case fileHash = "file_hash"
            }
        }

        let globalId: Int32
        let genesis: Genesis
        let nodeSeqno: UInt32
        let indexedSeqno: UInt32
        let status: String

        enum CodingKeys: String, CodingKey {
            case globalId = "global_id"
            case genesis
            case nodeSeqno = "node_seqno"
            case indexedSeqno = "indexed_seqno"
            case status
        }
    }

    enum WalletState: String, Decodable {
        case active
        case uninitialized
    }

    struct WalletSeqnoResponse: Decodable {
        let address: String
        let seqno: UInt64
        let state: WalletState
        let blockSeqno: UInt32

        enum CodingKeys: String, CodingKey {
            case address
            case seqno
            case state
            case blockSeqno = "block_seqno"
        }
    }

    struct AccountState: Decodable {
        let address: String
        let balance: String
        let status: String
    }

    struct WalletAccountState {
        let address: String
        let balanceNano: Int64
        let status: String
    }

    private struct AccountStatesResponse: Decodable {
        let accounts: [AccountState]
    }

    private struct SendMessageRequest: Encodable {
        let boc: String
    }

    private struct SendMessageResponse: Decodable {
        let messageHash: String
        let messageHashNorm: String

        enum CodingKeys: String, CodingKey {
            case messageHash = "message_hash"
            case messageHashNorm = "message_hash_norm"
        }
    }

    private let session: URLSession
    private let baseURL: URL
    private let statusURL: URL
    private let networkIdentityURL: URL

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://investortonnft.com/api/trio/v3")!,
        statusURL: URL = URL(string: "https://investortonnft.com/api/scan/status")!,
        networkIdentityURL: URL = URL(string: "https://investortonnft.com/api/trio/v3/network")!
    ) {
        self.session = session
        self.baseURL = baseURL
        self.statusURL = statusURL
        self.networkIdentityURL = networkIdentityURL
    }

    func loadWalletSeqno(wallet: Wallet) async throws -> UInt64 {
        guard wallet.network.isTrioMainnet,
              wallet.isTrioSigningVersionSupported
        else {
            throw ClientError.invalidWalletAddress
        }

        try await requireVerifiedTrioGenesis()
        return try await loadWalletSeqno(address: wallet.address)
    }

    func loadWalletSeqno(address: Address) async throws -> UInt64 {
        try await requireTrioChainId()
        let response = try await getWalletSeqno(address: address)
        return response.seqno
    }

    func loadAccountBalance(wallet: Wallet) async throws -> Int64 {
        guard wallet.network.isTrioMainnet,
              wallet.isTrioSigningVersionSupported
        else {
            throw ClientError.invalidWalletAddress
        }

        return try await loadWalletAccountState(address: wallet.address)?.balanceNano ?? 0
    }

    func loadWalletAccountState(address: Address) async throws -> WalletAccountState? {
        try await requireTrioChainId()
        let response = try await getAccountStates(address: address)
        if let account = try matchingAccount(response.accounts, requested: address) {
            return WalletAccountState(
                address: account.address,
                balanceNano: try parseBalance(account.balance),
                status: account.status
            )
        }

        let seqno = try await getWalletSeqno(address: address)
        guard seqno.state == .uninitialized, seqno.seqno == 0 else {
            throw ClientError.accountUnavailable
        }
        return nil
    }

    func loadAccount(address: Address) async throws -> Account {
        let response = try await getAccountStates(address: address)
        guard let state = try matchingAccount(response.accounts, requested: address) else {
            throw ClientError.accountUnavailable
        }
        return Account(
            address: address,
            balance: try parseBalance(state.balance),
            status: state.status,
            name: nil,
            icon: nil,
            isSuspended: nil,
            isWallet: false,
            isScam: nil,
            isMemoRequired: nil
        )
    }

    private func getWalletSeqno(address: Address) async throws -> WalletSeqnoResponse {
        let data = try await get(path: "walletSeqno", address: address)
        let decoded: WalletSeqnoResponse
        do {
            decoded = try JSONDecoder().decode(WalletSeqnoResponse.self, from: data)
        } catch {
            throw ClientError.invalidResponse
        }

        guard let returnedAddress = try? Address.parse(decoded.address),
              returnedAddress.toRaw().lowercased() == address.toRaw().lowercased()
        else {
            throw ClientError.walletAddressMismatch
        }

        guard decoded.state != .uninitialized || decoded.seqno == 0 else {
            throw ClientError.invalidSeqno
        }
        return decoded
    }

    private func getAccountStates(address: Address) async throws -> AccountStatesResponse {
        let data = try await get(path: "accountStates", address: address, extraQuery: [
            URLQueryItem(name: "include_boc", value: "false"),
        ])
        do {
            return try JSONDecoder().decode(AccountStatesResponse.self, from: data)
        } catch {
            throw ClientError.invalidResponse
        }
    }

    private func get(path: String, address: Address, extraQuery: [URLQueryItem] = []) async throws -> Data {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "address", value: address.toRaw())] + extraQuery
        guard let url = components?.url else { throw ClientError.invalidWalletAddress }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard (200 ..< 300).contains(response.statusCode) else {
            throw ClientError.unexpectedStatus(response.statusCode)
        }
        return data
    }

    private func matchingAccount(_ accounts: [AccountState], requested: Address) throws -> AccountState? {
        guard accounts.count <= 1 else { throw ClientError.invalidResponse }
        guard let account = accounts.first else { return nil }
        guard let returnedAddress = try? Address.parse(account.address),
              returnedAddress.toRaw().lowercased() == requested.toRaw().lowercased()
        else {
            throw ClientError.walletAddressMismatch
        }
        return account
    }

    private func parseBalance(_ balance: String) throws -> Int64 {
        guard let amount = Int64(balance), amount >= 0 else { throw ClientError.invalidBalance }
        return amount
    }

    func sendSignedMessage(boc: String, wallet: Wallet) async throws {
        guard wallet.network.isTrioMainnet,
              wallet.isTrioSigningVersionSupported,
              let bytes = Data(base64Encoded: boc),
              !bytes.isEmpty
        else {
            throw ClientError.invalidMessage
        }

        try await requireVerifiedTrioGenesis()

        var request = URLRequest(url: baseURL.appendingPathComponent("message"), timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(SendMessageRequest(boc: boc))

        // Do not retry: a transport error after submission has an unknown outcome, and the BOC
        // may already be accepted by the Trio node. No mnemonic or private key leaves this device.
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard (200 ..< 300).contains(response.statusCode) else {
            throw ClientError.unexpectedStatus(response.statusCode)
        }

        let decoded: SendMessageResponse
        do {
            decoded = try JSONDecoder().decode(SendMessageResponse.self, from: data)
        } catch {
            throw ClientError.invalidResponse
        }
        guard !decoded.messageHash.isEmpty, !decoded.messageHashNorm.isEmpty else {
            throw ClientError.invalidResponse
        }
    }

    func sendSignedMessages(_ bocs: [String], wallet: Wallet) async throws {
        guard bocs.count == 1, let boc = bocs.first else { throw ClientError.unsupportedBatch }
        try await sendSignedMessage(boc: boc, wallet: wallet)
    }

    private func requireTrioChainId() async throws {
        let (data, response) = try await session.data(for: URLRequest(url: statusURL, timeoutInterval: 10))
        guard let response = response as? HTTPURLResponse,
              (200 ..< 300).contains(response.statusCode)
        else {
            throw ClientError.unexpectedStatus((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let status: PublicNetworkStatus
        do {
            status = try JSONDecoder().decode(PublicNetworkStatus.self, from: data)
        } catch {
            throw ClientError.invalidResponse
        }
        guard status.status == "online", status.chainId == 1_414_678_863 else {
            throw ClientError.wrongNetwork
        }
    }

    private func requireVerifiedTrioGenesis() async throws {
        let (data, response) = try await session.data(for: URLRequest(url: networkIdentityURL, timeoutInterval: 10))
        guard let response = response as? HTTPURLResponse,
              (200 ..< 300).contains(response.statusCode)
        else {
            throw ClientError.genesisUnverified
        }
        let identity: TrioNetworkIdentity
        do {
            identity = try JSONDecoder().decode(TrioNetworkIdentity.self, from: data)
        } catch {
            throw ClientError.genesisUnverified
        }
        guard identity.globalId == 1_414_678_863,
              identity.genesis.rootHash == "ADzIkkcxBIvn8aI/zPEJxy+S9pmCudIIpe3WM78QbaA=",
              identity.genesis.fileHash == "droQpYLSTJuS5itIhuPGD1oVOoFvloeu0mDy06yWtbo=",
              identity.status == "online"
        else {
            throw ClientError.genesisUnverified
        }
    }
}
