// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {MemeToken} from "./MemeToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Launcher is Ownable {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 private immutable i_fee;

    uint256 private constant INITIAL_SUPPLY = 1_000_000 ether;
    uint256 private constant MIN_BUT_AMOUNT = 1 ether;
    uint256 private constant MAX_BUY_AMOUNT = 10_000 ether;
    uint256 private constant FLOOR = 0.001 ether;
    uint256 private constant STEP = 0.001 ether;
    uint256 private constant INCREMENT = 1_000 ether;
    uint256 private constant PRECISION = 1e18;

    // The target value for successful meme launch
    uint256 private constant TARGET_VALUE = 3 ether;
    // The maximum amount of tokens allowed to be bought
    uint256 private constant ALLOWED_AMOUNT_TO_BUY = 500_000 ether;

    uint256 private s_totalMemes;
    MemeToken[] private s_memes;
    mapping(address memeAddress => MemeSale sale) private s_memeToSale;

    /*//////////////////////////////////////////////////////////////
                                 STRUTS
    //////////////////////////////////////////////////////////////*/

    struct MemeSale {
        address meme;
        string name;
        address creator;
        uint256 sold;
        uint256 ethRaised;
        bool isOpen;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Launcher__InsufficientFee();
    error Launcher__MemeNotOpen();
    error Launcher__AmountTooLow();
    error Launcher__AmountTooHigh();
    error Launcher__InsufficientEthReceived(uint256 expected);
    error Launcher__WithdrawalAmountTooHigh(uint256 balance);
    error Launcher__WithdrawalFailed();
    error Launcher__NotLaunchedYet();
    error Launcher__TransferFailed();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event MemeCreated(address indexed memeAddress);
    event MemeBought(
        address indexed memeAddress,
        address indexed buyer,
        uint256 indexed amount
    );

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(uint256 fee) Ownable(msg.sender) {
        i_fee = fee;
        s_totalMemes = 0;
    }

    /*//////////////////////////////////////////////////////////////
                     EXTERNAL AND PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createMeme(
        string memory name,
        string memory symbol
    ) external payable {
        if (msg.value < i_fee) {
            revert Launcher__InsufficientFee();
        }

        MemeToken newMeme = new MemeToken(
            name,
            symbol,
            msg.sender,
            INITIAL_SUPPLY
        );

        s_memes.push(newMeme);
        s_totalMemes++;

        MemeSale memory sale = MemeSale({
            meme: address(newMeme),
            name: name,
            creator: msg.sender,
            sold: 0,
            ethRaised: 0,
            isOpen: true
        });

        s_memeToSale[address(newMeme)] = sale;

        emit MemeCreated(address(newMeme));
    }

    function buyMeme(address meme, uint256 amount) external payable {
        MemeSale storage sale = s_memeToSale[meme];

        if (!sale.isOpen) {
            revert Launcher__MemeNotOpen();
        }

        if (amount < MIN_BUT_AMOUNT) {
            revert Launcher__AmountTooLow();
        }

        if (amount > MAX_BUY_AMOUNT) {
            revert Launcher__AmountTooHigh();
        }

        uint256 price = _calculatePrice(meme, amount);
        if (msg.value < price) {
            revert Launcher__InsufficientEthReceived(price);
        }

        sale.sold += amount;
        sale.ethRaised += price;

        if (_memeNotOpenAnymore(sale.sold, sale.ethRaised)) {
            sale.isOpen = false;
        }

        // Transfer the tokens to the buyer
        bool success = MemeToken(meme).transfer(msg.sender, amount);
        if (!success) {
            revert Launcher__TransferFailed();
        }

        emit MemeBought(meme, msg.sender, amount);
    }

    // The remaining token balance and the ETH raised would go into a liquidity pool like Uniswap V4
    // @audit update this function later!
    function launchMeme(address meme) external {
        // For now we'll just transfer remaining memes and ETH raised to the creator.
        MemeSale memory sale = s_memeToSale[meme];

        if (sale.isOpen) {
            revert Launcher__NotLaunchedYet();
        }

        bool transferSuccess = MemeToken(meme).transfer(
            sale.creator,
            sale.sold
        );
        if (!transferSuccess) {
            revert Launcher__TransferFailed();
        }

        // slither-disable-next-line arbitrary-send-eth
        (bool success, ) = sale.creator.call{value: sale.ethRaised}("");
        if (!success) {
            revert Launcher__WithdrawalFailed();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function withdrawFee(uint256 amount) external onlyOwner {
        if (amount > address(this).balance) {
            revert Launcher__WithdrawalAmountTooHigh(address(this).balance);
        }

        (bool success, ) = owner().call{value: amount}("");
        if (!success) {
            revert Launcher__WithdrawalFailed();
        }
    }

    /*//////////////////////////////////////////////////////////////
                     INTERNAL AND PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    ///
    /// @param meme The address of the meme token
    /// @param amount The amount of tokens to buy
    /// @return The price of the total amount of tokens
    function _calculatePrice(
        address meme,
        uint256 amount
    ) private view returns (uint256) {
        MemeSale memory sale = s_memeToSale[meme];
        // Let's say we have sold 1 token and the amount is 1 token
        // per price = (0.001e18 * 1e18) / 1000e18 + 0.001e18 = 0.001001e18
        // price = (0.001001e18 * 1e18) / 1e18 = 0.001001e18

        // What about 100_000 tokens?
        // per price = (0.001e18 * 100_000e18) / 1000e18 + 0.001e18 = 0.101e18
        // price = (0.101e18 * 1e18) / 1e18 = 0.101e18

        uint256 perPrice = (STEP * sale.sold) / INCREMENT + FLOOR;

        return ((perPrice * amount) / PRECISION);
    }

    function _memeNotOpenAnymore(
        uint256 sold,
        uint256 ethRaised
    ) private pure returns (bool) {
        return (sold >= ALLOWED_AMOUNT_TO_BUY) || (ethRaised >= TARGET_VALUE);
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    function getMemes() external view returns (MemeToken[] memory) {
        return s_memes;
    }

    function getMemeSale(
        uint256 index
    ) external view returns (MemeSale memory) {
        return s_memeToSale[address(s_memes[index])];
    }

    function getTotalMemes() external view returns (uint256) {
        return s_totalMemes;
    }

    function getFee() external view returns (uint256) {
        return i_fee;
    }

    function getMemeToSale(
        address meme
    ) external view returns (MemeSale memory) {
        return s_memeToSale[meme];
    }
}
