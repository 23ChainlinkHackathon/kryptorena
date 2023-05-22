// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

contract KryptorenaBattle is VRFConsumerBaseV2, ConfirmedOwner {
    //VRF variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    //Battle Variables
    enum AttackOrDefense {
        GAME_START,
        ATTACK,
        DEFEND
    }

    struct Battle {
        address player1;
        address player2;
        uint256 player1AttackPoints;
        uint256 player1DefensePoints;
        uint256 player2AttackPoints;
        uint256 player2DefensePoints;
        AttackOrDefense player1Choice;
        AttackOrDefense player2Choice;
        uint256 turn;
    }

    mapping(uint256 => Battle) public battles;
    mapping(address => Battle) public currentMatch;
    uint256 public battleCount;

    event BattleResult(uint256 battleId, address winner);

    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 gasLane,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2) ConfirmedOwner(msg.sender) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_subscriptionId = subscriptionId;
        i_gasLane = gasLane;
        i_callbackGasLimit = callbackGasLimit;
        battleCount = 0;
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {}

    // Randomize who begins the battle
    function initiateBattle(
        address player1,
        address player2,
        uint256 player1AttackPoints,
        uint256 player1DefensePoints,
        uint256 player2AttackPoints,
        uint256 player2DefensePoints
    ) external {
        require(player1 != address(0), "Invalid player.");
        require(player2 != address(0), "Invalid player.");

        battleCount++;
        battles[battleCount] = Battle(
            player1,
            player2,
            player1AttackPoints,
            player1DefensePoints,
            player2AttackPoints,
            player2DefensePoints,
            AttackOrDefense.GAME_START,
            AttackOrDefense.GAME_START,
            0
        );
        currentMatch[player1] = battles[battleCount];
        currentMatch[player2] = battles[battleCount];

        emit BattleResult(battleCount, address(0));
    }

    // Require that for each attack and defend options that it is the player's respective turn and that the timer has not gone off
    // and that the battle is still active and that there does exist a battle between both addresses.
    // and that users HP is not zero
    function attack() external {
        Battle storage round = currentMatch[msg.sender];
        if (msg.sender == round.player1) {
            round.player1Choice = AttackOrDefense.ATTACK;
        } else {
            round.player2Choice = AttackOrDefense.ATTACK;
        }
        round.turn += 1;
        if (round.turn % 2 == 0) {
            turnAction(msg.sender);
        }
    }

    function defend() external {
        Battle storage round = currentMatch[msg.sender];
        if (msg.sender == round.player1) {
            round.player1Choice = AttackOrDefense.DEFEND;
        } else {
            round.player2Choice = AttackOrDefense.DEFEND;
        }
        round.turn += 1;
        if (round.turn % 2 == 0) {
            turnAction(msg.sender);
        }
    }

    function turnAction(address player) private {}
}
