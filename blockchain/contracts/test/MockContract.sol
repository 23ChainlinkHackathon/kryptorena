// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../KryptorenaNft.sol";

contract MockContract {
    KryptorenaNft targetContract;

    constructor(string[] memory NFTTokenUris) {
        targetContract = new KryptorenaNft(
            0x5FbDB2315678afecb367f032d93F642f64180aa3,
            1,
            0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61,
            2500000,
            NFTTokenUris,
            100000000
        );
    }

    function targetWithdraw() external {
        targetContract.withdraw();
    }
}
