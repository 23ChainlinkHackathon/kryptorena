const { getNamedAccounts, ethers, network } = require("hardhat")
const { assert, expect } = require("chai")
const { developmentChains, networkConfig } = require("../../helper-hardhat-config")
const { tokenUris } = require("/home/robitu/personal/MY_NFT/deploy/01-deploy-MyNft")

developmentChains.includes(network.name)
    ? describe.skip
    : describe("Kryptorena", async function () {
          let kryptorena, deployer, mintFee
          chainId = network.config.chainId

          beforeEach(async () => {
              deployer = (await getNamedAccounts()).deployer
              kryptorena = await ethers.getContract("KryptorenaNft", deployer)
              mintFee = networkConfig[chainId]["mintFee"]
          })

          describe("constructor", function () {
              it("should return the correct number of NFT token URIs stored in the contract", async () => {
                  const response = await kryptorena.getNftTokenUriCount()
                  const urisListLength = tokenUris.length
                  assert.equal(response.toString(), urisListLength)
              })
              it("should return the correct subscriptionId value", async () => {
                  const response = await kryptorena.getSubscriptionId()
                  const subId = networkConfig[chainId]["subscriptionId"]
                  assert.equal(response.toString(), subId)
              })
              it("should return correct gas lane", async () => {
                  const response = await kryptorena.getGasLane()
                  const gasLane = networkConfig[chainId]["gasLane"]
                  assert.equal(response, gasLane)
              })
              it("should return correct callback gas limit", async () => {
                  const response = await kryptorena.getCallbackGasLimit()
                  const callbackGasLimit = networkConfig[chainId]["callbackGasLimit"]
                  assert.equal(response, callbackGasLimit)
              })
              it("should return correct request confirmations", async () => {
                  const response = await kryptorena.getRequestConfirmations()
                  const requestConfirmations = "3"
                  assert.equal(response, requestConfirmations)
              })

              it("should return correct number of random words", async () => {
                  const response = await kryptorena.getNumWords()
                  const numWords = "1"
                  assert.equal(response, numWords)
              })

              it("should have at least one token Uri", async () => {
                  const response = await kryptorena.getNftUriList()
                  assert.equal(response.length > 0, true)
              })

              it("should return URI at index", async () => {
                  const response = await kryptorena.getNftUriAtIndex(0)
                  assert.equal(tokenUris.includes(response.toString()), true)
              })
          })

          describe("requestNft", function () {
              it("should revert with error if not enough funds sent", async () => {
                  await expect(kryptorena.requestNft()).to.be.revertedWith(
                      "KryptorenaNft__NeedMoreAVAXSent"
                  )
              })

              it("Check that the request ID was generated correctly", async () => {
                  const tx = await kryptorena.requestNft({ value: mintFee })
                  const txReceipt = await tx.wait(1)
                  const requestId = txReceipt.events[1].args.requestId
                  expect(requestId).to.not.be.null
                  expect(requestId).to.not.equal(0)
              })

              it("emits NftRequested event when nft gets requested", async () => {
                  await expect(await kryptorena.requestNft({ value: mintFee })).to.emit(
                      kryptorena,
                      "NftRequested"
                  )
              })
          })

          describe("withdraw", function () {
              it("should withdraw entire contract balance", async () => {
                  //   const accounts = await ethers.getSigners()
                  // await kryptorena.connect(accounts[1]).requestNft({ value: mintFee })
                  const startingDeployerBalance = await kryptorena.provider.getBalance(deployer)
                  const startingContractBalance = await kryptorena.provider.getBalance(
                      kryptorena.address
                  )

                  const mint = await kryptorena.requestNft({ value: mintFee })
                  const mintReceipt = await mint.wait(1)
                  const { gasUsed, effectiveGasPrice } = mintReceipt
                  mintGasCost = gasUsed.mul(effectiveGasPrice)
                  const transaction = await kryptorena.withdraw()
                  const transactionReceipt = await transaction.wait(1)
                  withdrawGasUsed = transactionReceipt.gasUsed
                  withdrawEffectiveGasPrice = transactionReceipt.effectiveGasPrice
                  const gasCost = withdrawGasUsed.mul(withdrawEffectiveGasPrice)

                  const endingContractBalance = await kryptorena.provider.getBalance(
                      kryptorena.address
                  )
                  const endingDeployerBalance = await kryptorena.provider.getBalance(deployer)

                  assert.equal(endingContractBalance.toString(), 0)
                  assert.equal(
                      startingDeployerBalance
                          .add(startingContractBalance)
                          .sub(mintGasCost)
                          .toString(),
                      endingDeployerBalance.add(gasCost).toString()
                  )
              })
          })
          describe("fulfillRandomWord", function () {
              it("mints NFT after random number is returned", async function () {
                  await new Promise(async (resolve, reject) => {
                      kryptorena.once("NftMinted", async () => {
                          try {
                              const tokenUri = await kryptorena.tokenURI("0")
                              const tokenCounter = await kryptorena.getTokenCounter()
                              assert.equal(tokenUri.toString().includes("ipfs://"), true)
                              assert.equal(tokenCounter.toString(), "1")
                              await expect(
                                  kryptorena.requestNft({ value: mintFee })
                              ).to.be.revertedWith("KryptorenaNft__AlreadyMintedNft")
                              resolve()
                          } catch (e) {
                              console.log(e)
                              reject(e)
                          }
                      })
                      try {
                          await kryptorena.requestNft({ value: mintFee })
                      } catch (e) {
                          console.log(e)
                          reject(e)
                      }
                  })
              })
          })
      })
