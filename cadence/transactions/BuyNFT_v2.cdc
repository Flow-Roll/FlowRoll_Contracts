import "EVM"
import "FungibleToken"
import "FlowToken"

//  flow transactions send ./cadence/transactions/BuyNFT_v2.cdc --args-json '[
//     {"type": "String", "value": "0x67E9A2e94DF5328F5b0DD97083EA15CCe71E17ED"},
//     {"type": "String", "value": "Super Bet Awesome"},
//     {"type": "String", "value": ""},
//     {"type": "String", "value": "0x0000000000000000000000000000000000000000"},
//     {"type": "UInt8",  "value": "10"},
//     {"type": "UFix64", "value": "5.0"},
//     {"type": "UInt8",  "value": "10"},
//     {"type": "UInt16", "value": "1"},
//     {"type": "UInt16", "value": "5"},
//     {"type": "UInt16", "value": "0"},
//     {"type": "UInt64", "value": "2999999"}
// ]' --signer testent-acc --network testnet

transaction(
    contractAddress: String,
    name: String,
    coupon: String,
    erc20Address: String,
    winnerPrizeShare: UInt8,
    diceRollCost: UFix64,
    houseEdge: UInt8,
    min: UInt16,
    max: UInt16,
    betType: UInt16,
    gasLimit: UInt64
){
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

    execute{
        let evmContractAddress = EVM.addressFromString(contractAddress)
        var diceRollCostWei = EVM.Balance(attoflow: 0)
        diceRollCostWei.setFLOW(flow: diceRollCost)

        let functionSelector = EVM.encodeABIWithSignature(
        "buyNFT(string,string,address,uint8,uint256,uint8,uint16,uint16,uint16)",
        [name, coupon, EVM.addressFromString(erc20Address), winnerPrizeShare,diceRollCostWei.inAttoFLOW(),houseEdge,min,max,betType]
        )

        //Now I hardcode the prize in flow, 2000
        var weiAmount = EVM.Balance(attoflow: 0)
            weiAmount.setFLOW(flow: 2000.0)

        let result = self.coa.call(
                to: evmContractAddress,
                data: functionSelector,
                gasLimit: gasLimit,
                value: weiAmount
            )

        assert(
                        result.status == EVM.Status.successful,
                        message: "buyNFT call to ".concat(contractAddress)
                            .concat(" failed with error code ").concat(result.errorCode.toString())
                            .concat(": ")
                            .concat(result.errorMessage)
                            .concat(" data ")
                            .concat(result.data.length.toString())
                            
                    )

    }
}