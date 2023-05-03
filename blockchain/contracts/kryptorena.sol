// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;
//this is a structured contract, not final 
contract kryptorena {

    enum BattleStatus { STARTED, ENDED, PENDING} // describes the state of game

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
        string name; // to store name of battle
        bytes32 battleHash; //store the hash of battle name, dont really know the use case...but might be needed later
        address[2] playersInBattle; // to store the players in this battle
        uint[2] aod; //to store the choice of player: attack or defence
        address winner; // storing the address of winner
    }

    Player[] public players; // store all players
    BattleId[] public battleId; // store all game ids
    Game[] public games; // store all games 

    // general functions
    // isPlayer, getPlayer, allPlayers, 
    function isPlayer(address _address) public {

    }
    function getPlayer(address _address) public {

    }
    function getAllPlayer(address _address) public {

    }
    function isGame(address _address) public {

    }
    function getGame(address _address) public {

    }
    function getAllGame(address _address) public {

    }

    function updateGame() public {

    }

    // events


    // more functions

    function playerRegistration() public {

    }
    
    function generateRandomNumber() public {

    }

    function generateRandomGameId() public {

    }

    function createGame() public { // battle

    }

    function joinGame() public {

    }

    function aodBattle() public { // to get if user chosed attack or defence
        
    }

    function regAod() public { // to store the choice on-chain

    }

    struct Play {
        uint index;
        uint choice;
        uint health;
        uint attack;
        uint defence;
    }

    
    
    
    

    
    
    
    


    
}