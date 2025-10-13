import "EVM"

// flow transactions send ./cadence/transactions/GetExpectedPriceNFT.cdc --network testnet --signer testent-acc

transaction(){
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount

 prepare(signer: auth(BorrowValue, SaveValue) &Account) {
        // Borrow or create a CadenceOwnedAccount (COA)
        if signer.storage.type(at: /storage/evm) == nil {
            let newCOA <- EVM.createCadenceOwnedAccount()
            signer.storage.save(<-newCOA, to: /storage/evm)
        }
        
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA reference")
    }
    
    execute {
        // Convert contract address from hex string to EVM address
    let evmContractAddress = EVM.addressFromString("0x17664E960a1445434A460fBAAf6d361FcD04396c")
        

    let getExpectedPriceSelector = EVM.encodeABIWithSignature("getExpectedPriceInFlow()", [])

     let params_res = self.coa.call(
        to: evmContractAddress,
        data: getExpectedPriceSelector,
        gasLimit: 50064,
        value: EVM.Balance(attoflow: 0)
       )

    assert(params_res.status == EVM.Status.successful, 
    message: "EVM call to get expected price failed"
    .concat(" error: ")
    .concat(params_res.errorMessage)
    .concat(" Error Code " )
    .concat(params_res.errorCode.toString())
    )

 let decodedData = EVM.decodeABI(
        types: [Type<UInt256>()],
        data: params_res.data
    )

        let expectedPrice = decodedData[0] as! UInt256


        let getReducedPrice = EVM.encodeABIWithSignature(
        "getReducedPrice(string,uint256)",
        ["#GoWithTheFlow", expectedPrice]
        )

       let reducedPriceRes  = self.coa.call(
        to: evmContractAddress,
        data: getReducedPrice,
        gasLimit: 50064,
        value: EVM.Balance(attoflow: 0)
       )
      assert(reducedPriceRes.status == EVM.Status.successful, message: "EVM call to get expected price failed")
 
      let decodedReducedPrice = EVM.decodeABI(
          types: [Type<UInt256>()],
          data: reducedPriceRes.data
      )

      let priceWithDiscount = decodedReducedPrice[0] as! UInt256

      log("Price with discount".concat(priceWithDiscount.toString()))

      let price = EVM.Balance(attoflow: UInt(priceWithDiscount)).inFLOW()

      assert(price == 293.40000000,message: "Not the expected price")

    }   
}