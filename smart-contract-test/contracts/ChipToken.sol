// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";

/// @title A ChipToken contract for use as in game currency in casino games.
/// @author Tedi Mitiku
/// @dev work in progress, not tested
/// @notice
///
/// This token is the in game currency for Blackjack and other future casino
/// games. This token comes with the following features:
///
/// - a Minter role that allows for token minting. The minter role should be granted
///  to the creator of this contract and any BlackjackFactory contracts. This represents
///  the ability to create more poker chips as needed by the casino.
///
/// - A Transfer role that allows for transferring tokens to addresses as needed. The
///  transfer role should be granted to Blackjack and BlackjackFactory contracts. For
///  a Blackjack contract, this represents the dealer collecting/paying players tokens.
///  For a BlackjackFactory contract, this represents allocating and collecting funds
///  to and from a Blackjack round.
///
/// This contract uses {AccessControl} to lock permissioned functions using the
/// different roles.
///
/// The account that deploys the contract will be granted the minter role,
/// as well as the default admin role, which will let it grant both minter and
/// transfer roles to other accounts.
contract ChipToken is Context, AccessControl, ERC20 {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");

    constructor() ERC20("Chip", "CHIP") {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(TRANSFER_ROLE, _msgSender());
    }

    function mint(address to, uint256 amount) public {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "ChipToken: must have minter role to mint new chips."
        );
        _mint(to, amount);
    }

    // TODO: implement transfer role functionality so only those with transfer role can call transferFrom)
}