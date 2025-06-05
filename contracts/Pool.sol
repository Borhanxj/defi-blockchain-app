// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./DeFiHelper.sol";

contract Pool {
    address public token0;
    address public token1;
    address public owner;

    uint256 public liquidity0;
    uint256 public liquidity1;

    mapping(address => uint256) public lpShares;
    uint256 public totalShares;

    uint256 public constant FEE_NUMERATOR = 997;
    uint256 public constant FEE_DENOMINATOR = 1000;

    DeFiHelper public helper;

    constructor(
        address _token0,
        address _token1,
        address _creator,
        address _helper
    ) {
        require(_token0 != _token1, "Same token");
        token0 = _token0;
        token1 = _token1;
        owner = _creator;
        helper = DeFiHelper(_helper);
    }

    function initializeLiquidity(uint256 amount0, uint256 amount1) external {
        require(liquidity0 == 0 && liquidity1 == 0, "Already initialized");
        liquidity0 = amount0;
        liquidity1 = amount1;
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut) external {
        require(tokenIn == token0 || tokenIn == token1, "Invalid tokenIn");
        address tokenOut = tokenIn == token0 ? token1 : token0;

        uint256 liquidityIn = tokenIn == token0 ? liquidity0 : liquidity1;
        uint256 liquidityOut = tokenIn == token0 ? liquidity1 : liquidity0;

        uint256 amountInWithFee = (amountIn * FEE_NUMERATOR) / FEE_DENOMINATOR;
        uint256 amountOut = (liquidityOut * amountInWithFee) / (liquidityIn + amountInWithFee);

        require(amountOut > 0, "Insufficient output");
        require(amountOut >= minAmountOut, "Slippage exceeded");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(msg.sender, amountOut);

        if (tokenIn == token0) {
            liquidity0 += amountIn;
            liquidity1 -= amountOut;
        } else {
            liquidity1 += amountIn;
            liquidity0 -= amountOut;
        }

        helper.logSwap(msg.sender, address(this), tokenIn, amountIn, amountOut);
    }

    function addLiquidity(uint256 amount0, uint256 amount1) external {
        require( liquidity0 * amount1 == liquidity1 * amount0,"Deposit ratio mismatch");

        IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);

        liquidity0 += amount0;
        liquidity1 += amount1;

        uint256 share;
        if (totalShares == 0) {
            share = amount0 + amount1;
        }
        else {
            share = ((amount0 + amount1) * totalShares) / (liquidity0 + liquidity1);
        }

        lpShares[msg.sender] += share;
        totalShares += share;

        helper.logLiquidityAdd(msg.sender, address(this), amount0, amount1, share);
    }

    function removeLiquidity(uint256 share) external {
        require(share > 0, "Zero share");
        require(lpShares[msg.sender] >= share, "Not enough share");

        uint256 amount0 = (liquidity0 * share) / totalShares;
        uint256 amount1 = (liquidity1 * share) / totalShares;

        lpShares[msg.sender] -= share;
        totalShares -= share;

        liquidity0 -= amount0;
        liquidity1 -= amount1;

        IERC20(token0).transfer(msg.sender, amount0);
        IERC20(token1).transfer(msg.sender, amount1);
    }

    function addLiquiditySingleToken(address tokenIn, uint256 amountIn) external {
        require(tokenIn == token0 || tokenIn == token1, "Invalid token");

        uint256 liquidityIn = tokenIn == token0 ? liquidity0 : liquidity1;
        uint256 liquidityOut = tokenIn == token0 ? liquidity1 : liquidity0;

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        uint256 amountInWithFee = (amountIn * FEE_NUMERATOR) / FEE_DENOMINATOR;
        uint256 amountOut = (liquidityOut * amountInWithFee) / (liquidityIn + amountInWithFee);

        require(amountOut <= liquidityOut, "Not enough liquidity to rebalance");

        if (tokenIn == token0) {
            liquidity0 += amountIn;
            liquidity1 -= amountOut;
        } 
        else {
            liquidity1 += amountIn;
            liquidity0 -= amountOut;
        }

        uint256 liquidityAdded = amountIn + amountOut;
        uint256 totalLiquidity = liquidity0 + liquidity1;
        uint256 share = (liquidityAdded * totalShares) / totalLiquidity;

        lpShares[msg.sender] += share;
        totalShares += share;

        helper.logLiquidityAdd(msg.sender, address(this), tokenIn == token0 ? amountIn : 0, tokenIn == token1 ? amountIn : 0, share);
    }
}
