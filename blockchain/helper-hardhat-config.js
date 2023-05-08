const { ethers } = require("hardhat")

//Define network - addresses configurations
const networkConfig = {
    5: {
        name: "goerli",
        vrfCoordinatorV2: "0x2ca8e0c643bde4c2e08ab1fa0da3401adad7734d",
        subscriptionId: "8104",
        gasLane: "",
        callbackGasLimit: "50000",
        mintFee: ethers.utils.parseEther("0.01"),
        priceFeedAddress: "0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e", //ETH/USD
    },
    31337: {
        name: "hardhat",
        TOKEN_URI:
            "ipfs://bafybeig37ioir76s7mg5oobetncojcm3c3hxasyd4rvid4jqhy4gkaheg4/?filename=0-PUG.json",
        initialTokenCounter: "0",
        gasLane: "0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15",
        callbackGasLimit: "50000",
        mintFee: ethers.utils.parseEther("0.01"),
    },
}

const DECIMALS = "18"
const INITIAL_PRICE = "200000000000000000000"
const developmentChains = ["hardhat", "localhost", 31337]

module.exports = {
    networkConfig,
    developmentChains,
    DECIMALS,
    INITIAL_PRICE,
}
