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
    43113: {
        name: "fuji",
        vrfCoordinatorV2: "0x2eD832Ba664535e5886b75D64C46EB9a228C2610",
        subscriptionId: "675",
        gasLane: "0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61",
        callbackGasLimit: "2500000",
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
