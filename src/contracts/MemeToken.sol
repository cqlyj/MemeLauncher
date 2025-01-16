// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MemeToken is ERC20, Ownable {
    address private immutable i_creator;
    // here the owner is the Launcher contract
    address payable private immutable i_owner;

    constructor(
        string memory _name,
        string memory _symbol,
        address _creator,
        uint256 _totalSupply
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        i_creator = _creator;
        i_owner = payable(msg.sender);

        // mint the total supply to the owner, which is the Launcher contract
        // Then the Launcher contract can handle those operations
        _mint(i_owner, _totalSupply);
    }

    // only the owner can burn tokens
    // @notice Not the creator!
    function burn(uint256 _amount) external onlyOwner {
        _burn(msg.sender, _amount);
    }
}
