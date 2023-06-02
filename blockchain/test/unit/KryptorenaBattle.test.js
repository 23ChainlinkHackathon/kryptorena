const { assert, expect } = require("chai")
const { network, deployments, ethers, getNamedAccounts } = require("hardhat")
const { developmentChains, networkConfig } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("KryptorenaBattle Tests", function () {
          let kryptorena, deployer, vrfCoordinatorV2Mock, mintFee
          const chainId = network.config.chainId

          beforeEach(async () => {
              deployer = (await getNamedAccounts()).deployer
              player1 = (await getNamedAccounts()).player1
              player2 = (await getNamedAccounts()).player2
              await deployments.fixture(["all"])
              battle = await ethers.getContract("KryptorenaBattle", deployer)
              kryptorena = await ethers.getContract("Kryptorena", deployer)
              vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock", deployer)
              await battle.initiateContract(kryptorena.address)
          })

          describe("constructor", function () {
              it("Tests for attack and defend", async () => {
                  const accounts = await ethers.getSigners()

                  const initiate = await kryptorena.triggerBattle()
                  let response = await battle.s_battles(1) //get starting stats
                  console.log(response.toString())

                  await battle.connect(accounts[1]).attack()
                  response2 = await battle.s_battles(1)
                  console.log(response2.toString())

                  await battle.connect(accounts[2]).attack()
                  response3 = await battle.s_battles(1)
                  console.log(response3.toString())

                  response5 = await battle.s_battleData(1)
                  console.log(response5.toString())

                  console.log(
                      "=========================== TURN 2 ==================================="
                  )
                  await battle.connect(accounts[1]).attack()
                  response6 = await battle.s_battles(1)
                  console.log(response6.toString())

                  await battle.connect(accounts[2]).defend()
                  response7 = await battle.s_battles(1)
                  console.log(response7.toString())

                  response8 = await battle.s_battleData(1)
                  console.log(response8.toString())

                  console.log(
                      "=========================== TURN 3 ==================================="
                  )

                  await battle.connect(accounts[1]).defend()
                  response9 = await battle.s_battles(1)
                  console.log(response9.toString())

                  await battle.connect(accounts[2]).attack()
                  response10 = await battle.s_battles(1)
                  console.log(response10.toString())

                  response11 = await battle.s_battleData(1)
                  console.log(response11.toString())

                  console.log(
                      "=========================== TURN 4 ==================================="
                  )

                  await battle.connect(accounts[1]).defend()
                  response12 = await battle.s_battles(1)
                  console.log(response12.toString())

                  await battle.connect(accounts[2]).defend()
                  response13 = await battle.s_battles(1)
                  console.log(response13.toString())

                  response14 = await battle.s_battleData(1)
                  console.log(response14.toString())

                  console.log(
                      "=========================== TURN 5 ==================================="
                  )

                  await battle.connect(accounts[1]).attack()
                  response15 = await battle.s_battles(1)
                  console.log(response15.toString())

                  await battle.connect(accounts[2]).attack()
                  response16 = await battle.s_battles(1)
                  console.log(response16.toString())

                  response17 = await battle.s_battleData(1)
                  console.log(response17.toString())
              })
          })
      })
