import Foundation
import Commons
import WalletConnectSign
import WalletConnectAccount

final class Signer {
    enum Errors: Error {
        case notImplemented
    }
    
    private init() {}

    static func sign(request: Request, importAccount: ImportAccount) async throws -> AnyCodable {
        if try await didRequestSmartAccount(request) {
            return try await signWithSmartAccount(request: request)
        } else {
            return try signWithEOA(request: request, importAccount: importAccount)
        }
    }

    private static func didRequestSmartAccount(_ request: Request) async throws -> Bool {
        // Attempt to decode params for transaction requests
        if let params = try? request.params.get([String: AnyCodable].self),
           let account = params["from"]?.value as? String {
            let smartAccountAddress = try await SmartAccount.instance.getAddress()
            return account.lowercased() == smartAccountAddress.lowercased()
        }

        // Attempt to decode params for signing message requests
        if let paramsArray = try? request.params.get([AnyCodable].self) {
            if request.method == "personal_sign" || request.method == "eth_signTypedData" {
                // Typically, the account address is the second parameter for personal_sign and eth_signTypedData
                if paramsArray.count > 1,
                   let account = paramsArray[1].value as? String {
                    let smartAccountAddress = try await SmartAccount.instance.getAddress()
                    return account.lowercased() == smartAccountAddress.lowercased()
                }
            }
        }

        return false
    }

    private static func signWithEOA(request: Request, importAccount: ImportAccount) throws -> AnyCodable {
        let signer = ETHSigner(importAccount: importAccount)

        switch request.method {
        case "personal_sign":
            return signer.personalSign(request.params)

        case "eth_signTypedData":
            return signer.signTypedData(request.params)

        case "eth_sendTransaction":
            return try signer.sendTransaction(request.params)

        case "solana_signTransaction":
            return SOLSigner.signTransaction(request.params)

        default:
            throw Signer.Errors.notImplemented
        }
    }


    private static func signWithSmartAccount(request: Request) async throws -> AnyCodable {
            switch request.method {
            case "personal_sign":
                let params = try request.params.get([String].self)
                let message = params[0]
                return AnyCodable(SmartAccount.instance.signMessage(message))

            case "eth_signTypedData":
                let params = try request.params.get([String].self)
                let message = params[0]
                return AnyCodable(SmartAccount.instance.signMessage(message))

            case "eth_sendTransaction":
                let params = try request.params.get([WalletConnectAccount.Transaction].self)
                let transaction = params[0]
                let result = try await SmartAccount.instance.sendTransaction(transaction)
                return AnyCodable(result)

                //        case "wallet_sendCalls":
                //            let transactions =
                //            return SmartAccount.instance.sendBatchTransaction(<#T##batch: [Transaction]##[Transaction]#>)

            default:
                throw Signer.Errors.notImplemented
            }
        }
}

extension Signer.Errors: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notImplemented:   return "Requested method is not implemented"
        }
    }
}

