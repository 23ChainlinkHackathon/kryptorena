// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "./KryptorenaNft.sol";

contract Kryptorena is ERC1155, Ownable, ERC1155Supply {
    KryptorenaNft public i_kryptorenaNft;
    string public baseURI;
    uint256 public totalSupply;
    uint256 public constant DEVIL = 0;
    uint256 public constant GRIFFIN = 1;
    uint256 public constant FIREBIRD = 2;
    uint256 public constant KAMO = 3;
    uint256 public constant KUKULKAN = 4;
    uint256 public constant CELESTION = 5;

    uint256 public constant MAX_ATTACK_DEFEND_STRENGTH = 10;

    enum BattleStatus {
        PENDING,
        STARTED,
        ENDED
    }

    struct GameToken {
        // BattleId
        string name;
        uint256 id;
        uint256 attackStrength;
        uint256 defenseStrength;
    }

    /// @dev Player struct to store player info
    struct Player {
        address playerAddress;
        string playerName;
        uint256 playerMana;
        uint256 playerHealth;
        bool inBattle;
    }

    struct Battle {
        BattleStatus battleStatus;
        bytes32 battleHash;
        string name;
        address[2] players;
        uint8[2] moves;
        address winner;
    }

    mapping(address => uint256) public playerInfo;
    mapping(address => uint256) public playerTokenInfo;
    mapping(string => uint256) public battleInfo;
    mapping(address => string) public s_addressToUri;

    Player[] public players;
    GameToken[] public gameTokens;
    Battle[] public battles;

    function isPlayer(address addr) public view returns (bool) {
        if (playerInfo[addr] == 0) {
            return false;
        } else {
            return true;
        }
    }

    function getPlayer(address addr) public view returns (Player memory) {
        require(isPlayer(addr), "Player doesn't exist!");
        return players[playerInfo[addr]];
    }

    function getAllPlayers() public view returns (Player[] memory) {
        return players;
    }

    function isPlayerToken(address addr) public view returns (bool) {
        if (playerTokenInfo[addr] == 0) {
            return false;
        } else {
            return true;
        }
    }

    function getPlayerToken(address addr) public view returns (GameToken memory) {
        require(isPlayerToken(addr), "Game token doesn't exist!");
        return gameTokens[playerTokenInfo[addr]];
    }

    function getAllPlayerTokens() public view returns (GameToken[] memory) {
        return gameTokens;
    }

    function isBattle(string memory _name) public view returns (bool) {
        if (battleInfo[_name] == 0) {
            return false;
        } else {
            return true;
        }
    }

    function getBattle(string memory _name) public view returns (Battle memory) {
        require(isBattle(_name), "Battle doesn't exist!");
        return battles[battleInfo[_name]];
    }

    function getAllBattles() public view returns (Battle[] memory) {
        return battles;
    }

    function updateBattle(string memory _name, Battle memory _newBattle) private {
        require(isBattle(_name), "Battle doesn't exist");
        battles[battleInfo[_name]] = _newBattle;
    }

    event NewPlayer(address indexed owner, string name);
    event NewBattle(string battleName, address indexed player1, address indexed player2);
    event BattleEnded(string battleName, address indexed winner, address indexed loser);
    event BattleMove(string indexed battleName, bool indexed isFirstMove);
    event NewGameToken(
        address indexed owner,
        uint256 id,
        uint256 attackStrength,
        uint256 defenseStrength
    );
    event RoundEnded(address[2] damagedPlayers);

    constructor(string memory _metadataURI) ERC1155(_metadataURI) {
        baseURI = _metadataURI; // Set baseURI
        initialize();
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function initialize() private {
        gameTokens.push(GameToken("", 0, 0, 0));
        players.push(Player(address(0), "", 0, 0, false));
        battles.push(
            Battle(
                BattleStatus.PENDING,
                bytes32(0),
                "",
                [address(0), address(0)],
                [0, 0],
                address(0)
            )
        );
    }

    function linkNftContract(address _kryptorenaNftAddress) public {
        i_kryptorenaNft = KryptorenaNft(_kryptorenaNftAddress);
    }

    function registerPlayer(string memory _name, string memory _gameTokenName) external payable {
        require(!isPlayer(msg.sender), "Player already registered");
        uint256 _id = players.length;
        players.push(Player(msg.sender, _name, 10, 25, false));
        playerInfo[msg.sender] = _id;
        i_kryptorenaNft.requestNft(msg.sender);

        createRandomGameToken(_gameTokenName);

        emit NewPlayer(msg.sender, _name);
    }

    function _createRandomNum(
        uint256 _max,
        address _sender
    ) internal view returns (uint256 randomValue) {
        uint256 randomNum = uint256(
            keccak256(abi.encodePacked(block.difficulty, block.timestamp, _sender))
        );

        randomValue = randomNum % _max;
        if (randomValue == 0) {
            randomValue = _max / 2;
        }

        return randomValue;
    }

    function _createGameToken(string memory _name) internal returns (GameToken memory) {
        uint256 randAttackStrength = _createRandomNum(MAX_ATTACK_DEFEND_STRENGTH, msg.sender);
        uint256 randDefenseStrength = MAX_ATTACK_DEFEND_STRENGTH - randAttackStrength;

        uint8 randId = uint8(
            uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % 100
        );
        randId = randId % 6;
        if (randId == 0) {
            randId++;
        }

        GameToken memory newGameToken = GameToken(
            _name,
            randId,
            randAttackStrength,
            randDefenseStrength
        );

        uint256 _id = gameTokens.length;
        gameTokens.push(newGameToken);
        playerTokenInfo[msg.sender] = _id;

        _mint(msg.sender, randId, 1, "0x0");
        totalSupply++;

        emit NewGameToken(msg.sender, randId, randAttackStrength, randDefenseStrength);
        return newGameToken;
    }

    function createRandomGameToken(string memory _name) public {
        require(!getPlayer(msg.sender).inBattle, "Player is in a battle");
        require(isPlayer(msg.sender), "Please Register Player First");

        _createGameToken(_name);
    }

    function getTotalSupply() external view returns (uint256) {
        return totalSupply;
    }

    /// @dev Creates a new battle
    /// @param _name battle name; set by player
    function createBattle(string memory _name) external returns (Battle memory) {
        require(isPlayer(msg.sender), "Please Register Player First");
        require(!isBattle(_name), "Battle already exists!");

        bytes32 battleHash = keccak256(abi.encode(_name));

        Battle memory _battle = Battle(
            BattleStatus.PENDING,
            battleHash,
            _name,
            [msg.sender, address(0)],
            [0, 0],
            address(0)
        );

        uint256 _id = battles.length;
        battleInfo[_name] = _id;
        battles.push(_battle);

        return _battle;
    }

    function joinBattle(string memory _name) external returns (Battle memory) {
        Battle memory _battle = getBattle(_name);
        // Require that battle has not started
        require(_battle.players[0] != msg.sender, "Only player two can join a battle");
        require(!getPlayer(msg.sender).inBattle, "Already in battle");

        _battle.battleStatus = BattleStatus.STARTED;
        _battle.players[1] = msg.sender;
        updateBattle(_name, _battle);

        players[playerInfo[_battle.players[0]]].inBattle = true;
        players[playerInfo[_battle.players[1]]].inBattle = true;

        emit NewBattle(_battle.name, _battle.players[0], msg.sender);
        return _battle;
    }

    function getBattleMoves(
        string memory _battleName
    ) public view returns (uint256 P1Move, uint256 P2Move) {
        Battle memory _battle = getBattle(_battleName);

        P1Move = _battle.moves[0];
        P2Move = _battle.moves[1];

        return (P1Move, P2Move);
    }

    function _registerPlayerMove(
        uint256 _player,
        uint8 _choice,
        string memory _battleName
    ) internal {
        require(_choice == 1 || _choice == 2, "Choice should be either 1 or 2!");
        require(
            _choice == 1 ? getPlayer(msg.sender).playerMana >= 3 : true,
            "Mana not sufficient for attacking!"
        );
        battles[battleInfo[_battleName]].moves[_player] = _choice;
    }

    function attackOrDefendChoice(uint8 _choice, string memory _battleName) external {
        Battle memory _battle = getBattle(_battleName);

        require(
            _battle.battleStatus == BattleStatus.STARTED,
            "Battle not started. Please tell another player to join the battle"
        ); 
        require(_battle.battleStatus != BattleStatus.ENDED, "Battle has already ended"); // Require that battle has not ended
        require(
            msg.sender == _battle.players[0] || msg.sender == _battle.players[1],
            "You are not in this battle"
        ); // Require that player is in the battle

        require(
            _battle.moves[_battle.players[0] == msg.sender ? 0 : 1] == 0,
            "You have already made a move!"
        );

        _registerPlayerMove(_battle.players[0] == msg.sender ? 0 : 1, _choice, _battleName);

        _battle = getBattle(_battleName);
        uint _movesLeft = 2 - (_battle.moves[0] == 0 ? 0 : 1) - (_battle.moves[1] == 0 ? 0 : 1);
        emit BattleMove(_battleName, _movesLeft == 1 ? true : false);

        if (_movesLeft == 0) {
            _awaitBattleResults(_battleName);
        }
    }

    // Awaits battle results
    function _awaitBattleResults(string memory _battleName) internal {
        Battle memory _battle = getBattle(_battleName);

        require(
            msg.sender == _battle.players[0] || msg.sender == _battle.players[1],
            "Only players in this battle can make a move"
        );

        require(
            _battle.moves[0] != 0 && _battle.moves[1] != 0,
            "Players still need to make a move"
        );

        _resolveBattle(_battle);
    }

    struct P {
        uint index;
        uint move;
        uint health;
        uint attack;
        uint defense;
    }
    function _resolveBattle(Battle memory _battle) internal {
        P memory p1 = P(
            playerInfo[_battle.players[0]],
            _battle.moves[0],
            getPlayer(_battle.players[0]).playerHealth,
            getPlayerToken(_battle.players[0]).attackStrength,
            getPlayerToken(_battle.players[0]).defenseStrength
        );
        P memory p2 = P(
            playerInfo[_battle.players[1]],
            _battle.moves[1],
            getPlayer(_battle.players[1]).playerHealth,
            getPlayerToken(_battle.players[1]).attackStrength,
            getPlayerToken(_battle.players[1]).defenseStrength
        );
        address[2] memory _damagedPlayers = [address(0), address(0)];
        if (p1.move == 1 && p2.move == 1) {
            if (p1.attack >= p2.health) {
                _endBattle(_battle.players[0], _battle);
            } else if (p2.attack >= p1.health) {
                _endBattle(_battle.players[1], _battle);
            } else {
                players[p1.index].playerHealth -= p2.attack;
                players[p2.index].playerHealth -= p1.attack;
                players[p1.index].playerMana -= 3;
                players[p2.index].playerMana -= 3;
                _damagedPlayers = _battle.players;
            }
        } else if (p1.move == 1 && p2.move == 2) {
            uint256 PHAD = p2.health + p2.defense;
            if (p1.attack >= PHAD) {
                _endBattle(_battle.players[0], _battle);
            } else {
                uint256 healthAfterAttack;
                if (p2.defense > p1.attack) {
                    healthAfterAttack = p2.health;
                } else {
                    healthAfterAttack = PHAD - p1.attack;
                    _damagedPlayers[0] = _battle.players[1];
                }
                players[p2.index].playerHealth = healthAfterAttack;
                players[p1.index].playerMana -= 3;
                players[p2.index].playerMana += 3;
            }
        } else if (p1.move == 2 && p2.move == 1) {
            uint256 PHAD = p1.health + p1.defense;
            if (p2.attack >= PHAD) {
                _endBattle(_battle.players[1], _battle);
            } else {
                uint256 healthAfterAttack;

                if (p1.defense > p2.attack) {
                    healthAfterAttack = p1.health;
                } else {
                    healthAfterAttack = PHAD - p2.attack;

                    // Player 1 health damaged
                    _damagedPlayers[0] = _battle.players[0];
                }

                players[p1.index].playerHealth = healthAfterAttack;

                players[p1.index].playerMana += 3;
                players[p2.index].playerMana -= 3;
            }
        } else if (p1.move == 2 && p2.move == 2) {
            players[p1.index].playerMana += 3;
            players[p2.index].playerMana += 3;
        }
        emit RoundEnded(_damagedPlayers);
        _battle.moves[0] = 0;
        _battle.moves[1] = 0;
        updateBattle(_battle.name, _battle);
        uint256 _randomAttackStrengthPlayer1 = _createRandomNum(
            MAX_ATTACK_DEFEND_STRENGTH,
            _battle.players[0]
        );
        gameTokens[playerTokenInfo[_battle.players[0]]]
            .attackStrength = _randomAttackStrengthPlayer1;
        gameTokens[playerTokenInfo[_battle.players[0]]].defenseStrength =
            MAX_ATTACK_DEFEND_STRENGTH -
            _randomAttackStrengthPlayer1;

        uint256 _randomAttackStrengthPlayer2 = _createRandomNum(
            MAX_ATTACK_DEFEND_STRENGTH,
            _battle.players[1]
        );
        gameTokens[playerTokenInfo[_battle.players[1]]]
            .attackStrength = _randomAttackStrengthPlayer2;
        gameTokens[playerTokenInfo[_battle.players[1]]].defenseStrength =
            MAX_ATTACK_DEFEND_STRENGTH -
            _randomAttackStrengthPlayer2;
    }
    function quitBattle(string memory _battleName) public {
        Battle memory _battle = getBattle(_battleName);
        require(
            _battle.players[0] == msg.sender || _battle.players[1] == msg.sender,
            "You are not in this battle!"
        );

        _battle.players[0] == msg.sender
            ? _endBattle(_battle.players[1], _battle)
            : _endBattle(_battle.players[0], _battle);
    }
    function _endBattle(
        address battleEnder,
        Battle memory _battle
    ) internal returns (Battle memory) {
        require(_battle.battleStatus != BattleStatus.ENDED, "Battle already ended"); // Require that battle has not ended
        _battle.battleStatus = BattleStatus.ENDED;
        _battle.winner = battleEnder;
        updateBattle(_battle.name, _battle);
        generateNewAttDef(battleEnder, _battle);
        uint p1 = playerInfo[_battle.players[0]];
        uint p2 = playerInfo[_battle.players[1]];
        players[p1].inBattle = false;
        players[p1].playerHealth = 25;
        players[p1].playerMana = 10;
        players[p2].inBattle = false;
        players[p2].playerHealth = 25;
        players[p2].playerMana = 10;
        address _battleLoser = battleEnder == _battle.players[0]
            ? _battle.players[1]
            : _battle.players[0];

        emit BattleEnded(_battle.name, battleEnder, _battleLoser);
        return _battle;
    }

    function uintToStr(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
    function tokenURI(uint256 tokenId) public view returns (string memory) {
        return string(abi.encodePacked(baseURI, "/", uintToStr(tokenId), ".json"));
    }
    function registerAddressToUri(address _player, string memory _uri) external {
        s_addressToUri[_player] = _uri;
    }
    function getPlayerURI(address _player) public returns (string memory) {
        return s_addressToUri[_player];
    }
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
    function generateNewAttDef(address winner, Battle memory _battle) internal {
        Player memory player = getPlayer(winner);
        require(player.inBattle, "Player is not in a battle");
        uint256 playerIndex = playerInfo[winner];
        uint256 opponentIndex = playerIndex == 1 ? 2 : 1;
        uint256 playerHP = players[playerIndex].playerHealth;
        uint256 opponentHP = players[opponentIndex].playerHealth;
        uint256 hpDifference = playerHP > opponentHP
            ? playerHP - opponentHP
            : opponentHP - playerHP;
        uint256 _postBattleAttackStrengthPlayer1 = _createRandomNum(
            hpDifference,
            _battle.players[playerInfo[msg.sender]]
        );
        uint256 _postBattleDefenseStrengthPlayer1 = hpDifference - _postBattleAttackStrengthPlayer1;
        gameTokens[playerTokenInfo[_battle.players[playerInfo[msg.sender]]]]
            .attackStrength += _postBattleAttackStrengthPlayer1;
        gameTokens[playerTokenInfo[_battle.players[playerInfo[msg.sender]]]]
            .defenseStrength += _postBattleDefenseStrengthPlayer1;
    }
}
