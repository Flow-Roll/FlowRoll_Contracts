import "EVM"

/// First approves an ERC20 token for spending by a target contract, then calls the contract's
/// betERC20 function with the approved amount and bet number.
transaction(
    erc20TokenHex: String,
    bettingContractHex: String,
    betAmount: UInt256,
    bet: UInt16,
    approvalGasLimit: UInt64,
    betGasLimit: UInt64
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
        // Deserialize the EVM addresses from the hex strings
        let erc20Address = EVM.addressFromString(erc20TokenHex)
        let bettingContractAddress = EVM.addressFromString(bettingContractHex)
        
        // Step 1: Approve the betting contract to spend ERC20 tokens
        // ERC20 approve function signature: approve(address spender, uint256 amount)
        let approvalCalldata = EVM.encodeABIWithSignature(
            "approve(address,uint256)",
            [bettingContractAddress, betAmount]
        )
        
        let approvalResult: EVM.Result = self.coa.call(
            to: erc20Address,
            data: approvalCalldata,
            gasLimit: approvalGasLimit,
            value: EVM.Balance(attoflow: 0)
        )
        
        // Revert if approval failed
        assert(
            approvalResult.status == EVM.Status.successful,
            message: "ERC20 approval failed for token ".concat(erc20TokenHex)
                .concat(" with error code ").concat(approvalResult.errorCode.toString())
                .concat(": ").concat(approvalResult.errorMessage)
        )
        
        // Step 2: Call the betting contract's betERC20 function
        // Function signature: betERC20(uint256 betAmount, uint16 bet)
        let betCalldata = EVM.encodeABIWithSignature(
            "betERC20(uint256,uint16)",
            [betAmount, bet]
        )
        
        let betResult: EVM.Result = self.coa.call(
            to: bettingContractAddress,
            data: betCalldata,
            gasLimit: betGasLimit,
            value: EVM.Balance(attoflow: 0)
        )
        
        // Revert if the bet call failed
        assert(
            betResult.status == EVM.Status.successful,
            message: "Bet call failed on contract ".concat(bettingContractHex)
                .concat(" with error code ").concat(betResult.errorCode.toString())
                .concat(": ").concat(betResult.errorMessage)
        )
    }
}