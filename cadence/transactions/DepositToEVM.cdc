import "FlowToken"
import "FungibleToken"
import "EVM"

// Example use
// flow transactions send ./cadence/transactions/DepositToEVM.cdc   --args-json '[
//     {"type": "UFix64", "value": "100.00"}
//   ]'   --signer testent-acc   --network testnet

transaction(amount: UFix64) {
    let sentVault: @FlowToken.Vault
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount

    prepare(signer: auth(BorrowValue,SaveValue) &Account){
        //reference to the signers flow token vault
       let sourceVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow signer's FlowToken.Vault")
        
           // Create empty FLOW vault to capture funds
       self.sentVault <- sourceVault.withdraw(amount: amount) as! @FlowToken.Vault

        // Check if COA exists, if not create it
        if signer.storage.borrow<&EVM.CadenceOwnedAccount>(from: /storage/evm) == nil {
            let newCOA <- EVM.createCadenceOwnedAccount()
            signer.storage.save(<-newCOA, to: /storage/evm)
        }

        // Borrow an entitled reference to the COA from the storage location we saved it to
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(
            from: /storage/evm
        ) ?? panic("Could not borrow reference to the signer's CadenceOwnedAccount (COA). "
            .concat("Ensure the signer account has a COA stored in the canonical /storage/evm path"))



    }


    execute {        
        // Withdraw from sender and deposit to recipient

        self.coa.deposit(from: <-self.sentVault)

        log("Deposited ".concat(amount.toString()))
    }
}