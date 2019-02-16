pragma solidity 0.5.0;

contract RockPaperScissors {
    uint8 constant STAKE = 10;
    uint16 constant GAME_TIMEOUT = 10;
    bytes32 constant DEFAULT_HASH = "";
    
    uint64 gameCounter = 0;
    address payable waitingPlayer;
    mapping (uint => Game) games;
    mapping (uint8 => mapping (uint8 => uint8)) winnerEncoding;

    struct Game {
        address payable p1;
        address payable p2;
        uint8 p1Move;
        uint8 p2Move;
        bytes32 p1MoveHash;
        bytes32 p2MoveHash;
        bool gameInProgress;
        uint timeout;
    }

    event GameStart(uint gameID, address p1, address p2);
    event CommitRequest(uint gameID, address player);
    event GameEnd(uint gameID, uint8 winner);
    event GameTimeout(uint gameID);

    modifier sentPayIn {
        require(msg.value == STAKE);
        _;
    }

    modifier gameInProgress(uint gameID) {
        checkGameState(gameID);
        _;
    }
    
    modifier playerInGame(uint gameID) {
        Game memory game = games[gameID];
        require(msg.sender == game.p1 || msg.sender == game.p2);
        _;
    }
    
    modifier playerNotMoved(uint gameID) {
        Game memory game = games[gameID];
        if (game.p1 == msg.sender) {
            require(game.p1Move == 3 && game.p1MoveHash == DEFAULT_HASH);
        }
        if (game.p2 == msg.sender) {
            require(game.p2Move == 3 && game.p2MoveHash == DEFAULT_HASH);
        }
        _;
    }
    
    modifier bothPlayersMoved(uint gameID) {
        Game memory game = games[gameID];
        require((game.p1Move != 3 || game.p1MoveHash != DEFAULT_HASH) &&
                (game.p2Move != 3 || game.p2MoveHash != DEFAULT_HASH));
        _;
    }

    constructor() public {
        // Initialize winning mapping to avoid work when game played
        // Moves-   0: Rock, 1: Paper, 2: Scissors
        // Results- 0: Draw, 1: P1,    2: P2
        winnerEncoding[0][0] = 0;
        winnerEncoding[1][1] = 0;
        winnerEncoding[2][2] = 0;
        winnerEncoding[0][2] = 1;
        winnerEncoding[1][0] = 1;
        winnerEncoding[2][1] = 1;
        winnerEncoding[2][0] = 2;
        winnerEncoding[0][1] = 2;
        winnerEncoding[1][2] = 2;
    }


    function joinGame() public {
        if (waitingPlayer != address(0) && waitingPlayer != msg.sender) {
            games[gameCounter] = Game({p1: waitingPlayer, p2: msg.sender, 
                                       p1Move: 3, p2Move: 3, 
                                       p1MoveHash: DEFAULT_HASH, p2MoveHash: DEFAULT_HASH, 
                                       gameInProgress: true, timeout: now + GAME_TIMEOUT});
            emit GameStart(gameCounter, waitingPlayer, msg.sender);
            waitingPlayer = address(0);
            gameCounter++;
        } else {
            waitingPlayer = msg.sender;
        }
    }

    function makeMove(uint gameID, uint8 move, string memory password) payable public
        sentPayIn
        gameInProgress(gameID)
        playerInGame(gameID)
        playerNotMoved(gameID)
    {
        Game storage game = games[gameID];
        if (msg.sender == game.p1) {
            if (game.p2MoveHash == DEFAULT_HASH) {
                game.p1MoveHash = keccak256(abi.encodePacked(gameID, move, password));
            } else {
                game.p1Move = move;
                emit CommitRequest(gameID, game.p2);
            }
        } else if (msg.sender == game.p2) {
            if (game.p1MoveHash == DEFAULT_HASH) {
                game.p2MoveHash = keccak256(abi.encodePacked(gameID, move, password));
            } else {
                game.p2Move = move;
                emit CommitRequest(gameID, game.p1);
            }
        }
    }

    function commit(uint gameID, uint8 move, string memory password) public 
        gameInProgress(gameID)
        playerInGame(gameID)
        bothPlayersMoved(gameID)
    {
        Game storage game = games[gameID];
        uint8 winner = 3;
        if (msg.sender == game.p1 && keccak256(abi.encodePacked(gameID, move, password)) == game.p1MoveHash) {
            winner = winnerEncoding[move][game.p2Move];
            emit GameEnd(gameID, winner);
        } else if (msg.sender == game.p2 && keccak256(abi.encodePacked(gameID, move, password)) == game.p2MoveHash) {
            winner = winnerEncoding[game.p1Move][move];
            emit GameEnd(gameID, winner);
        } else {
            revert();
        }

        if (winner == 0) {
            game.p1.transfer(5);
            game.p2.transfer(5);
        } else if (winner == 1) {
            game.p1.transfer(10);
        } else {
            game.p2.transfer(10);
        }
        game.gameInProgress = false;

    }
    
        
    function checkGameState(uint gameID) public {
        Game storage game = games[gameID];
        require(game.gameInProgress);
        if (now > game.timeout) {
            if (game.p1Move != 3 || game.p1MoveHash != DEFAULT_HASH) {
                game.p1.transfer(10);
            }
            if (game.p1Move != 3 || game.p1MoveHash != DEFAULT_HASH) {
                game.p2.transfer(10);
            }
            game.gameInProgress = false;
            emit GameTimeout(gameID);
            revert();
        }
    }
}
