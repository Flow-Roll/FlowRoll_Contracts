import "EVM"

/// Calls the betFlow function on the betting contract, sending FLOW value with the transaction.
/// The bet parameter determines the bet number, and flowValue is sent as payment.
//Example use:
//  flow transactions send ./cadence/transactions/BetFlowEVM.cdc   --args-json '[
//     {"type": "String", "value": "0x2872A8AcF0F85EE4255AfFe2AC21a0aB25aD83b9"},
//     {"type": "UInt16", "value": "0"},
//     {"type": "UInt", "value": "2"},
//     {"type": "UInt64", "value": "999999"}
//   ]'   --signer testent-acc   --network testnet


transaction(
    bettingContractHex: String,
    bet: UInt16,
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
        
        // Construct the calldata for betFlow(uint16 bet)
        let calldata = EVM.encodeABIWithSignature(
            "betFlow(uint16)",
            [UInt16(bet)]
        )

    // Construct the calldata for getContractParameters()
    let calldata_getContractParameters = EVM.encodeABIWithSignature(
        "getContractParameters()",
        []
    )

       let params_res = self.coa.call(
        to: contractAddress,
        data: calldata_getContractParameters,
        gasLimit: gasLimit,
        value: EVM.Balance(attoflow: 0)
       )

        // Check if call was successful
    assert(
        params_res.status == EVM.Status.successful,
        message: "getContractParameters call failed with error code "
            .concat(params_res.errorCode.toString())
            .concat(": ")
            .concat(params_res.errorMessage)
    )
    
  // Decode the return data
    // Returns (uint8, uint256, uint8, uint256, uint16, uint16, uint16)
    let decodedData = EVM.decodeABI(
        types: [Type<UInt8>(), Type<UInt256>(), Type<UInt8>(), Type<UInt256>(), Type<UInt16>(), Type<UInt16>(), Type<UInt16>()],
        data: params_res.data
    )

        let diceRollCost = decodedData[1] as! UInt256

        // let flowAmountAtto: UInt = UInt(flowValue) * 1_000_000_000_000_000_000 // 2 * 10^18

        // Define the value as EVM.Balance struct (this is the payable amount)
        let value = EVM.Balance(attoflow: UInt(diceRollCost))
        
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
                .concat("| bet:")
                .concat(bet.toString())
                .concat("| value ")
                .concat(diceRollCost.toString())
                .concat(" data ")
                .concat(result.data.length.toString())
                .concat(" err ")
                .concat(errorText)
        )
    }
}