// require("@nomiclabs/hardhat-waffle")
// require("@nomiclabs/hardhat-etherscan")
// require("hardhat-deploy")
// require("solidity-coverage")
// require("hardhat-gas-reporter")
// require("hardhat-contract-sizer")
// require("dotenv").config()

// /** @type import('hardhat/config').HardhatUserConfig */
// const GOERLI = process.env.GOERLI_URL || ""
// const PRIVATE_KEY = process.env.PRIVATE_KEY || ""
// const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || ""
// const FUJI = process.env.FUJI_URL || ""
// const FUJI_PRIVATE_KEY = process.env.FUJI_PRIVATE_KEY || ""
// module.exports = {
//     defaultNetwork: "hardhat",
//     networks: {
//         goerli: {
//             url: GOERLI,
//             accounts: [PRIVATE_KEY],
//             chainId: 5,
//             blockConfirmations: 2,
//         },
//         fuji: {
//             url: FUJI,
//             accounts: [FUJI_PRIVATE_KEY],
//             chainId: 43113,
//             blockConfirmations: 1,
//         },
//     },
//     localhost: {
//         url: "http://127.0.0.1:8545/",
//         chainId: 31337,
//     },
//     solidity: {
//         compilers: [
//             { version: "0.8.16" },
//             { version: "0.8.8" },
//             { version: "0.8.7" },
//             { version: "0.8.3" },
//             { version: "0.8.0" },
//             { version: "0.6.6" },
//         ],
//     },
//     etherscan: {
//         apiKey: ETHERSCAN_API_KEY,
//     },
//     //Use to keep track of accounts that are deploying contracts
//     namedAccounts: {
//         deployer: {
//             //if using default network, use account (private key) in 0th position
//             default: 0,
//         },
//         player1: {
//             default: 1,
//         },
//         player2: {
//             default: 2,
//         },
//     },
//     gasReporter: {
//         enabled: true,
//         outputFile: "gas-report.txt",
//         noColors: true,
//     },
//     mocha: {
//         timeout: 200000,
//     },
// }

import dotenv from 'dotenv';
import '@nomiclabs/hardhat-ethers';

dotenv.config();

//* Notes for deploying the smart contract on your own subnet
//* More info on subnets: https://docs.avax.network/subnets
//* Why deploy on a subnet: https://docs.avax.network/subnets/when-to-use-subnet-vs-c-chain
//* How to deploy on a subnet: https://docs.avax.network/subnets/create-a-local-subnet
//* Transactions on the C-Chain might take 2-10 seconds -> the ones on the subnet will be much faster
//* On C-Chain we're relaying on the Avax token to confirm transactions -> on the subnet we can create our own token
//* You are in complete control over the network and it's inner workings

export default {
  solidity: {
    version: '0.8.16',
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 100,
      },
    },
  },
  networks: {
    fuji: {
      url: 'https://api.avax-test.network/ext/bc/C/rpc',
      gasPrice: 225000000000,
      chainId: 43113,
      accounts: [process.env.PRIVATE_KEY],
    },
    // subnet: {
    //   url: process.env.NODE_URL,
    //   chainId: Number(process.env.CHAIN_ID),
    //   gasPrice: 'auto',
    //   accounts: [process.env.PRIVATE_KEY],
    // },
  },
}