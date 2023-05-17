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
    "ipfs://QmV1SBgXAKNU6EcVP5EwTUEx4E4k2H6X5RhmvEBcTQ31Q8",
    "ipfs://QmPwmVUSQmdj7LxBKe4hT7KfarcpqYAEkaMssWQL4sCFPb",
    "ipfs://QmXisMZfUkbz79KjGDVEeBFgMPMz5N6LGg8zHbmD1HLbTB",
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
            tokenUriMetadata.name = files[index].replace(".jpg", "")
            tokenUriMetadata.description = `An adorable ${tokenUriMetadata.name} animal!`
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
