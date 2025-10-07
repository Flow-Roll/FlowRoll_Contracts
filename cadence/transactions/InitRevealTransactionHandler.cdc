import "BettingTransactionHandler"
import "FlowTransactionScheduler"
import "EVM"

transaction(bettingContractHex: String, gasLimit: UInt64) {
    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, SaveValue, PublishCapability) &Account) {
        // Get or create COA in storage
        if signer.storage.borrow<&EVM.CadenceOwnedAccount>(from: /storage/evm) == nil {
            let newCOA <- EVM.createCadenceOwnedAccount()
            signer.storage.save(<-newCOA, to: /storage/evm)
        }

        // Issue a capability for the COA
        let coaCap: Capability<auth(EVM.Call) &EVM.CadenceOwnedAccount> = signer.capabilities.storage
            .issue<auth(EVM.Call) &EVM.CadenceOwnedAccount>(/storage/evm)


        // Save a handler resource to storage if not already present
        if signer.storage.borrow<&AnyResource>(from: /storage/BettingTransactionHandler) == nil {
            let handler <- BettingTransactionHandler.createHandler(
                bettingContractHex: bettingContractHex,
                gasLimit: gasLimit,
                coa: coaCap
            )
            signer.storage.save(<-handler, to: /storage/BettingTransactionHandler)
        }

        // Validation/example that we can create an issue a handler capability with correct entitlement for FlowTransactionScheduler
        let _ = signer.capabilities.storage
            .issue<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>(/storage/BettingTransactionHandler)

        // Issue a non-entitled public capability for the handler that is publicly accessible
        let publicCap = signer.capabilities.storage
            .issue<&{FlowTransactionScheduler.TransactionHandler}>(/storage/BettingTransactionHandler)
        // publish the capability
        signer.capabilities.publish(publicCap, at: /public/BettingTransactionHandler)
    }
}