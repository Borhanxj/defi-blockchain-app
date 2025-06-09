// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AMM is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public token0;
    address public token1;
    address public owner;

    uint256 public liquidity0;
    uint256 public liquidity1;

    mapping(address => uint256) public lpShares;
    uint256 public totalShares;

    uint256 public constant FEE_NUMERATOR = 997;
    uint256 public constant FEE_DENOMINATOR = 1000;

    // === Events ===
    event LiquidityInitialized(address indexed creator, uint256 amount0, uint256 amount1, uint256 share);
    event TokensSwapped(address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event LiquidityAdded(address indexed user, uint256 amount0, uint256 amount1, uint256 share);
    event LiquidityRemoved(address indexed user, uint256 amount0, uint256 amount1, uint256 share);
    event OneSidedLiquidityAdded(address indexed user, address tokenIn, uint256 amountIn, uint256 share);

    constructor(address _token0, address _token1, address _creator) {
        require(_token0 != _token1, "Same token");
        token0 = _token0;
        token1 = _token1;
        owner = _creator;
    }

    function initializeLiquidity(uint256 amount0, uint256 amount1) external nonReentrant {
        require(liquidity0 == 0 && liquidity1 == 0, "Already initialized");
        liquidity0 = amount0;
        liquidity1 = amount1;
        uint256 share = amount0 + amount1;
        totalShares = share;
        lpShares[owner] = share;

        emit LiquidityInitialized(msg.sender, amount0, amount1, share);
    }

    function swap(address tokenIn, uint256 amountIn) external nonReentrant {
        require(tokenIn == token0 || tokenIn == token1, "Invalid tokenIn");

        address tokenOut = tokenIn == token0 ? token1 : token0;

        uint256 liquidityIn = tokenIn == token0 ? liquidity0 : liquidity1;
        uint256 liquidityOut = tokenIn == token0 ? liquidity1 : liquidity0;

        uint256 amountInWithFee = (amountIn * FEE_NUMERATOR) / FEE_DENOMINATOR;
        uint256 amountOut = (liquidityOut * amountInWithFee) / (liquidityIn + amountInWithFee);

        require(amountOut > 0, "Insufficient output");

        if (tokenIn == token0) {
            liquidity0 += amountIn;
            liquidity1 -= amountOut;
        } else {
            liquidity1 += amountIn;
            liquidity0 -= amountOut;
        }

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);

        emit TokensSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    function addLiquidity(uint256 amount0, uint256 amount1) external nonReentrant {
        require(liquidity0 * amount1 == liquidity1 * amount0, "Deposit ratio mismatch");

        liquidity0 += amount0;
        liquidity1 += amount1;

        uint256 share = amount0 + amount1;

        lpShares[msg.sender] += share;
        totalShares += share;

        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);

        emit LiquidityAdded(msg.sender, amount0, amount1, share);
    }

    function removeLiquidity(uint256 share) external nonReentrant {
        require(share > 0, "Zero share");
        require(lpShares[msg.sender] >= share, "Not enough share");

        uint256 amount0 = (liquidity0 * share) / totalShares;
        uint256 amount1 = (liquidity1 * share) / totalShares;

        lpShares[msg.sender] -= share;
        totalShares -= share;

        liquidity0 -= amount0;
        liquidity1 -= amount1;

        IERC20(token0).safeTransfer(msg.sender, amount0);
        IERC20(token1).safeTransfer(msg.sender, amount1);

        emit LiquidityRemoved(msg.sender, amount0, amount1, share);
    }

    function addLiquidityWithOneToken(address tokenIn, uint256 amountIn) external nonReentrant {
        require(tokenIn == token0 || tokenIn == token1, "Invalid token");
        require(amountIn > 0, "Zero input");
        require(liquidity0 > 0 && liquidity1 > 0, "Pool not initialized");

        uint256 totalLiquidity = liquidity0 + liquidity1;

        if (tokenIn == token0) {
            uint256 tokenToAdd0 = (liquidity0 * amountIn) / totalLiquidity;
            uint256 tokenToAdd1 = amountIn - tokenToAdd0;
            liquidity0 += tokenToAdd0;
            liquidity1 += tokenToAdd1;
        } else {
            uint256 tokenToAdd1 = (liquidity1 * amountIn) / totalLiquidity;
            uint256 tokenToAdd0 = amountIn - tokenToAdd1;
            liquidity1 += tokenToAdd1;
            liquidity0 += tokenToAdd0;
        }

        lpShares[msg.sender] += amountIn;
        totalShares += amountIn;

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        emit OneSidedLiquidityAdded(msg.sender, tokenIn, amountIn, amountIn);
    }
}
