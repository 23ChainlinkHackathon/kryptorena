//scripts that deploy files can call on to serve a function
//In this case, any deploy file can call this script to verify the contracts on etherscan
const { run } = require("hardhat")

async function verify(contractAddress, args) {
    console.log("Verifying contract...")
    try {
        await run("verify:verify", {
            address: contractAddress,
            constructorArguments: args,
        })
    } catch (e) {
        if (e.message.toLowerCase().includes("Already verified")) {
            console.log("Already Verified")
        } else {
            console.log(e)
        }
    }
}
module.exports = { verify }
