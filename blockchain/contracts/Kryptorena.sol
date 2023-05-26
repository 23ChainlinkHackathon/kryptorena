// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "./KryptorenaNft.sol";
import "./KryptorenaBattle.sol";

contract Kryptorena is VRFConsumerBaseV2, ConfirmedOwner {
    enum GameStatus {
        STARTED,
        ENDED,
        PENDING
    } // describes the state of game

    struct BattleId {
        uint id;
        string name; //user defined
        uint playerHealth; // lets keep it 10 in the beginning of each battle, will be changed after each attack or defence based on who won the round
        uint attackPoints; // randomly by Chainlink vrfv2
        uint defencePoints; // randomly by Chainlink vrfv2
    }
    struct Player {
        string playerName; // user defined
        address playerAddress; // metamask address
        bool inGame; // true if playing if by any chance player left the game, we need to put it false
    }

    //     //storing the battle data

    struct Game {
        GameStatus gameStatus;
        string name; // to store name of battle
        bytes32 battleHash; //store the hash of battle name, dont really know the use case...but might be needed later
        address[2] playersInBattle; // to store the players in this battle
        uint8[2] aod; //to store the choice of player: attack or defence
        address winner; // storing the address of winner
    }

    struct Play {
        uint index;
        uint choice;
        uint health;
        uint attack;
        uint defence;
    }

    KryptorenaBattle public i_kryptorenaBattle;
    KryptorenaNft public i_kryptorenaNft;
    uint256 public i_mintFee;
    uint256 s_randomAttackValue;
    uint256 s_randomDefenseValue;
    uint256 public constant PLAYER_HP = 10;

    Player[] public players; // store all players
    BattleId[] public battleId; // store all game ids
    Game[] public games; // store all games

    mapping(address => uint) public playerInfo;
    mapping(string => uint) public gameInfo;
    mapping(uint256 => address) public s_requestIdToSender;
    mapping(address => string) public s_addressToUsername;

    //Chainlink VRF Variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    //     // events

    //     event newPlayer(address indexed owner, string name);
    //     event newGame(string battleName, address indexed player1, address indexed player2);
    //     event gameEnded(string battleName, address indexed winner, address indexed defeated);

    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 gasLane,
        uint32 callbackGasLimit,
        //   string[] memory cardTokenUris,
        //  address kryptorenaNftAddress,
        //  uint256 mintFee,
        address kryptorenaBattleAddress
    ) VRFConsumerBaseV2(vrfCoordinatorV2) ConfirmedOwner(msg.sender) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_subscriptionId = subscriptionId;
        i_gasLane = gasLane;
        i_callbackGasLimit = callbackGasLimit;
        //i_kryptorenaNft = KryptorenaNft(kryptorenaNftAddress);
        // i_mintFee = mintFee;
        i_kryptorenaBattle = KryptorenaBattle(kryptorenaBattleAddress);
    }

    // register the player

    // function registerNewPlayer(string memory _name) external payable returns (uint256 requestId) {
    //     require(!isPlayer(msg.sender), "This address already registered");
    //     require(msg.value >= i_mintFee, "Not enough AVAX");

    //     i_kryptorenaNft.requestNft{value: msg.value}();

    //     uint _id = players.length;
    //     players.push(Player(_name, msg.sender, false));
    //     playerInfo[msg.sender] = _id;

    //     requestId = i_vrfCoordinator.requestRandomWords(
    //         i_gasLane,
    //         i_subscriptionId,
    //         REQUEST_CONFIRMATIONS,
    //         i_callbackGasLimit,
    //         NUM_WORDS
    //     );
    //     s_requestIdToSender[requestId] = msg.sender;
    //     s_addressToUsername[msg.sender] = _name;

    //     emit newPlayer(msg.sender, _name);
    // }

    /**
     *
     * @dev This will trigger battle contract. Built it like this for now just for testing purposes.
     */

    struct forTesting {
        address player1;
        address player2;
        uint256 player1AttackPoints;
        uint256 player1DefensePoints;
        uint256 player2AttackPoints;
        uint256 player2DefensePoints;
    }
    forTesting test =
        forTesting(
            0xC9C4C378eB60de311B004783E47d683A74eE3756,
            0x22fb1C7a7FAc8aD61b14c61d776C010C439aA078,
            1,
            10,
            1,
            10
        );

    function fakeJoinGameExtraStep() public {
        initiateFromContract();
    }

    function initiateFromContract() public {
        initiateBattle(
            test.player1,
            test.player2,
            test.player1AttackPoints,
            test.player1DefensePoints,
            test.player2AttackPoints,
            test.player2DefensePoints
        );
    }

    function initiateBattle(
        address player1,
        address player2,
        uint256 player1AttackPoints,
        uint256 player1DefensePoints,
        uint256 player2AttackPoints,
        uint256 player2DefensePoints
    ) public {
        i_kryptorenaBattle.initiateBattle(
            player1,
            player2,
            player1AttackPoints,
            player1DefensePoints,
            player2AttackPoints,
            player2DefensePoints
        );
    }

    //     /**
    //      * @notice Battle contract will call this function to send winner's updated stats
    //      * @notice This function will then update the player struct with the new stats.
    //      */

    function updateStats(address winner, uint256 newAttack, uint256 newDefense) external {
        require(msg.sender == address(i_kryptorenaBattle), "Unauthorized");
        // logic
    }

    //     // create Battle

    //     function createGame(string memory _name) external returns (Game memory) {
    //         require(isPlayer(msg.sender), "This address is not registered"); // Require that the player is registered
    //         require(!isGame(_name), "Can not create game with this name. It already exist."); // Require battle with same name should not exist

    //         bytes32 hashOfBattle = keccak256(abi.encode(_name));

    //         Game memory _game = Game(
    //             GameStatus.PENDING,
    //             _name,
    //             hashOfBattle,
    //             [msg.sender, address(0)],
    //             [0, 0],
    //             address(0)
    //         );

    //         uint _id = games.length;
    //         gameInfo[_name] = _id;
    //         games.push(_game);

    //         return _game;
    //     }

    //     // function joinGame(string memory _name) external returns (Game memory) {
    //     //     Game memory _game = getGame(_name);

    //     //     require(_game.gameStatus == GameStatus.PENDING, "Battle already started!"); // Require that battle has not started
    //     //     require(_game.playersInBattle[0] != msg.sender, "Only player two can join a battle"); // Require that player 2 is joining the battle
    //     //     require(!getPlayer(msg.sender).inBattle, "Already in battle"); // Require that player is not already in a battle

    //     //     _game.battleStatus = GameStatus.STARTED;
    //     //     _game.players[1] = msg.sender;
    //     //     updateGame(_name, _game);

    //     //     players[playerInfo[_game.players[0]]].inBattle = true;
    //     //     players[playerInfo[_game.players[1]]].inBattle = true;

    //     //     emit newGame(_game.name, _game.players[0], msg.sender); // Emits NewBattle event
    //     //     return _game;
    //     // }

    //     function getPlayer(address _address) public {}

    //     function getAllPlayer(address _address) public {}

    //     function getGame(address _address) public {}

    //     function getAllGame(address _address) public {}

    //     function updateGame() public {}

    //     function generateRandomNumber() public {}

    //     function generateRandomGameId() public {}

    //     function joinGame() public {}

    //     function aodBattle() public {
    //         // to get if user chosed attack or defence
    //     }

    //     function regAod() public {
    //         // to store the choice on-chain
    //     }

    //     // function quitGame(string memory _gameName) public {
    //     //     Game memory _game = getGame(_gameName);
    //     //     require(
    //     //         _game.players[0] == msg.sender ||
    //     //             _game.players[1] = -msg.sender,
    //     //         "You are not in this game sir"
    //     //     );
    //     //     _game.players[0] == msg.sender
    //     //         ? endGame(_game.players[1], _game)
    //     //         : endGame(_game.players[0], _game);
    //     // }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 randomNumber = randomWords[0];
        s_randomAttackValue = randomNumber % 10;
        s_randomDefenseValue = 10 - s_randomAttackValue;
        address user = s_requestIdToSender[requestId];
        battleId.push(
            BattleId(
                playerInfo[user],
                s_addressToUsername[user],
                PLAYER_HP,
                s_randomAttackValue,
                s_randomDefenseValue
            )
        );
    }

    //     // function endGame(address lastUser, Game memory _game) internal returns (Game memory) {
    //     //     require(_game.GameStatus != GameStatus.ENDED, "The game has ended");
    //     //     _game.gameStatus = GameStatus.ENDED;
    //     //     _game.winner = lastUser;
    //     //     updateGame(_game.name, _game);

    //     //     uint player1 = playerInfo[_game.players[0]];
    //     //     uint player2 = playerInfo[_game.players[1]];

    //     //     players[player1].inGame = false;
    //     //     players[player1].playerHealth = 10;
    //     //     players[player2].inGame = false;
    //     //     players[player2].playerHealth = 10;

    //     //     address _gameLoser = lastUser == _game.players[0] ? _game.players[1] : _game.players[0];

    //     //     emit gameEnded(_game.name, lastUser, _gameLoser); // Emits BattleEnded event

    //     //     return _game;
    //     // }

    //     function isPlayer(address _address) public view returns (bool) {
    //         if (playerInfo[_address] == 0) {
    //             return false;
    //         } else {
    //             return true;
    //         }
    //     }

    //     function getGame(string memory _name) public view returns (Game memory) {
    //         require(isGame(_name), "Battle doesn't exist!");
    //         return games[gameInfo[_name]];
    //     }

    //     function isGame(string memory _name) public view returns (bool) {
    //         if (gameInfo[_name] == 0) {
    //             return false;
    //         } else {
    //             return true;
    //         }
    //     }
}
