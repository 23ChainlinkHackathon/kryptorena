const { network, ethers } = require("hardhat")
const { developmentChains, networkConfig } = require("../helper-hardhat-config.js")
const { verify } = require("../utils/verify.js")
const { storeImages, storeTokenUriMetadata } = require("../scripts/uploadToPinata.js")

const imagesLocation = "./images"
const metadataTemplate = {
    name: "",
    description: "",
    image: "",
}

let tokenUris = [
    "ipfs://QmQkZbQ6GDFZqRDeSYGwjaAWoPobsLtYPyJCB1rQvkwwiH",
    "ipfs://QmUYAwb6sPX5ER2czMoWYmuY2wpbi9n3YcJpeZvfJY5JsL",
    "ipfs://QmbhYo8qroKXLQYQtRj3uVCBen1zVTKHaBkQTcznsnKMBs",
    "ipfs://QmWHXWb8SeUUx7sGX3L9vNQcg3AWqYrpsiFUELESb6Gucq",
    "ipfs://QmQmRNXSWxmNpN8StDFxhcWRFgRRc8zjsYXk8TDLqC7ToE",
    "ipfs://QmYqUS7tSk2dmHVi2nb4s5BCPFy3u3ZVqXyeZ6VMB5toXq",
    "ipfs://QmTT2y3sZWQvrkcEcNuk1cXZfmnCGShkWBiMTV5LpbNT72",
    "ipfs://QmTXoEyG2Ro6FmSVfc6bbRBvHwAgR6L8kTpiM6WjxD5Kp7",
    "ipfs://QmRxbsimpNWxMrX5S449358S1KqFhKg9ZWy3xn2P3E8x4D",
    "ipfs://QmbwDRexprXkn43EoaqF3LCSR4pbzZdtSC2o9poNw9dcEm",
    "ipfs://QmQzB6jsPv6LPtvWjdRS7d3TfgrcmsZVSmuZDhvwindieJ",
    "ipfs://Qma3Ze6cmPF23GdGrJWbKSPf8Gge7ptEdQ8u2Et2twuxXm",
    "ipfs://QmSuixLfj3khpCY6ryytyKWGiVqBECpcMNCjrtDQh6btbd",
    "ipfs://QmctoKtadYKp7sH5SQKDKq1eaZERU7mYw1TaU21SAWVKAn",
    "ipfs://QmehLD7HwKfTBjnKBAuGxziabABUZH8gbH2qpVRcsLCwNd",
]

const FUND_AMOUNT = "1000000000000000000000"

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId

    if (process.env.UPLOAD_TO_PINATA == "true") {
        tokenUris = await handleTokenUris()
    }
    let vrfCoordinatorV2Address, subscriptionId, vrfCoordinatorV2Mock

    if (developmentChains.includes(network.name)) {
        vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock")
        vrfCoordinatorV2Address = vrfCoordinatorV2Mock.address
        const tx = await vrfCoordinatorV2Mock.createSubscription()
        const txReceipt = await tx.wait()
        subscriptionId = txReceipt.events[0].args.subId
        await vrfCoordinatorV2Mock.fundSubscription(subscriptionId, FUND_AMOUNT)
    } else {
        vrfCoordinatorV2Address = networkConfig[chainId]["vrfCoordinatorV2"]
        subscriptionId = networkConfig[chainId]["subscriptionId"]
    }
    log(
        "-----------------------------------------------------------------------------------------------------------"
    )
    const gasLane = networkConfig[chainId]["gasLane"]
    const callbackGasLimit = networkConfig[chainId]["callbackGasLimit"]
    const mintFee = networkConfig[chainId]["mintFee"]

    const args = [
        vrfCoordinatorV2Address,
        subscriptionId,
        gasLane,
        callbackGasLimit,
        tokenUris,
        mintFee,
    ]

    const nft = await deploy("KryptorenaNft", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })
    if (chainId == 31337) {
        await vrfCoordinatorV2Mock.addConsumer(subscriptionId, nft.address)
    }

    log("--------------------------------------------------------------------------")

    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying...")
        await verify(nft.address, args)
    }

    async function handleTokenUris() {
        tokenUris = []
        const { responses: imageUploadResponses, files } = await storeImages(imagesLocation)
        for (index in imageUploadResponses) {
            let tokenUriMetadata = { ...metadataTemplate }
            tokenUriMetadata.name = files[index].replace(".png", "")
            tokenUriMetadata.description = `${tokenUriMetadata.name}`
            tokenUriMetadata.image = `ipfs://${imageUploadResponses[index].IpfsHash}`
            console.log(`Uploading ${tokenUriMetadata.name}...`)
            const metadataUploadResponse = await storeTokenUriMetadata(tokenUriMetadata)
            tokenUris.push(`ipfs://${metadataUploadResponse.IpfsHash}`)
        }
        console.log(`Token URIS:`)
        console.log(tokenUris)
        return tokenUris
    }
}

module.exports.tokenUris = tokenUris
module.exports.tags = ["all", "main", "nft"]
