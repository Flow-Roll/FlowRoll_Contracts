import "FlowTransactionScheduler"
import "FlowTransactionSchedulerUtils"
import "FlowToken"
import "FungibleToken"
import "EVM"
import "BettingTransactionHandler"

//Bet Flow and Schedule a Reveal transaction with relative delay in seconds using the manager

transaction(
    erc20TokenHex: String,
    bettingContractHex: String,
    betAmount: String,
    bet: UInt16,
    approvalGasLimit: UInt64,
    betGasLimit: UInt64,
    flowValue: UInt,
    revealGasLimit: UInt64,
    delaySeconds: UFix64,
    priority: UInt8,
    executionEffort: UInt64,
    transactionData: AnyStruct?
){
   let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount

    prepare(signer: auth(SaveValue,BorrowValue,IssueStorageCapabilityController,PublishCapability,GetStorageCapabilityController) &Account){
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

        // Check if there is a public capability already
    
     let publicCapExists = signer.capabilities
        .get<&{FlowTransactionScheduler.TransactionHandler}>(/public/BettingTransactionHandler)
        .check()
    
      if !publicCapExists{
        // Issue a capability for the COA
        let coaCap: Capability<auth(EVM.Call) &EVM.CadenceOwnedAccount> = signer.capabilities.storage
            .issue<auth(EVM.Call) &EVM.CadenceOwnedAccount>(/storage/evm)


        // Save a handler resource to storage if not already present
        if signer.storage.borrow<&AnyResource>(from: /storage/BettingTransactionHandler) == nil {
            let handler <- BettingTransactionHandler.createHandler(
                bettingContractHex: bettingContractHex,
                gasLimit: revealGasLimit,
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

        //Now I can schedule the reveal transaction
        let future = getCurrentBlock().timestamp + delaySeconds

        let pr = priority == 0
            ? FlowTransactionScheduler.Priority.High
            : priority == 1
                ? FlowTransactionScheduler.Priority.Medium
                : FlowTransactionScheduler.Priority.Low

        // Get the entitled capability that will be used to create the transaction
        // Need to check both controllers because the order of controllers is not guaranteed
        var handlerCap: Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>? = nil
        if let cap = signer.capabilities.storage
                            .getControllers(forPath: /storage/BettingTransactionHandler)[0]
                            .capability as? Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}> {
            handlerCap = cap
        } else {
            handlerCap = signer.capabilities.storage
                            .getControllers(forPath: /storage/BettingTransactionHandler)[1]
                            .capability as! Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>
        }

       // Save a manager resource to storage if not already present
        if signer.storage.borrow<&AnyResource>(from: FlowTransactionSchedulerUtils.managerStoragePath) == nil {
            let manager <- FlowTransactionSchedulerUtils.createManager()
            signer.storage.save(<-manager, to: FlowTransactionSchedulerUtils.managerStoragePath)

            // Create a capability for the Manager
            let managerCapPublic = signer.capabilities.storage.issue<&{FlowTransactionSchedulerUtils.Manager}>(FlowTransactionSchedulerUtils.managerStoragePath)
            signer.capabilities.publish(managerCapPublic, at: FlowTransactionSchedulerUtils.managerPublicPath)
        }

           // Borrow the manager
        let manager = signer.storage.borrow<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>(from: FlowTransactionSchedulerUtils.managerStoragePath)
            ?? panic("Could not borrow a Manager reference from \(FlowTransactionSchedulerUtils.managerStoragePath)")

        // Withdraw fees
        let vaultRef = signer.storage
            .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("missing FlowToken vault")

        let est = FlowTransactionScheduler.estimate(
            data: transactionData,
            timestamp: future,
            priority: pr,
            executionEffort: executionEffort
        )

        assert(
            est.timestamp != nil || pr == FlowTransactionScheduler.Priority.Low,
            message: est.error ?? "estimation failed"
        )

        let fees <- vaultRef.withdraw(amount: est.flowFee ?? 0.0) as! @FlowToken.Vault

        // Schedule through the manager
        let transactionId = manager.schedule(
            handlerCap: handlerCap ?? panic("Could not borrow handler capability"),
            data: transactionData,
            timestamp: future,
            priority: pr,
            executionEffort: executionEffort,
            fees: <-fees
        )

        log("Scheduled transaction id: ".concat(transactionId.toString()).concat(" at ").concat(future.toString()))
}

   //Runs the EVM call and places the bet! Does the ERC20 Approval
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