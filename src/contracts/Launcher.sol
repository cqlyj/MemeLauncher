// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {MemeToken} from "./MemeToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PositionManager, PoolInitializer_v4} from "v4-periphery/src/PositionManager.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {LiquidityAmounts} from "lib/v4-core/test/utils/LiquidityAmounts.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

contract Launcher is Ownable {
    using CurrencyLibrary for Currency;
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
    // lpFee is the fee expressed in pips, i.e. 3000 = 0.30%
    uint24 private constant LP_FEE = 3000;
    // tickSpacing is the granularity of the pool. Lower values are more precise but more expensive to trade
    int24 private constant TICK_SPACING = 60;
    int24 private constant TICK_LOWER = -600;
    int24 private constant TICK_UPPER = 600;

    uint256 private s_totalMemes;
    MemeToken[] private s_memes;
    mapping(address memeAddress => MemeSale sale) private s_memeToSale;
    PositionManager private immutable i_posm;
    IAllowanceTransfer private immutable i_permit2;

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
    event MemeClosed(address indexed memeAddress);
    event MemeLaunched(address indexed memeAddress);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        uint256 fee,
        address posm,
        address permit2
    ) Ownable(msg.sender) {
        i_fee = fee;
        s_totalMemes = 0;
        i_posm = PositionManager(payable(posm));
        i_permit2 = IAllowanceTransfer(payable(permit2));
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

        // the owner of the meme is this contract
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
            // once get this event, our contract will call that launchMeme function
            // front-end handle this or use Chainlink Automation
            emit MemeClosed(meme);
        }

        // Transfer the tokens to the buyer
        bool success = MemeToken(meme).transfer(msg.sender, amount);
        if (!success) {
            revert Launcher__TransferFailed();
        }

        emit MemeBought(meme, msg.sender, amount);
    }

    ///
    /// @param meme The address of the meme token
    /// @dev Once the meme is closed, the contract will launch the meme
    function launchMeme(address meme) external onlyOwner {
        MemeSale memory sale = s_memeToSale[meme];

        if (sale.isOpen) {
            revert Launcher__NotLaunchedYet();
        }

        bytes[] memory params = new bytes[](2);
        PoolKey memory pool = PoolKey({
            // native token pairs => ETH
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(meme),
            fee: LP_FEE,
            tickSpacing: TICK_SPACING,
            // for now, no hooks
            hooks: IHooks(address(0))
        });

        uint160 startingPrice = getStartingPriceX96(meme);

        // pools are initialized with a starting price
        params[0] = abi.encodeWithSelector(
            PoolInitializer_v4.initializePool.selector,
            pool,
            startingPrice
        );

        // The first command MINT_POSITION creates a new liquidity position
        // The second command SETTLE_PAIR indicates that tokens are to be paid by the caller, to create the position
        bytes memory actions = abi.encodePacked(
            uint8(Actions.MINT_POSITION),
            uint8(Actions.SETTLE_PAIR)
        );

        bytes[] memory mintParams = new bytes[](2);

        uint256 currentTokenPerPrice = (STEP * sale.sold) / INCREMENT + FLOOR;
        uint256 token0Amount = sale.ethRaised;
        // based on the current price, how many tokens can be bought with the raised ETH
        // what about the rest tokens in the contract? => for now we will just burn them
        // @audit the burn mechanism can be improved...
        uint256 token1Amount = token0Amount / currentTokenPerPrice;

        uint256 amount0Max = token0Amount + 1 wei;
        uint256 amount1Max = token1Amount + 1 wei;

        /// @notice Computes the maximum amount of liquidity received for a given amount of token0, token1, the current
        /// pool prices and the prices at the tick boundaries
        /// @param sqrtPriceX96 A sqrt price representing the current pool prices
        /// @param sqrtPriceAX96 A sqrt price representing the first tick boundary
        /// @param sqrtPriceBX96 A sqrt price representing the second tick boundary
        /// @param amount0 The amount of token0 being sent in
        /// @param amount1 The amount of token1 being sent in
        /// @return liquidity The maximum amount of liquidity received
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            startingPrice,
            TickMath.getSqrtPriceAtTick(TICK_LOWER),
            TickMath.getSqrtPriceAtTick(TICK_UPPER),
            // send the raised ETH to the pool
            token0Amount,
            token1Amount
        );

        /// @pool the same PoolKey defined above, in pool-creation
        /// @tickLower and tickUpper are the range of the position, must be a multiple of pool.tickSpacing
        /// @liquidity is the amount of liquidity units to add, see LiquidityAmounts for converting token amounts to liquidity units
        /// @amount0Max and amount1Max are the maximum amounts of token0 and token1 the caller is willing to transfer
        /// @recipient is the address that will receive the liquidity position (ERC-721)
        /// @hookData is the optional hook data
        mintParams[0] = abi.encode(
            pool,
            TICK_LOWER,
            TICK_UPPER,
            liquidity,
            amount0Max,
            amount1Max,
            // the recipient will also be our launcher contract
            address(this),
            // for now no hooks
            new bytes(0)
        );

        // Creating a position on a pool requires the caller to transfer `currency0` and `currency1` tokens
        mintParams[1] = abi.encode(pool.currency0, pool.currency1);
        uint256 deadline = block.timestamp + 60;
        // update the position manager later
        params[1] = abi.encodeWithSelector(
            // update the position manager later
            i_posm.modifyLiquidities.selector,
            abi.encode(actions, mintParams),
            deadline
        );

        // approve permit2 as a spender
        // update the permit2 address later
        IERC20(meme).approve(address(i_permit2), type(uint256).max);

        // approve `PositionManager` as a spender
        i_permit2.approve(
            meme,
            address(i_posm),
            type(uint160).max,
            type(uint48).max
        );

        PositionManager(i_posm).multicall{value: token0Amount}(params);
        // burn the rest tokens...
        MemeToken(meme).burn(INITIAL_SUPPLY - amount1Max);

        emit MemeLaunched(meme);
    }

    function getStartingPriceX96(address meme) public view returns (uint160) {
        uint256 price = _calculatePrice(meme, 1 ether); // Price of 1 MemeToken in ETH
        uint256 ratio = price * (2 ** 96); // Scale price by 2^96
        return uint160(_sqrt(ratio)); // Return square root
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

    // Based on Solmate
    // https://github.com/transmissions11/solmate/blob/main/src/utils/FixedPointMathLib.sol
    function _sqrt(uint256 x) private pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            let y := x // We start y at x, which will help us make our initial estimate.

            z := 181 // The "correct" value is 1, but this saves a multiplication later.

            // This segment is to get a reasonable initial estimate for the Babylonian method. With a bad
            // start, the correct # of bits increases ~linearly each iteration instead of ~quadratically.

            // We check y >= 2^(k + 8) but shift right by k bits
            // each branch to ensure that if x >= 256, then y >= 256.
            if iszero(lt(y, 0x10000000000000000000000000000000000)) {
                y := shr(128, y)
                z := shl(64, z)
            }
            if iszero(lt(y, 0x1000000000000000000)) {
                y := shr(64, y)
                z := shl(32, z)
            }
            if iszero(lt(y, 0x10000000000)) {
                y := shr(32, y)
                z := shl(16, z)
            }
            if iszero(lt(y, 0x1000000)) {
                y := shr(16, y)
                z := shl(8, z)
            }

            // Goal was to get z*z*y within a small factor of x. More iterations could
            // get y in a tighter range. Currently, we will have y in [256, 256*2^16).
            // We ensured y >= 256 so that the relative difference between y and y+1 is small.
            // That's not possible if x < 256 but we can just verify those cases exhaustively.

            // Now, z*z*y <= x < z*z*(y+1), and y <= 2^(16+8), and either y >= 256, or x < 256.
            // Correctness can be checked exhaustively for x < 256, so we assume y >= 256.
            // Then z*sqrt(y) is within sqrt(257)/sqrt(256) of sqrt(x), or about 20bps.

            // For s in the range [1/256, 256], the estimate f(s) = (181/1024) * (s+1) is in the range
            // (1/2.84 * sqrt(s), 2.84 * sqrt(s)), with largest error when s = 1 and when s = 256 or 1/256.

            // Since y is in [256, 256*2^16), let a = y/65536, so that a is in [1/256, 256). Then we can estimate
            // sqrt(y) using sqrt(65536) * 181/1024 * (a + 1) = 181/4 * (y + 65536)/65536 = 181 * (y + 65536)/2^18.

            // There is no overflow risk here since y < 2^136 after the first branch above.
            z := shr(18, mul(z, add(y, 65536))) // A mul() is saved from starting z at 181.

            // Given the worst case multiplicative error of 2.84 above, 7 iterations should be enough.
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            // If x+1 is a perfect square, the Babylonian method cycles between
            // floor(sqrt(x)) and ceil(sqrt(x)). This statement ensures we return floor.
            // See: https://en.wikipedia.org/wiki/Integer_square_root#Using_only_integer_division
            // Since the ceil is rare, we save gas on the assignment and repeat division in the rare case.
            // If you don't care whether the floor or ceil square root is returned, you can remove this statement.
            z := sub(z, lt(div(x, z), z))
        }
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    function getCost(uint256 sold) external pure returns (uint256) {
        return (STEP * sold) / INCREMENT + FLOOR;
    }

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

    function getAllowedAmountToBuy() external pure returns (uint256) {
        return ALLOWED_AMOUNT_TO_BUY;
    }

    function getTargetValue() external pure returns (uint256) {
        return TARGET_VALUE;
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getStep() external pure returns (uint256) {
        return STEP;
    }

    function getFloor() external pure returns (uint256) {
        return FLOOR;
    }

    function getIncrement() external pure returns (uint256) {
        return INCREMENT;
    }

    function getMinBuyAmount() external pure returns (uint256) {
        return MIN_BUT_AMOUNT;
    }

    function getMaxBuyAmount() external pure returns (uint256) {
        return MAX_BUY_AMOUNT;
    }

    function getInitialSupply() external pure returns (uint256) {
        return INITIAL_SUPPLY;
    }
}
