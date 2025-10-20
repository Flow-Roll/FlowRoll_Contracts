import "BettingTransactionHandler"
import "FlowTransactionScheduler"
import "EVM"

access(all) fun main(address: Address): {String: Bool} {
    let account = getAccount(address)
    
    // Check if handler exists in storage
    let handlerExists = account.storage.type(at: /storage/BettingTransactionHandler) != nil
    
    // Check if public capability exists and is valid
    let publicCapExists = account.capabilities
        .get<&{FlowTransactionScheduler.TransactionHandler}>(/public/BettingTransactionHandler)
        .check()
    
    // Check if COA exists in storage
    let coaExists = account.storage.type(at: /storage/evm) != nil
    
    return {
        "handlerExists": handlerExists,
        "publicCapabilityValid": publicCapExists,
        "coaExists": coaExists,
        "allValid": handlerExists && publicCapExists && coaExists
    }
}