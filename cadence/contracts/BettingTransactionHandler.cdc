import "FlowTransactionScheduler"
import "EVM"

access(all) contract BettingTransactionHandler {

    /// Handler resource that implements the Scheduled Transaction interface
    /// Calls the revealDiceRoll() function on an EVM betting contract
    access(all) resource Handler: FlowTransactionScheduler.TransactionHandler {
        access(all) let bettingContractAddress: EVM.EVMAddress
        access(all) let gasLimit: UInt64
        access(all) let coaCapability: Capability<auth(EVM.Call) &EVM.CadenceOwnedAccount>

        init(bettingContractHex: String, gasLimit: UInt64, coaCapability: Capability<auth(EVM.Call) &EVM.CadenceOwnedAccount>) {
            self.bettingContractAddress = EVM.addressFromString(bettingContractHex)
            self.gasLimit = gasLimit
            self.coaCapability = coaCapability
        }

        access(FlowTransactionScheduler.Execute) fun executeTransaction(id: UInt64, data: AnyStruct?) {
            let coa = self.coaCapability.borrow() ?? panic("Could not borrow COA")
            
            // Construct the calldata for revealDiceRoll()
            let calldata = EVM.encodeABIWithSignature(
                "revealDiceRoll()",
                []
            )
            
            // Call the betting contract's revealDiceRoll function
            let result: EVM.Result = coa.call(
                to: self.bettingContractAddress,
                data: calldata,
                gasLimit: self.gasLimit,
                value: EVM.Balance(attoflow: 0)
            )

            // Log the result
            if result.status == EVM.Status.successful {
                log("Transaction executed (id: ".concat(id.toString()).concat(") - revealDiceRoll successful"))
            } else {
                log("Transaction executed (id: ".concat(id.toString())
                    .concat(") - revealDiceRoll failed with error code ").concat(result.errorCode.toString())
                    .concat(": ").concat(result.errorMessage))
            }
        }

        access(all) view fun getViews(): [Type] {
            return [Type<StoragePath>(), Type<PublicPath>()]
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<StoragePath>():
                    return /storage/BettingTransactionHandler
                case Type<PublicPath>():
                    return /public/BettingTransactionHandler
                default:
                    return nil
            }
        }
    }

    /// Factory for the handler resource
    /// Creates a handler with the betting contract address, gas limit, and COA capability
    access(all) fun createHandler(
        bettingContractHex: String,
        gasLimit: UInt64,
        coa: Capability<auth(EVM.Call) &EVM.CadenceOwnedAccount>
    ): @Handler {
        return <- create Handler(
            bettingContractHex: bettingContractHex,
            gasLimit: gasLimit,
            coaCapability: coa
        )
    }
}