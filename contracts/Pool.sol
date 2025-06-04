// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Pool {
    address public tokenA;
    address public tokenB;
    address public owner;

    uint256 public liquidityA;
    uint256 public liquidityB;

    mapping(address => uint256) public lpShares;
    uint256 public totalShares;

    uint256 public constant FEE_NUMERATOR = 997;
    uint256 public constant FEE_DENOMINATOR = 1000;

    constructor(
        address _tokenA,
        address _tokenB,
        address _creator
    ) {
        require(_tokenA != _tokenB, "Same token");
        tokenA = _tokenA;
        tokenB = _tokenB;
        owner = _creator;
    }
    function initializeLiquidity(uint256 amountA, uint256 amountB) external {
        require(liquidityA == 0 && liquidityB == 0, "Already initialized");
        liquidityA = amountA;
        liquidityB = amountB;
    }


    function swap(address tokenIn, uint256 amountIn) external {
        require(tokenIn == tokenA || tokenIn == tokenB, "Invalid tokenIn");
        address tokenOut = tokenIn == tokenA ? tokenB : tokenA;

        uint256 liquidityIn = tokenIn == tokenA ? liquidityA : liquidityB;
        uint256 liquidityOut = tokenIn == tokenA ? liquidityB : liquidityA;

        uint256 amountInWithFee = (amountIn * FEE_NUMERATOR) / FEE_DENOMINATOR;
        uint256 amountOut = (liquidityOut * amountInWithFee) / (liquidityIn + amountInWithFee);

        require(amountOut > 0, "Insufficient output");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(msg.sender, amountOut);

        if (tokenIn == tokenA) {
            liquidityA += amountIn;
            liquidityB -= amountOut;
        }
        else {
            liquidityB += amountIn;
            liquidityA -= amountOut;
        }
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external {
        require( liquidityA * amountB == liquidityB * amountA,"Deposit ratio mismatch");

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        liquidityA += amountA;
        liquidityB += amountB;

        uint256 share;
        if (totalShares == 0) {
            share = amountA + amountB;
        }
        else {
            share = ((amountA + amountB) * totalShares) / (liquidityA + liquidityB);
        }

        lpShares[msg.sender] += share;
        totalShares += share;
    }

    function removeLiquidity(uint256 share) external {
        require(share > 0, "Zero share");
        require(lpShares[msg.sender] >= share, "Not enough share");

        uint256 amountA = (liquidityA * share) / totalShares;
        uint256 amountB = (liquidityB * share) / totalShares;

        lpShares[msg.sender] -= share;
        totalShares -= share;

        liquidityA -= amountA;
        liquidityB -= amountB;

        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);
    }

    function addLiquiditySingleToken(address tokenIn, uint256 amountIn) external {
        require(tokenIn == tokenA || tokenIn == tokenB, "Invalid token");

        uint256 liquidityIn = tokenIn == tokenA ? liquidityA : liquidityB;
        uint256 liquidityOut = tokenIn == tokenA ? liquidityB : liquidityA;

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        uint256 amountInWithFee = (amountIn * FEE_NUMERATOR) / FEE_DENOMINATOR;
        uint256 amountOut = (liquidityOut * amountInWithFee) / (liquidityIn + amountInWithFee);

        require(amountOut <= liquidityOut, "Not enough liquidity to rebalance");

        if (tokenIn == tokenA) {
            liquidityA += amountIn;
            liquidityB -= amountOut;
        } 
        else {
        liquidityB += amountIn;
        liquidityA -= amountOut;
        }

        uint256 liquidityAdded = amountIn + amountOut;
        uint256 totalLiquidity = liquidityA + liquidityB;
        uint256 share = (liquidityAdded * totalShares) / totalLiquidity;

        lpShares[msg.sender] += share;
        totalShares += share;
    }
}
