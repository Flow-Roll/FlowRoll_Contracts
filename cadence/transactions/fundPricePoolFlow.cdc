import "EVM"


//Example use:
//  flow transactions send ./cadence/transactions/fundPricePoolFlow.cdc   --args-json '[
//     {"type": "String", "value": "0x2872A8AcF0F85EE4255AfFe2AC21a0aB25aD83b9"},
//     {"type": "UInt", "value": "2"},
//     {"type": "UInt64", "value": "99999"}
//   ]'   --signer testent-acc   --network testnet



transaction(
    bettingContractHex: String,
    flowValue: UInt,
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
                // let flowAmountAtto: UInt = UInt(flowValue) * 1_000_000_000_000_000_000 // 2 * 10^18

        // Define the value as EVM.Balance struct (this is the payable amount)
        let value = EVM.Balance(attoflow: 0)
        value.setFLOW(flow: UFix64(flowValue))
        
        // Construct the calldata for betFlow(uint16 bet)
        let calldata = EVM.encodeABIWithSignature(
            "fundPrizePoolFLOW(uint256)",
            [value.attoflow]
        )
        
        // Call the contract at the given EVM address with the bet parameter and FLOW value
        let result: EVM.Result = self.coa.call(
            to: contractAddress,
            data: calldata,
            gasLimit: gasLimit,
            value: value
        )

    var errorText = ""

       if result.status != EVM.Status.successful && result.data.length > 0{

        let decoded = EVM.decodeABIWithSignature("Error(string)", types: [Type<String>()], data: result.data)
        errorText = decoded[0] as! String
       
       }

        // Revert the transaction if the call was not successful
        assert(
            result.status == EVM.Status.successful,
            message: "betFlow call to ".concat(bettingContractHex)
                .concat(" failed with error code ").concat(result.errorCode.toString())
                .concat(": ")
                .concat(result.errorMessage)
                .concat("| value")
                .concat("revert data length: ")
                .concat(result.data.length.toString())
                .concat(errorText)
                
        )
    }
}