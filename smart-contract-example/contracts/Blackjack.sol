/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/utils/Context.sol";
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./ChipToken.sol";
import "./CardDeck.sol";

/// @title A Blackjack game.
contract Blackjack is Context {
    uint256 public constant MIN_BET = 1;
    uint256 public constant MAX_BET = 1000000000000000000000;

    struct Player {
        bool isPlayer;
        bool betMade;
        bool turnOver;
        uint256 betValue;
        uint256 stackValue;
    }

    struct Dealer {
        address dealer;
        uint256 faceUpValue;
        uint256 stackValue;
    }

    enum Stage {
        BETTING,
        DEALING,
        PLAYING,
        PAYOUT,
        GAME_OVER
    }

    enum Decision {
        HIT,
        STAND
    }

    struct GameMetadata {
        address currentPlayer;
        uint256 betCount;
        uint256 moveCount;
        uint256 numPlayers;
        Stage currentStage;
        address[] playerAddresses;
    }

    ChipToken public token;
    GameMetadata internal game;
    Dealer internal dealer;
    mapping(address => Player) public players;

    using CardDeckUtils for CardDeck;
    CardDeck internal deck;

    event BetReceived(address player, uint256 amount);
    event StageAdvanced(Stage stage);
    event PlayerMoved(address player);
    event DealerMoved(address dealer);
    event CollectedChips(address player, uint256 amount);
    event PaidChips(address player, uint256 amount);
    event CardDrawn(address player, Suit suit, Value value);

    modifier isStage(Stage stage) {
        require(
            game.currentStage == stage,
            "function cannot be called right now."
        );
        _;
    }

    modifier isValidBet(uint256 amount) {
        require(
            amount <= MAX_BET && amount >= MIN_BET,
            "bet amount must be valid."
        );
        require(
            players[_msgSender()].betMade == false,
            "player has already bet."
        );
        require(
            token.balanceOf(_msgSender()) >= amount,
            "player doesn't have enough tokens."
        );
        _;
    }

    modifier onlyDealer() {
        require(
            _msgSender() == dealer.dealer,
            "only the dealer can call this function."
        );
        _;
    }

    modifier onlyPlayer() {
        require(
            players[_msgSender()].isPlayer == true,
            "not a player in this game."
        );
        require(players[_msgSender()].turnOver == false, "your turn is over.");
        _;
    }

    constructor(address[] memory _players, address _token) {
        token = ChipToken(_token);
        dealer = Dealer(_msgSender(), 0, 0);
        for (uint256 i = 0; i < _players.length; i++) {
            address player = _players[i];
            players[player] = Player(true, false, false, 0, 0);
        }
        game = GameMetadata(
            _players[0],
            0,
            0,
            _players.length,
            Stage.BETTING,
            _players
        );
        deck.createDeck();
    }

    function bet(uint256 amount)
        external
        isStage(Stage.BETTING)
        isValidBet(amount)
        onlyPlayer
    {
        address player = _msgSender();

        _collectChips(player, amount);

        players[player].betMade = true;
        players[player].betValue = amount;
        game.betCount++;

        emit BetReceived(player, amount);

        if (_isBettingOver()) {
            _advanceStage();
        }
    }

    function deal() external isStage(Stage.DEALING) onlyDealer {
        for (uint256 i = 0; i < game.numPlayers; i++) {
            address playerAddress = game.playerAddresses[i];

            Card memory playersCard = deck.drawCard();
            emit CardDrawn(playerAddress, playersCard.suit, playersCard.value);
            uint256 cardValue = _convertCardValueToUint(playersCard.value);

            players[playerAddress].stackValue += cardValue;
        }

        Card memory dealersCard = deck.drawCard();
        uint256 dealersCardValue = _convertCardValueToUint(dealersCard.value);
        emit CardDrawn(dealer.dealer, dealersCard.suit, dealersCard.value);
        dealer.faceUpValue += dealersCardValue;
        dealer.stackValue += dealersCardValue;

        for (uint256 i = 0; i < game.numPlayers; i++) {
            address playerAddress = game.playerAddresses[i];

            Card memory playersCard = deck.drawCard();
            emit CardDrawn(playerAddress, playersCard.suit, playersCard.value);
            uint256 cardValue = _convertCardValueToUint(playersCard.value);

            players[playerAddress].stackValue += cardValue;
        }

        Card memory dealersSecondCard = deck.drawCard();
        emit CardDrawn(
            dealer.dealer,
            dealersSecondCard.suit,
            dealersSecondCard.value
        );
        dealer.stackValue += _convertCardValueToUint(dealersSecondCard.value);

        _checkNaturals();

        _advanceStage();
    }

    function play(Decision decision)
        external
        isStage(Stage.PLAYING)
        onlyPlayer
    {
        require(_msgSender() == game.currentPlayer, "not your turn to play.");

        address playerAddress = _msgSender();
        Player storage player = players[playerAddress];

        if (decision == Decision.STAND) {
            player.turnOver = true;
            game.moveCount++;
        } else {
            Card memory card = deck.drawCard();
            emit CardDrawn(playerAddress, card.suit, card.value);
            player.stackValue += _convertCardValueToUint(card.value);

            if (player.stackValue > 21) {
                player.turnOver = true;
                game.moveCount++;
            }
        }

        emit PlayerMoved(playerAddress);

        if (player.turnOver == true && game.moveCount < game.numPlayers)
            game.currentPlayer = game.playerAddresses[game.moveCount];

        if (_isPlayingOver()) {
            _playDealer();
            _advanceStage();
        }
    }

    function payout() external onlyDealer isStage(Stage.PAYOUT) {
        bool dealerBusts = (dealer.stackValue > 21);

        for (uint256 i = 0; i < game.numPlayers; i++) {
            address playerAddress = game.playerAddresses[i];
            Player memory player = players[playerAddress];

            if (!player.turnOver && dealerBusts) {
                _payChips(playerAddress, SafeMath.mul(2, player.betValue));
            } else if (
                !player.turnOver && (player.stackValue > dealer.stackValue)
            ) {
                _payChips(playerAddress, SafeMath.mul(2, player.betValue));
            }
        }

        _advanceStage();
    }

    function getPlayerInfo(address player)
        external
        view
        returns (
            bool,
            bool,
            uint256,
            uint256
        )
    {
        return (
            players[player].betMade,
            players[player].turnOver,
            players[player].betValue,
            players[player].stackValue
        );
    }

    function getGameInfo()
        external
        view
        returns (
            address,
            uint256,
            uint256,
            uint256 numPlayers,
            Stage,
            address[] memory
        )
    {
        return (
            game.currentPlayer,
            game.betCount,
            game.moveCount,
            game.numPlayers,
            game.currentStage,
            game.playerAddresses
        );
    }

    function getDealersFaceUpCardValue()
        external
        view
        isStage(Stage.PLAYING)
        returns (uint256)
    {
        return dealer.faceUpValue;
    }

    function getCurrentStage() external view returns (Stage) {
        return game.currentStage;
    }

    function _playDealer() internal onlyDealer isStage(Stage.PLAYING) {
        while (dealer.stackValue < 17) {
            Card memory card = deck.drawCard();

            dealer.stackValue += _convertCardValueToUint(card.value);
        }

        emit DealerMoved(dealer.dealer);
    }

    function _checkNaturals() internal isStage(Stage.DEALING) {
        bool dealerHasNatural = (dealer.stackValue == 21);

        for (uint256 i = 0; i < game.numPlayers; i++) {
            address playerAddress = game.playerAddresses[i];
            Player storage player = players[playerAddress];
            bool playerHasNatural = (player.stackValue == 21);
            uint256 betValue = player.betValue;

            if (!dealerHasNatural && playerHasNatural) {
                player.turnOver = true;
                uint256 betValueDivBy2 = SafeMath.add(betValue, 1) / 2;
                _payChips(playerAddress, SafeMath.mul(5, betValueDivBy2));
            } else if (dealerHasNatural && playerHasNatural) {
                player.turnOver = true;
                _payChips(playerAddress, betValue);
            } else if (dealerHasNatural && !playerHasNatural) {
                player.turnOver = true;
            }
        }
    }

    function _collectChips(address player, uint256 amount) internal {
        token.transferFrom(player, dealer.dealer, amount);
    }

    function _payChips(address player, uint256 amount) internal {
        token.transferFrom(dealer.dealer, player, amount);
    }

    function _advanceStage() internal {
        if (game.currentStage == Stage.BETTING) {
            game.currentStage = Stage.DEALING;
            emit StageAdvanced(game.currentStage);
        } else if (game.currentStage == Stage.DEALING) {
            game.currentStage = Stage.PLAYING;
            emit StageAdvanced(game.currentStage);
        } else if (game.currentStage == Stage.PLAYING) {
            game.currentStage = Stage.PAYOUT;
            emit StageAdvanced(game.currentStage);
        } else if (game.currentStage == Stage.PAYOUT) {
            game.currentStage = Stage.GAME_OVER;
            emit StageAdvanced(game.currentStage);
        } else {}
    }

    function _isBettingOver() internal view returns (bool) {
        return game.betCount == game.numPlayers;
    }

    function _isPlayingOver() internal view returns (bool) {
        return game.moveCount == game.numPlayers;
    }

    function _convertCardValueToUint(Value value)
        internal
        pure
        returns (uint256)
    {
        if (
            value == Value.Jack || value == Value.King || value == Value.Queen
        ) {
            return 10;
        } else {
            return uint256(value);
        }
    }
}