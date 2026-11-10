import Foundation

enum TrioNetworkConfiguration {
    static let assetIdPrefix = "trio/mainnet/"
    static let nativeCoinAssetId = "trio/mainnet/coin"
    static let chainID: UInt64 = 1_414_678_863
    static let chainIDHex = "0x5452494f"
    static let masterchainGenesisRootBase64 = "ADzIkkcxBIvn8aI/zPEJxy+S9pmCudIIpe3WM78QbaA="
    static let masterchainFileHashBase64 = "droQpYLSTJuS5itIhuPGD1oVOoFvloeu0mDy06yWtbo="
    static let bridgeRateURL = URL(string: "https://investortonnft.com/api/trio/rates/TRI-USD")

    static let rpcURL: URL? = nil
    static let walletActionsEnabled = false
    static let assetManagementEnabled = false
    static let transactionSubmissionEnabled = false
}
