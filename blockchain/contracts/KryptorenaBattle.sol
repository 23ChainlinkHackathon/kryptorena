// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./Kryptorena.sol";

contract KryptorenaBattle is VRFConsumerBaseV2, Ownable {
    //contract
    Kryptorena public i_kryptorena;

    //VRF variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    //Battle Variables
    enum AttackOrDefense {
        UNDEFINED,
        ATTACK,
        DEFEND
    }
    enum endStatus {
        UNDEFINED,
        WON,
        LOST,
        DRAW
    }

    struct Battle {
        uint256 battleId;
        address player1;
        address player2;
        int256 player1HP;
        uint256 player1AttackPoints;
        uint256 player1DefensePoints;
        int256 player2HP;
        uint256 player2AttackPoints;
        uint256 player2DefensePoints;
        AttackOrDefense player1Choice;
        AttackOrDefense player2Choice;
    }

    struct BattleData {
        endStatus player1;
        endStatus player2;
        bool player1ChoiceMade;
        bool player2ChoiceMade;
        uint256 turn;
        // uint256 matchDuration;
        // uint256 lastTurnTimestamp;
        // uint256 turnDuration;
    }

    /**
     * @notice 'battles' mapping associates the battleId with Battle struct to store information about the battle
     * @notice 'currentMatch'is used to keep track of the ongoing battle for each player participating in the game
     * @notice 's_requestIdToSender' works with Chainlink VRF to keep track of message sender
     */

    mapping(uint256 => Battle) public battles;
    mapping(address => Battle) public currentMatch;
    mapping(uint256 => BattleData) public matchData;
    mapping(address => BattleData) public matchDataPlayerTracker;

    mapping(uint256 => address) public s_requestIdToSender;

    uint256 public battleId;
    bool public initialized;
    uint256 public constant MAX_TURNS = 5;

    event BattleResult(uint256 indexed battleId, address winner);
    event RngRequested(uint256 indexed requestId, address winner);

    event BattleCreated(uint256 indexed battleId, address player1, address player2);

    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 gasLane,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2) Ownable() {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_subscriptionId = subscriptionId;
        i_gasLane = gasLane;
        i_callbackGasLimit = callbackGasLimit;
        battleId = 0;
        initialized = false;
    }

    function initiateContract(address kryptorena) public onlyOwner {
        require(!initialized, "Already initialized");
        i_kryptorena = Kryptorena(kryptorena);
        initialized = true;
    }

    /**
     * @notice arguements come from game logic contract
     * @notice maps battleId to Battle Struct for this specific match between specific players
     * @notice currentMatch[address] links each player to this specific battle struct with ID for future reference
     */
    function initiateBattle(
        address player1,
        address player2,
        uint256 player1AttackPoints,
        uint256 player1DefensePoints,
        uint256 player2AttackPoints,
        uint256 player2DefensePoints
    ) external {
        //require that neither player is in another battle => Game logic contract can take care of this.
        require(msg.sender == address(i_kryptorena));
        require(player1 != address(0), "Invalid player.");
        require(player2 != address(0), "Invalid player.");

        battleId++;
        battles[battleId] = Battle(
            battleId,
            player1,
            player2,
            10,
            player1AttackPoints,
            player1DefensePoints,
            10,
            player2AttackPoints,
            player2DefensePoints,
            AttackOrDefense.UNDEFINED,
            AttackOrDefense.UNDEFINED
            // 0
        );
        matchData[battleId] = BattleData(
            endStatus.UNDEFINED,
            endStatus.UNDEFINED,
            false,
            false,
            0
            // 60,
            // block.timestamp,
            // 15
        );

        currentMatch[player1] = battles[battleId];
        currentMatch[player2] = battles[battleId];

        matchDataPlayerTracker[player1] = matchData[battleId];
        matchDataPlayerTracker[player2] = matchData[battleId];

        emit BattleCreated(battleId, player1, player2);
    }

    // TO DO:
    // and that the battle is still active and that there does exist a battle between both addresses.
    // and that users HP is not zero
    // and that each user only takes one action per turn

    //How to prevent users for taking two turns in one?

    /**
     * @notice 'round' references the current players ongoing match
     */
    function attack() external {
        Battle storage round = currentMatch[msg.sender];
        BattleData storage resultData = matchDataPlayerTracker[msg.sender];

        // require(
        //     block.timestamp <= resultData.lastTurnTimestamp + resultData.turnDuration,
        //     "Turn time limit exceeded"
        // );
        require(resultData.turn <= MAX_TURNS, "There are no more turns to this match!");
        require(
            msg.sender == round.player1 || msg.sender == round.player2,
            "Player is not in this battle"
        );

        if (msg.sender == round.player1) {
            round.player1Choice = AttackOrDefense.ATTACK;
        } else {
            round.player2Choice = AttackOrDefense.ATTACK;
        }
    }

    function defend() external {
        Battle storage round = currentMatch[msg.sender];
        BattleData storage resultData = matchDataPlayerTracker[msg.sender];

        // require(
        //     block.timestamp <= resultData.lastTurnTimestamp + resultData.turnDuration,
        //     "Match time limit exceeded"
        // );
        require(resultData.turn <= MAX_TURNS, "There are no more turns to this match!");
        require(
            msg.sender == round.player1 || msg.sender == round.player2,
            "Player is not in this battle"
        );

        if (msg.sender == round.player1) {
            round.player1Choice = AttackOrDefense.DEFEND;
        } else {
            round.player2Choice = AttackOrDefense.DEFEND;
        }
    }

    function turnAction(address player) private returns (string memory) {
        BattleData storage resultData = matchDataPlayerTracker[msg.sender];
        Battle storage round = currentMatch[player];
        string memory message;
        if (
            round.player1Choice == AttackOrDefense.ATTACK &&
            round.player2Choice == AttackOrDefense.ATTACK
        ) {
            round.player1HP = round.player1HP - int(round.player2AttackPoints);
            round.player2HP = round.player2HP - int(round.player1AttackPoints);
            message = "Both players attacked!";
        } else if (
            round.player1Choice == AttackOrDefense.ATTACK &&
            round.player2Choice == AttackOrDefense.DEFEND
        ) {
            if (round.player2DefensePoints - round.player1AttackPoints > 0) {
                round.player2HP =
                    round.player2HP -
                    int(round.player2DefensePoints - round.player1AttackPoints);
            }
            message = "Player 1 attacked and Player 2 defended!";
        } else if (
            round.player1Choice == AttackOrDefense.DEFEND &&
            round.player2Choice == AttackOrDefense.ATTACK
        ) {
            if (round.player1DefensePoints - round.player2AttackPoints > 0) {
                round.player1HP =
                    round.player1HP -
                    int(round.player1DefensePoints - round.player2AttackPoints);
            }
            message = "Player 1 defended and Player 2 attacked!";
        } else if (
            round.player1Choice == AttackOrDefense.DEFEND &&
            round.player2Choice == AttackOrDefense.DEFEND
        ) {
            message = "Both players defended! No damage done.";
        } else if (
            round.player1Choice == AttackOrDefense.ATTACK &&
            round.player2Choice == AttackOrDefense.UNDEFINED
        ) {
            round.player2HP = round.player2HP - int(round.player1AttackPoints);
            message = "Player 1 attacked, Player 2 chose nothing!";
        } else if (
            round.player1Choice == AttackOrDefense.DEFEND &&
            round.player2Choice == AttackOrDefense.UNDEFINED
        ) {
            message = "Player 1 defended, Player 2 chose nothing!";
        } else if (
            round.player1Choice == AttackOrDefense.UNDEFINED &&
            round.player2Choice == AttackOrDefense.ATTACK
        ) {
            round.player1HP = round.player1HP - int(round.player2AttackPoints);
            message = "Player 2 attacked, Player 1 chose nothing!";
        } else if (
            round.player1Choice == AttackOrDefense.UNDEFINED &&
            round.player2Choice == AttackOrDefense.DEFEND
        ) {
            message = "Player 2 defended, Player 1 chose nothing!";
        }

        resultData.turn += 1;

        if (round.player1HP < 0) {
            round.player1HP = 0;
        }
        if (round.player2HP < 0) {
            round.player1HP = 0;
        }

        if (round.player1HP == 0 || round.player2HP == 0 || resultData.turn == MAX_TURNS) {
            endGame(player);
        }

        return message;
    }

    /**
     * @notice This function triggers after both players have chosen their move
     * @param player address of any player in order to reference the match that is ongoing
     */

    function endGame(address player) private {
        //battle status ended
        Battle storage round = currentMatch[player];
        BattleData storage resultData = matchDataPlayerTracker[player];
        if (round.player1HP > round.player2HP) {
            resultData.player1 = endStatus.WON;
            resultData.player2 = endStatus.LOST;
        } else if (round.player1HP == round.player2HP) {
            resultData.player2 = resultData.player1 = endStatus.DRAW;
        } else {
            resultData.player1 = endStatus.LOST;
            resultData.player2 = endStatus.WON;
        }
        address winner;
        if (resultData.player1 == endStatus.WON) {
            winner = round.player1;
            requestRandomWord(winner);
        } else if (resultData.player2 == endStatus.WON) {
            winner = round.player2;
            requestRandomWord(winner);
        } else {
            winner = address(0);
            i_kryptorena.updateStats(address(0), 0, 0);
        }
        emit BattleResult(round.battleId, winner);
    }

    function requestRandomWord(address winner) private returns (uint256 requestId) {
        requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        s_requestIdToSender[requestId] = winner;
    }

    /**
     * @notice randomizes the new stats for winner depending on difference of HP
     */

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 randomNumber = randomWords[0];

        address winner = s_requestIdToSender[requestId];
        Battle storage round = currentMatch[winner];
        uint256 s_HP_DIFFERENCE = uint256(absoluteValue(round.player1HP, round.player2HP));
        uint256 rngAttackValue = randomNumber % s_HP_DIFFERENCE;
        uint256 rngDefenseValue = s_HP_DIFFERENCE - rngAttackValue;

        if (winner == round.player1) {
            round.player1AttackPoints += rngAttackValue;
            round.player1DefensePoints += rngDefenseValue;
            i_kryptorena.updateStats(winner, round.player1AttackPoints, round.player1DefensePoints);
        } else {
            round.player2AttackPoints += rngAttackValue;
            round.player2DefensePoints += rngDefenseValue;
            i_kryptorena.updateStats(winner, round.player2AttackPoints, round.player2DefensePoints);
        }
    }

    function absoluteValue(int256 player1HP, int256 player2HP) public pure returns (int256) {
        int256 num = player1HP - player2HP;
        if (num >= 0) {
            return num;
        } else {
            return -num;
        }
    }
}
