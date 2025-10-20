import "EVM"
//Example use:
// flow transactions send ./cadence/transactions/revealBet.cdc   --args-json '[
//     {"type": "String", "value": "0x2872A8AcF0F85EE4255AfFe2AC21a0aB25aD83b9"},
//     {"type": "UInt64", "value": "999999"}
//   ]'   --signer testent-acc   --network testnet

transaction(
    bettingContractHex: String,
    gasLimit: UInt64
) {
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
 
    prepare(signer: auth(SaveValue, BorrowValue) &Account) {
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
        // Deserialize the EVM address from the hex string
        let contractAddress = EVM.addressFromString(bettingContractHex)
        

        // Construct the calldata for betFlow(uint16 bet)
        let calldata = EVM.encodeABIWithSignature(
            "revealDiceRoll()",
            []
        )
        
        // Call the contract at the given EVM address with the bet parameter and FLOW value
        let result: EVM.Result = self.coa.call(
            to: contractAddress,
            data: calldata,
            gasLimit: gasLimit,
            value: EVM.Balance(attoflow: 0)
        )

        // Revert the transaction if the call was not successful
        assert(
            result.status == EVM.Status.successful,
            message: "reveal call to ".concat(bettingContractHex)
                .concat(" failed with error code ").concat(result.errorCode.toString())
                .concat(": ")
                .concat(result.errorMessage)
        )
    }
}