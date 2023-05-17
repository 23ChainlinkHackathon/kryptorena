const { assert, expect } = require("chai")
const { network, deployments, ethers, getNamedAccounts } = require("hardhat")
const { developmentChains, networkConfig } = require("../../helper-hardhat-config")
const { tokenUris, subscriptionId } = require("/home/robitu/personal/MY_NFT/deploy/01-deploy-MyNft")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("KryptorenaNft Tests", function () {
          let kryptorena, deployer, vrfCoordinatorV2Mock, mintFee
          const chainId = network.config.chainId

          beforeEach(async () => {
              deployer = (await getNamedAccounts()).deployer
              await deployments.fixture(["all"])
              kryptorena = await ethers.getContract("KryptorenaNft", deployer)
              vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock", deployer)
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
                  const subId = "1"
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
              it("should store the sender address in a mapping with the correct request ID", async () => {
                  const tx = await kryptorena.requestNft({ value: mintFee })
                  const txReceipt = await tx.wait(1)
                  const requestId = txReceipt.events[1].args.requestId
                  const response = await kryptorena.getRequestIdToSender(requestId.toString())
                  assert.equal(response, deployer)
              })
              it("emits NftRequested event when nft gets requested", async () => {
                  await expect(await kryptorena.requestNft({ value: mintFee })).to.emit(
                      kryptorena,
                      "NftRequested"
                  )
              })
              it("should revert with error if user has already minted NFT", async () => {
                  await new Promise(async (resolve, reject) => {
                      kryptorena.once("NftMinted", async () => {
                          try {
                              await expect(
                                  kryptorena.requestNft({ value: mintFee })
                              ).to.be.revertedWith("KryptorenaNft__AlreadyMintedNft")
                              resolve()
                          } catch (e) {
                              console.log(e)
                              reject(e)
                          }
                      })
                      const tx = await kryptorena.requestNft({ value: mintFee })
                      const txReceipt = await tx.wait(1)
                      await vrfCoordinatorV2Mock.fulfillRandomWords(
                          txReceipt.events[1].args.requestId,
                          kryptorena.address
                      )
                  })
              })
          })
          describe("fulfillRandomWords", function () {
              it("correctly sets NFT owner", async () => {
                  await new Promise(async (resolve, reject) => {
                      kryptorena.once("NftMinted", async () => {
                          try {
                              const nftOwner = await kryptorena.getRequestIdToSender(
                                  txReceipt.events[1].args.requestId
                              )
                              assert.equal(nftOwner, deployer)
                              resolve()
                          } catch (e) {
                              console.log(e)
                              reject(e)
                          }
                      })
                      const tx = await kryptorena.requestNft({ value: mintFee })
                      const txReceipt = await tx.wait(1)
                      await vrfCoordinatorV2Mock.fulfillRandomWords(
                          txReceipt.events[1].args.requestId,
                          kryptorena.address
                      )
                  })
              })

              it("Token counter goes up after each NFT request", async () => {
                  await new Promise(async (resolve, reject) => {
                      kryptorena.once("NftMinted", async () => {
                          try {
                              const postMintCount = await kryptorena.getTokenCounter()
                              assert.equal("1", postMintCount.toString())
                              resolve()
                          } catch (e) {
                              console.log(e)
                              reject(e)
                          }
                      })
                      const tx = await kryptorena.requestNft({ value: mintFee })
                      const txReceipt = await tx.wait(1)
                      await vrfCoordinatorV2Mock.fulfillRandomWords(
                          txReceipt.events[1].args.requestId,
                          kryptorena.address
                      )
                  })
              })

              it("should store URI string to NFT owner", async () => {
                  await new Promise(async (resolve, reject) => {
                      kryptorena.once("NftMinted", async () => {
                          try {
                              const response = await kryptorena.getUriOfAddress(deployer)
                              assert(tokenUris.includes(response), true)
                              resolve()
                          } catch (e) {
                              console.log(e)
                              reject(e)
                          }
                      })
                      const tx = await kryptorena.requestNft({ value: mintFee })
                      const txReceipt = await tx.wait(1)
                      await vrfCoordinatorV2Mock.fulfillRandomWords(
                          txReceipt.events[1].args.requestId,
                          kryptorena.address
                      )
                  })
              })

              it("mints NFT after random number is returned", async function () {
                  await new Promise(async (resolve, reject) => {
                      kryptorena.once("NftMinted", async () => {
                          try {
                              const tokenUri = await kryptorena.tokenURI("0")
                              const tokenCounter = await kryptorena.getTokenCounter()
                              assert.equal(tokenUri.toString().includes("ipfs://"), true)
                              assert.equal(tokenCounter.toString(), "1")
                              resolve()
                          } catch (e) {
                              console.log(e)
                              reject(e)
                          }
                      })
                      try {
                          const requestNftResponse = await kryptorena.requestNft({ value: mintFee })
                          const requestNftReceipt = await requestNftResponse.wait(1)
                          await vrfCoordinatorV2Mock.fulfillRandomWords(
                              requestNftReceipt.events[1].args.requestId,
                              kryptorena.address
                          )
                      } catch (e) {
                          console.log(e)
                          reject(e)
                      }
                  })
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

              it("Should revert with error if transfer fails", async () => {
                  const MockContract = await ethers.getContractFactory("MockContract")
                  const mockContract = await MockContract.deploy(tokenUris)
                  await mockContract.deployed()

                  await expect(mockContract.targetWithdraw()).to.be.revertedWith(
                      "Kryptorena__TransferFailed"
                  )
              })
          })
      })
