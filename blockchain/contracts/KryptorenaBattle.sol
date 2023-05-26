// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Kryptorena.sol";

/**
 * @notice This is the battle contract. This contract works in tangent with the game logic contract.
 * Whenever a user starts a battle from the lobby or joins a game it will trigger this contract to 
 * initiate the battle with the user's stats. Initially, this contract will have to be linked with 
 * the Kryptorena game logic contract through the initialize() function. Once two players have 
 * initiated the match, their entire battle will be recorded, including what moves each user took, 
 * the effects of their choices, and in which respective turns. After a winner has been decided, 
 * the Chainlink VRF contract will be used to randomize the HP difference between the winner and 
 * loser and randomly designate this number between a new attack and defense value. These new 
 * attack and defense values will then be sent to the game-logic contract (through endGame()) for 
 * player stat update.
 */

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
        PENDING,
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
        uint256 turn;
        // uint256 matchDuration;
        // uint256 lastTurnTimestamp;
        // uint256 turnDuration;
    }

    /**
     * @notice 'battles' mapping associates the battleId with Battle struct to store information about the battle
     * @notice 'currentMatch'is used to keep track of the ongoing battle for each player participating in the game
     * @notice matchData and matchDataPlayerTracker tracks external battle data such as turn, timers and end results.
     * @notice 's_requestIdToSender' works with Chainlink VRF to keep track of message sender
     */

    mapping(uint256 => Battle) public battles;
    mapping(address => Battle) public currentMatch;
    mapping(uint256 => BattleData) public matchData;
    mapping(address => BattleData) public matchDataPlayerTracker;
    mapping(uint256 => address) public s_requestIdToSender;

    bool public initialized;
    uint256 public battleId;
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

    /**
     * @dev When battle contract is deployed, we link it to the game logic contract through this function
     */

    function initiateContract(address kryptorena) public onlyOwner {
        require(!initialized, "Already initialized");
        i_kryptorena = Kryptorena(kryptorena);
        initialized = true;
    }

    /**
     * @dev arguements come from game logic contract
     * @dev mapping of battleId to Battle Struct is used to track the match between specific addresses (players)
     * @dev currentMatch[address] is used with battleId and Battle struct to call match details with player's address.
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
            AttackOrDefense.PENDING,
            AttackOrDefense.PENDING
            // 0
        );
        matchData[battleId] = BattleData(
            endStatus.UNDEFINED,
            endStatus.UNDEFINED,
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

    /**
     * @notice 'round' references the current players ongoing match
     * It also tracks the choice of the player for the current turn.
     * It successfully calls on turnAction if both players have made a choice.
     */
    function attack() external {
        Battle storage round = currentMatch[msg.sender];
        BattleData storage resultData = matchDataPlayerTracker[msg.sender];

        require(resultData.turn <= MAX_TURNS, "There are no more turns to this match!");
        require(
            msg.sender == round.player1 || msg.sender == round.player2,
            "Player is not in this battle"
        );
        if (msg.sender == round.player1) {
            require(round.player1Choice == AttackOrDefense.PENDING, "You've already taken a turn");
        } else if (msg.sender == round.player2) {
            require(round.player2Choice == AttackOrDefense.PENDING, "You've already taken a turn");
        }

        // require(
        //     block.timestamp <= resultData.lastTurnTimestamp + resultData.turnDuration,
        //     "Turn time limit exceeded"
        // );

        if (msg.sender == round.player1) {
            round.player1Choice = AttackOrDefense.ATTACK;
        } else {
            round.player2Choice = AttackOrDefense.ATTACK;
        }

        if (
            round.player1Choice != AttackOrDefense.PENDING &&
            round.player2Choice != AttackOrDefense.PENDING
        ) {
            turnAction(msg.sender);
        }
    }

    function defend() external {
        Battle storage round = currentMatch[msg.sender];
        BattleData storage resultData = matchDataPlayerTracker[msg.sender];

        require(resultData.turn <= MAX_TURNS, "There are no more turns to this match!");
        require(
            msg.sender == round.player1 || msg.sender == round.player2,
            "Player is not in this battle"
        );
        if (msg.sender == round.player1) {
            require(round.player1Choice == AttackOrDefense.PENDING, "You've already taken a turn");
        } else if (msg.sender == round.player2) {
            require(round.player2Choice == AttackOrDefense.PENDING, "You've already taken a turn");
        }

        // require(
        //     block.timestamp <= resultData.lastTurnTimestamp + resultData.turnDuration,
        //     "Match time limit exceeded"
        // );

        if (msg.sender == round.player1) {
            round.player1Choice = AttackOrDefense.DEFEND;
        } else {
            round.player2Choice = AttackOrDefense.DEFEND;
        }

        if (
            round.player1Choice != AttackOrDefense.PENDING &&
            round.player2Choice != AttackOrDefense.PENDING
        ) {
            turnAction(msg.sender);
        }
    }

    /**
     * @dev Executes battle logic depending on user's choice. Function only triggers when both players have taken a turn.
     * @param player address of any player in order to reference the match that is ongoing
     * Optional: If game is being held hostage chainlink automation can trigger this function. Status: PENDING
     * If any user's HP is zero or the amount of turns is equal to MAX_TURNS, it will trigger the endGame() function.
     * Adds to round turn.
     * Returns string message with players decision for better readability in front end.
     */

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
            round.player2Choice == AttackOrDefense.PENDING
        ) {
            round.player2HP = round.player2HP - int(round.player1AttackPoints);
            message = "Player 1 attacked, Player 2 chose nothing!";
        } else if (
            round.player1Choice == AttackOrDefense.DEFEND &&
            round.player2Choice == AttackOrDefense.PENDING
        ) {
            message = "Player 1 defended, Player 2 chose nothing!";
        } else if (
            round.player1Choice == AttackOrDefense.PENDING &&
            round.player2Choice == AttackOrDefense.ATTACK
        ) {
            round.player1HP = round.player1HP - int(round.player2AttackPoints);
            message = "Player 2 attacked, Player 1 chose nothing!";
        } else if (
            round.player1Choice == AttackOrDefense.PENDING &&
            round.player2Choice == AttackOrDefense.DEFEND
        ) {
            message = "Player 2 defended, Player 1 chose nothing!";
        }

        if (round.player1HP < 0) {
            round.player1HP = 0;
        }
        if (round.player2HP < 0) {
            round.player1HP = 0;
        }

        if (round.player1HP == 0 || round.player2HP == 0 || resultData.turn == MAX_TURNS) {
            endGame(player);
        }

        resultData.turn += 1;

        round.player1Choice = AttackOrDefense.PENDING;
        round.player2Choice = AttackOrDefense.PENDING;

        return message;
    }

    /**
     * @notice This function triggers after end game conditions have been met.
     * End game conditions: A player has zero HP or the max amount of turns has been reached.
     * It will assign the status of winner or loser accordingly and request for VRF function
     * Emits an event.
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

    /**
     * @notice Creates a requestId for chainlink VRF that will trigger fulfillrandomWord function
     * Emits event.
     */

    function requestRandomWord(address winner) private returns (uint256 requestId) {
        requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        s_requestIdToSender[requestId] = winner;
        emit RngRequested(requestId, winner);
    }

    /**
     * @notice randomizes the new stats for winner depending on difference of HP
     * Calls absoluteValue function to guarantee the difference of HP is a positive value.
     * Returns new attack and defense values to game logic contract.
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

    /**
     * @notice Used to return positive number between two int256 values
     */

    function absoluteValue(int256 player1HP, int256 player2HP) public pure returns (int256) {
        int256 num = player1HP - player2HP;
        if (num >= 0) {
            return num;
        } else {
            return -num;
        }
    }
}
