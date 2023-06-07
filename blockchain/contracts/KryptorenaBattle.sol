// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Kryptorena.sol";
import "hardhat/console.sol";

/**
 * @title KryptorenaBattle
 * @author Roberto Iturralde
 */

/**
 * @notice This is the battle contract. This contract works in tangent with kryptorena.sol contract.
 * Whenever a user starts a battle from the lobby or joins a game it will trigger this contract to
 * initiate the battle with the user's stats. Initially, this contract will have to be linked with
 * the Kryptorena.sol game logic contract through the initialize() function. Once two players have
 * initiated the match, their entire battle will be recorded, including what moves each user took,
 * the effects of their choices, and keep track of the turns taken. After a winner has been decided,
 * the Chainlink VRF contract will be used to randomize the HP difference between the winner and
 * loser and randomly designate this number between a new attack and defense value. These new
 * attack and defense values will then be sent to the kryptorena.sol contract.
//  */

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
    //Current state of the battle
    enum BattleStatus {
        ONGOING,
        ENDED
    }

    //Player's current turn choice
    enum AttackOrDefense {
        PENDING,
        ATTACK,
        DEFEND
    }

    //Player's end game results.
    enum EndStatus {
        ONGOING,
        WON,
        LOST,
        DRAW
    }

    /**
     * @dev This is the boilerplate for each battle that tracks information about the specific
     * battleId, player addresses, HP, attack/defense stats, and choices. A new BattleFrame struct
     * is created when a battle initiates.
     */
    struct BattleFrame {
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

    /**
     * @dev BattleData struct tracks additional battle information such as the winner, loser
     * the end turn, current state of the battle and the final difference in HP between both
     * players that will help in updating the winner's stats.
     */
    struct BattleData {
        EndStatus player1;
        EndStatus player2;
        uint256 turn;
        BattleStatus battleState;
        uint256 hpDifference;
    }

    /**
     * @dev 's_battles' mapping associates the battleId with Battle struct to store information about the battle (hp, attack, defense points, choices)
     * 's_playerToBattle'is used to keep track of the specific battle between two players using any of their addresses.
     * 's_battleData tracks' background battle data such as turn, timers and end results.
     * 's_requestIdToSender' works with Chainlink VRF to keep track of message sender
     */
    mapping(uint256 => BattleFrame) public s_battleFrames;
    mapping(address => BattleFrame) public s_playerToBattle;
    mapping(uint256 => BattleData) public s_battleData;
    mapping(uint256 => address) public s_requestIdToSender;

    bool public s_contractInitialized;
    uint256 public s_battleId;
    uint256 public constant MAX_TURNS = 5;

    event BattleEnded(uint256 battleId, address indexed winner, address indexed loser);
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
        s_battleId = 0;
        s_contractInitialized = false;
    }

    /**
     * @dev arguements come from game logic contract
     * @dev mapping of battleId to Battle Struct is used to track the match between specific addresses (players)
     * @dev s_playerToBattle[address] is used with battleId and Battle struct to call match details with player's address.
     */
    function initiateBattle(
        address player1,
        address player2,
        uint256 player1AttackPoints,
        uint256 player1DefensePoints,
        uint256 player2AttackPoints,
        uint256 player2DefensePoints
    ) external {
        require(
            msg.sender == address(i_kryptorena),
            "Battle must be initiated from kryptorena.sol"
        );
        require(player1 != address(0), "Invalid player.");
        require(player2 != address(0), "Invalid player.");

        s_battleId++;
        s_battleFrames[s_battleId] = BattleFrame(
            s_battleId,
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

        s_battleData[s_battleId] = BattleData(
            EndStatus.ONGOING,
            EndStatus.ONGOING,
            0,
            BattleStatus.ONGOING,
            0
        );

        s_playerToBattle[player1] = s_battleFrames[s_battleId];
        s_playerToBattle[player2] = s_battleFrames[s_battleId];

        emit BattleCreated(s_battleId, player1, player2);
    }

    /**
     * @notice 'currentMatch' references the current players ongoing match
     * It also tracks the choice of the player for the current turn.
     * It successfully calls on turnAction if both players have made a choice.
     */
    function attack() public {
        uint256 id = s_playerToBattle[msg.sender].battleId;
        BattleFrame storage currentMatch = s_battleFrames[id];
        BattleData storage currentMatchData = s_battleData[id];

        require(currentMatchData.battleState != BattleStatus.ENDED);
        require(currentMatchData.turn <= MAX_TURNS, "There are no more turns to this match!");
        require(
            msg.sender == currentMatch.player1 || msg.sender == currentMatch.player2,
            "Player is not in this battle"
        );
        if (msg.sender == currentMatch.player1) {
            require(
                currentMatch.player1Choice == AttackOrDefense.PENDING,
                "You've already taken a turn"
            );
        } else if (msg.sender == currentMatch.player2) {
            require(
                currentMatch.player2Choice == AttackOrDefense.PENDING,
                "You've already taken a turn"
            );
        }

        if (msg.sender == currentMatch.player1) {
            currentMatch.player1Choice = AttackOrDefense.ATTACK;
        } else {
            currentMatch.player2Choice = AttackOrDefense.ATTACK;
        }

        if (
            currentMatch.player1Choice != AttackOrDefense.PENDING &&
            currentMatch.player2Choice != AttackOrDefense.PENDING
        ) {
            endTurn(msg.sender);
        }
    }

    function defend() public {
        uint256 id = s_playerToBattle[msg.sender].battleId;
        BattleFrame storage currentMatch = s_battleFrames[id];
        BattleData storage currentMatchData = s_battleData[id];

        require(currentMatchData.battleState != BattleStatus.ENDED);
        require(currentMatchData.turn <= MAX_TURNS, "There are no more turns to this match!");
        require(
            msg.sender == currentMatch.player1 || msg.sender == currentMatch.player2,
            "Player is not in this battle"
        );
        if (msg.sender == currentMatch.player1) {
            require(
                currentMatch.player1Choice == AttackOrDefense.PENDING,
                "You've already taken a turn"
            );
        } else if (msg.sender == currentMatch.player2) {
            require(
                currentMatch.player2Choice == AttackOrDefense.PENDING,
                "You've already taken a turn"
            );
        }

        if (msg.sender == currentMatch.player1) {
            currentMatch.player1Choice = AttackOrDefense.DEFEND;
        } else {
            currentMatch.player2Choice = AttackOrDefense.DEFEND;
        }

        if (
            currentMatch.player1Choice != AttackOrDefense.PENDING &&
            currentMatch.player2Choice != AttackOrDefense.PENDING
        ) {
            endTurn(msg.sender);
        }
    }

    /**
     * @dev When battle contract is deployed, we link it to kryptorena.sol contract through this function
     */

    function initiateContract(address kryptorena) public onlyOwner {
        require(!s_contractInitialized, "Already initialized");
        i_kryptorena = Kryptorena(kryptorena);
        s_contractInitialized = true;
    }

    /**
     * @notice randomizes the new attack & defense stats for winner depending on difference of HP
     *  between both players. Returns new attack and defense values to game logic contract.
     */

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 randomNumber = randomWords[0];

        address winner = s_requestIdToSender[requestId];
        uint256 id = s_playerToBattle[winner].battleId;
        BattleData storage currentMatchData = s_battleData[id];

        BattleFrame storage currentMatch = s_battleFrames[id];
        uint256 s_HP_DIFFERENCE = currentMatchData.hpDifference;

        uint256 rngAttackValue = randomNumber % s_HP_DIFFERENCE;
        uint256 rngDefenseValue = s_HP_DIFFERENCE - rngAttackValue;

        if (winner == currentMatch.player1) {
            currentMatch.player1AttackPoints += rngAttackValue;
            currentMatch.player1DefensePoints += rngDefenseValue;
            // i_kryptorena.updateStats(
            //     winner,
            //     currentMatch.player1AttackPoints,
            //     currentMatch.player1DefensePoints
            // );
        } else {
            currentMatch.player2AttackPoints += rngAttackValue;
            currentMatch.player2DefensePoints += rngDefenseValue;
            // i_kryptorena.updateStats(
            //     winner,
            //     currentMatch.player2AttackPoints,
            //     currentMatch.player2DefensePoints
            // );
        }
    }

    /**
     * @dev Executes battle logic depending on user's choice. Function only triggers when both players have taken a turn.
     * @param player address of any player in order to call the battle that the player is in.
     * Optional: If game is being held hostage chainlink automation can trigger this function. Status: PENDING IMPLEMENTATION
     * If any user's HP is zero or the amount of turns is equal to MAX_TURNS, it will trigger the endGame() function.
     * Adds to match turn. Calls absoluteValue function to guarantee the difference of HP is a positive value.
     * Returns string message with players decision for better readability in front end.
     */

    function endTurn(address player) private returns (string memory) {
        uint256 id = s_playerToBattle[player].battleId;
        BattleFrame storage currentMatch = s_battleFrames[id];
        BattleData storage currentMatchData = s_battleData[id];
        string memory message;

        if (
            currentMatch.player1Choice == AttackOrDefense.ATTACK &&
            currentMatch.player2Choice == AttackOrDefense.ATTACK
        ) {
            currentMatch.player1HP -= int(currentMatch.player2AttackPoints);
            currentMatch.player2HP -= int(currentMatch.player1AttackPoints);
            message = "Both players attacked!";
        } else if (
            currentMatch.player1Choice == AttackOrDefense.ATTACK &&
            currentMatch.player2Choice == AttackOrDefense.DEFEND
        ) {
            int damage = int(currentMatch.player1AttackPoints) -
                int(currentMatch.player2DefensePoints);
            if (damage > 0) {
                currentMatch.player2HP -= damage;
            }
            message = "Player 1 attacked and Player 2 defended!";
        } else if (
            currentMatch.player1Choice == AttackOrDefense.DEFEND &&
            currentMatch.player2Choice == AttackOrDefense.ATTACK
        ) {
            int damage = int(currentMatch.player2AttackPoints) -
                int(currentMatch.player1DefensePoints);
            if (damage > 0) {
                currentMatch.player1HP -= damage;
            }
            message = "Player 1 defended and Player 2 attacked!";
        } else if (
            currentMatch.player1Choice == AttackOrDefense.DEFEND &&
            currentMatch.player2Choice == AttackOrDefense.DEFEND
        ) {
            message = "Both players defended! No damage done.";
        }

        if (currentMatch.player1HP < 0) currentMatch.player1HP = 0;
        if (currentMatch.player2HP < 0) currentMatch.player2HP = 0;

        currentMatchData.turn += 1;

        currentMatch.player1Choice = AttackOrDefense.PENDING;
        currentMatch.player2Choice = AttackOrDefense.PENDING;

        if (
            currentMatch.player1HP == 0 ||
            currentMatch.player2HP == 0 ||
            currentMatchData.turn == MAX_TURNS
        ) {
            int256 int_HP_DIFFERENCE = absoluteValue(
                currentMatch.player1HP,
                currentMatch.player2HP
            );
            currentMatchData.hpDifference = uint256(int_HP_DIFFERENCE);
            currentMatchData.battleState = BattleStatus.ENDED;
            endBattle(player);
        }

        return message;
    }

    /**
     * @notice This function triggers after end game conditions have been met.
     * End game conditions: A player has zero HP or the max amount of turns has been reached.
     * It will assign the status of winner or loser accordingly and request for VRF function
     * Emits an event.
     * @param player address of any player in order to reference the match that is ongoing
     */

    function endBattle(address player) private {
        uint256 id = s_playerToBattle[player].battleId;
        BattleFrame storage currentMatch = s_battleFrames[id];
        BattleData storage currentMatchData = s_battleData[id];

        if (currentMatch.player1HP > currentMatch.player2HP) {
            currentMatchData.player1 = EndStatus.WON;
            currentMatchData.player2 = EndStatus.LOST;
        } else if (currentMatch.player1HP == currentMatch.player2HP) {
            currentMatchData.player2 = currentMatchData.player1 = EndStatus.DRAW;
        } else {
            currentMatchData.player1 = EndStatus.LOST;
            currentMatchData.player2 = EndStatus.WON;
        }
        address winner;
        address loser;
        if (currentMatchData.player1 == EndStatus.WON) {
            winner = currentMatch.player1;
            loser = currentMatch.player2;
            requestRandomWord(winner);
        } else if (currentMatchData.player2 == EndStatus.WON) {
            winner = currentMatch.player2;
            loser = currentMatch.player1;
            requestRandomWord(winner);
        } else {
            winner = address(0);
            // i_kryptorena.updateStats(address(0), 0, 0);
        }
        emit BattleEnded(id, winner, loser);
    }

    /**
     * @dev When user triggers this function it will end the battle
     * The caller will forfeit the game and to prevent abuse only 1 point
     * of HP difference will accredited to the winner.
     */

    function quitBattle() public {
        uint256 id = s_playerToBattle[msg.sender].battleId;
        BattleFrame storage currentMatch = s_battleFrames[id];
        BattleData storage currentMatchData = s_battleData[id];
        require(
            msg.sender == currentMatch.player1 || msg.sender == currentMatch.player2,
            "Player is not in this battle"
        );

        if (msg.sender == currentMatch.player1) {
            currentMatch.player1HP = 0;
            currentMatch.player1HP = 1;
        } else {
            currentMatch.player1HP = 0;
            currentMatch.player1HP = 1;
        }
        currentMatchData.battleState = BattleStatus.ENDED;
        endBattle(msg.sender);
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
