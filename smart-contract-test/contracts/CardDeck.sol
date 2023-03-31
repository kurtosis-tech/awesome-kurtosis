// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

enum Suit {
    Spades,
    Clubs,
    Diamonds,
    Hearts
}

enum Value {
    Two,
    Three,
    Four,
    Five,
    Six,
    Seven,
    Eight,
    Nine,
    Ten,
    Jack,
    King,
    Queen,
    Ace
}

struct Card {
    Suit suit;
    Value value;
}

struct CardDeck {
    Card[] cards;
    uint256 numCards;
}

library CardDeckUtils {
    function createDeck(CardDeck storage deck) internal {
        for (uint256 i = 0; i < 4; i++) {
            for (uint256 j = 0; j < 13; j++) {
                deck.cards.push(Card(Suit(i), Value(j)));
                deck.numCards++;
            }
        }
    }

    function drawCard(CardDeck storage deck) internal returns (Card memory) {
        require(deck.numCards > 0, "no more cards left in the deck");
        uint256 index = _random() % deck.numCards;
        Card memory card = deck.cards[index];
        deck.cards[index] = deck.cards[deck.cards.length - 1];
        deck.cards.pop();
        deck.numCards--;
        return card;
    }

    /// @dev generates a pseudo random number - randomness would require an oracle
    /// https://stackoverflow.com/questions/48848948/how-to-generate-a-random-number-in-solidity
    function _random() private view returns (uint256) {
        return
            uint256(
                keccak256(abi.encodePacked(block.difficulty, block.timestamp))
            );
    }
}