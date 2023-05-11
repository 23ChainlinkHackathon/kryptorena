// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

//this is a structured contract, not final
contract Kryptorena {
    enum GameStatus {
        STARTED,
        ENDED,
        PENDING
    } // describes the state of game

    struct BattleId {
        uint id;
        string name; //user defined
        uint attackPoints; // randomly by Chainlink vrfv2
        uint defencePoints; // randomly by Chainlink vrfv2
    }
    struct Player {
        string playerName; // user defined
        address playerAddress; // metamask address
        uint playerHealth; // lets keep it 10 in the beginning of each battle, will be changed after each attack or defence based on who won the round
        bool inGame; // true if playing if by any chance player left the game, we need to put it false
    }

    //storing the battle data

    struct Game {
        GameStatus gameStatus;
        string name; // to store name of battle
        bytes32 battleHash; //store the hash of battle name, dont really know the use case...but might be needed later
        address[2] playersInBattle; // to store the players in this battle
        uint8[2] aod; //to store the choice of player: attack or defence
        address winner; // storing the address of winner
    }

    Player[] public players; // store all players
    BattleId[] public battleId; // store all game ids
    Game[] public games; // store all games

    mapping(address => uint) public playerInfo;
    mapping(string => uint) public gameInfo;

    // general functions
    // isPlayer, getPlayer, allPlayers,
    function isPlayer(address _address) public view returns (bool) {
        if (playerInfo[_address] == 0) {
            return false;
        } else {
            return true;
        }
    }

    function getPlayer(address _address) public {}

    function getAllPlayer(address _address) public {}

    function isGame(string memory _name) public view returns (bool) {
        if (gameInfo[_name] == 0) {
            return false;
        } else {
            return true;
        }
    }

    function getGame(address _address) public {}

    function getAllGame(address _address) public {}

    function updateGame() public {}

    // events

    // more functions

    function generateRandomNumber() public {}

    function generateRandomGameId() public {}

    function joinGame() public {}

    function aodBattle() public {
        // to get if user chosed attack or defence
    }

    function regAod() public {
        // to store the choice on-chain
    }

    struct Play {
        uint index;
        uint choice;
        uint health;
        uint attack;
        uint defence;
    }

    // events

    event newPlayer(address indexed owner, string name);
    event newGame(string battleName, address indexed player1, address indexed player2);
    event gameEnded(string battleName, address indexed winner, address indexed defeated);

    // register the player
    function registerNewPlayer(string memory _name) external {
        require(!isPlayer(msg.sender), "This address already registered");

        uint _id = players.length;
        players.push(Player(_name, msg.sender, 10, false));

        playerInfo[msg.sender] = _id;

        emit newPlayer(msg.sender, _name);
    }

    // create Battle

    function createGame(string memory _name) external returns (Game memory) {
        require(isPlayer(msg.sender), "This address is not registered"); // Require that the player is registered
        require(!isGame(_name), "Can not create game with this name. It already exist."); // Require battle with same name should not exist

        bytes32 hashOfBattle = keccak256(abi.encode(_name));

        Game memory _game = Game(
            GameStatus.PENDING,
            _name,
            hashOfBattle,
            [msg.sender, address(0)],
            [0, 0],
            address(0)
        );

        uint _id = games.length;
        gameInfo[_name] = _id;
        games.push(_game);

        return _game;
    }

    function getGame(string memory _name) public view returns (Game memory) {
        require(isGame(_name), "Battle doesn't exist!");
        return games[gameInfo[_name]];
    }

    function joinGame(string memory _name) external returns (Game memory) {
        Game memory _game = getGame(_name);

        require(_game.gameStatus == GameStatus.PENDING, "Battle already started!"); // Require that battle has not started
        require(_game.playersInBattle[0] != msg.sender, "Only player two can join a battle"); // Require that player 2 is joining the battle
        require(!getPlayer(msg.sender).inBattle, "Already in battle"); // Require that player is not already in a battle

        _game.battleStatus = GameStatus.STARTED;
        _game.players[1] = msg.sender;
        updateGame(_name, _game);

        players[playerInfo[_game.players[0]]].inBattle = true;
        players[playerInfo[_game.players[1]]].inBattle = true;

        emit newGame(_game.name, _game.players[0], msg.sender); // Emits NewBattle event
        return _game;
    }

    function quitGame(string memory _gameName) public {
        Game memory _game = getGame(_gameName);
        require(
            _game.players[0] == msg.sender ||
                _game.players[1] = -msg.sender,
            "You are not in this game sir"
        );
        _game.players[0] == msg.sender
            ? endGame(_game.players[1], _game)
            : endGame(_game.players[0], _game);
    }

    function endGame(address lastUser, Game memory _game) internal returns (Game memory) {
        require(_game.GameStatus != GameStatus.ENDED, "The game has ended");
        _game.gameStatus = GameStatus.ENDED;
        _game.winner = lastUser;
        updateGame(_game.name, _game);

        uint player1 = playerInfo[_game.players[0]];
        uint player2 = playerInfo[_game.players[1]];

        players[player1].inGame = false;
        players[player1].playerHealth = 10;
        players[player2].inGame = false;
        players[player2].playerHealth = 10;

        address _gameLoser = lastUser == _game.players[0] ? _game.players[1] : _game.players[0];

        emit gameEnded(_game.name, lastUser, _gameLoser); // Emits BattleEnded event

        return _game;
    }
}
