import "EVM"
import "FungibleToken"
import "FlowToken"

// flow transactions send ./cadence/transactions/BuyNFT.cdc --args-json '[
//     {"type": "String", "value": "0x17664E960a1445434A460fBAAf6d361FcD04396c"},
//     {"type": "String", "value": "0x71A713135d57911631Bb54259026Eaa030F7B881"},
//     {"type": "String", "value": "SuperBet"},
//     {"type": "String", "value": "#Go"},
//     {"type": "String", "value": "0x0000000000000000000000000000000000000000"},
//     {"type": "UInt8",  "value": "10"},
//     {"type": "UFix64", "value": "5.0"},
//     {"type": "UInt8", "value": "10"},
//     {"type": "UFix64", "value": "0.5"},
//     {"type": "UInt16", "value": "1"},
//     {"type": "UInt16", "value": "5"},
//     {"type": "UInt16", "value": "0"},
//     {"type": "UInt64", "value": "9999999"}
// ]' --signer testent-acc   --network testnet
//TODO: Need to break this down and try to call view functions first and then experiment to get this working

transaction(
    contractAddress: String,
    mintToAddress: String,
    name: String,
    coupon: String,
    erc20Address: String,
    winnerPrizeShare: UInt8,
    diceRollCost: UFix64,
    houseEdge: UInt8,
    revealCompensation: UFix64,
    betParam0: UInt16,
    betParam1: UInt16,
    betParam2: UInt16,
    gasLimit: UInt64
) {
    let coa: auth(EVM.Call) &EVM.CadenceOwnedAccount
    let mintToAddress:  String
    prepare(signer: auth(BorrowValue, SaveValue) &Account) {
        // Borrow or create a CadenceOwnedAccount (COA)
        if signer.storage.type(at: /storage/evm) == nil {
            let newCOA <- EVM.createCadenceOwnedAccount()
            signer.storage.save(<-newCOA, to: /storage/evm)
        }
        
        self.coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("Could not borrow COA reference")

        let addressWithoutPrefix = self.coa.address()        
        
        self.mintToAddress = "0x".concat(addressWithoutPrefix.toString())
    }
    
    execute {
    // Convert contract address from hex string to EVM address
    let evmContractAddress = EVM.addressFromString(contractAddress)
        

//     let getExpectedPriceSelector = EVM.encodeABIWithSignature("getExpectedPriceInFlow()", [])

//      let params_res = self.coa.call(
//         to: evmContractAddress,
//         data: getExpectedPriceSelector,
//         gasLimit: 50064,
//         value: EVM.Balance(attoflow: 0)
//        )

//     assert(params_res.status == EVM.Status.successful, 
//     message: "EVM call to get expected price failed"
//     .concat(" error: ")
//     .concat(params_res.errorMessage)
//     .concat(" Error Code " )
//     .concat(params_res.errorCode.toString())
//     )


//  let decodedData = EVM.decodeABI(
//         types: [Type<UInt256>()],
//         data: params_res.data
//     )

//         let expectedPrice = decodedData[0] as! UInt256


//         let getReducedPrice = EVM.encodeABIWithSignature(
//         "getReducedPrice(string,uint256)",
//         ["#GoWithTheFlow", expectedPrice]
//         )

//        let reducedPriceRes  = self.coa.call(
//         to: evmContractAddress,
//         data: getReducedPrice,
//         gasLimit: 50064,
//         value: EVM.Balance(attoflow: 0)
//        )
//       assert(reducedPriceRes.status == EVM.Status.successful, message: "EVM call to get expected price failed")
 
//       let decodedReducedPrice = EVM.decodeABI(
//           types: [Type<UInt256>()],
//           data: reducedPriceRes.data
//       )

//       let priceWithDiscount = decodedReducedPrice[0] as! UInt256

//       log("Price with discount".concat(priceWithDiscount.toString()))

    //   let price = EVM.Balance(attoflow: UInt(priceWithDiscount)).inFLOW()

           var diceRollCostWei = EVM.Balance(attoflow: 0)
            diceRollCostWei.setFLOW(flow: diceRollCost)

            var revealCompensationWei = EVM.Balance(attoflow : 0)
            revealCompensationWei.setFLOW(flow: revealCompensation)



        //     // Encode the function call
        //     // Function signature: buyNFT(string[2],address,address,uint8,uint256,uint8,uint256,uint16[3])
            let functionSelector = EVM.encodeABIWithSignature(
                "buyNFT(string[2],address,address,uint8,uint256,uint8,uint256,uint16[3])",
                [
                    [name, coupon],
                    EVM.addressFromString("0x71A713135d57911631Bb54259026Eaa030F7B881"),
                    EVM.addressFromString("0x0000000000000000000000000000000000000000"),
                    winnerPrizeShare,
                    UInt256(diceRollCostWei.inAttoFLOW()),
                    houseEdge,
                    UInt256(revealCompensationWei.inAttoFLOW()),
                    [betParam0, betParam1, betParam2] 
                ]
            )
            
            var weiAmount = EVM.Balance(attoflow: 0)//UInt(expectedPrice))
            weiAmount.setFLOW(flow: 271.0)

            // Call the contract function with value
            let result = self.coa.call(
                to: evmContractAddress,
                data: functionSelector,
                gasLimit: gasLimit,
                value: weiAmount
            )
            
           var errorText = ""

        //    if result.status != EVM.Status.successful && result.data.length > 0{

        //     let decoded = EVM.decodeABIWithSignature("Error(string)", types: [Type<String>()], data: result.data)
        //     errorText = decoded[0] as! String
        
        //    }
            // Revert the transaction if the call was not successful
                    // assert(
                    //     result.status == EVM.Status.successful,
                    //     message: "buyNFT call to ".concat(contractAddress)
                    //         .concat(" failed with error code ").concat(result.errorCode.toString())
                    //         .concat(": ")
                    //         .concat(result.errorMessage)
                    //         .concat(" data ")
                    //         .concat(result.data.length.toString())
                    //         .concat(" err ")
                    //         .concat(errorText)
                    //         .concat("weiAmount: ")
                    //         .concat(weiAmount.inAttoFLOW().toString())
                    //         .concat(" ,name: ")
                    //         .concat(name)
                    //         .concat(" ,coupon: ")
                    //         .concat(coupon)
                    //         .concat(", mint to address")
                    //         .concat(self.mintToAddress)
                    //         .concat(", winnerPriceShare")
                    //         .concat(winnerPrizeShare.toString())
                    //         .concat(" : ")
                    // )
     
    }
}