// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AMM is ReentrancyGuard{

    using SafeERC20 for IERC20;

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
    function initializeLiquidity(uint256 amountA, uint256 amountB) external nonReentrant  {
        require(liquidityA == 0 && liquidityB == 0, "Already initialized");
        liquidityA = amountA;
        liquidityB = amountB;
        uint256 share = amountA + amountB;
        totalShares = share;
        lpShares[owner] = share;
    } 

    function swap(address tokenIn, uint256 amountIn) external nonReentrant  {
        require(tokenIn == tokenA || tokenIn == tokenB, "Invalid tokenIn");
        address tokenOut = tokenIn == tokenA ? tokenB : tokenA;

        uint256 liquidityIn = tokenIn == tokenA ? liquidityA : liquidityB;
        uint256 liquidityOut = tokenIn == tokenA ? liquidityB : liquidityA;

        uint256 amountInWithFee = (amountIn * FEE_NUMERATOR) / FEE_DENOMINATOR;
        uint256 amountOut = (liquidityOut * amountInWithFee) / (liquidityIn + amountInWithFee);

        require(amountOut > 0, "Insufficient output");

        if (tokenIn == tokenA) {
            liquidityA += amountIn;
            liquidityB -= amountOut;
        }
        else {
            liquidityB += amountIn;
            liquidityA -= amountOut;
        }

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external nonReentrant  {
        require(liquidityA * amountB == liquidityB * amountA, "Deposit ratio mismatch");

        liquidityA += amountA;
        liquidityB += amountB;

        uint256 share;
        share = amountA + amountB;

        lpShares[msg.sender] += share;
        totalShares += share;

        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountB);
    }


    function removeLiquidity(uint256 share) external nonReentrant  {
        require(share > 0, "Zero share");
        require(lpShares[msg.sender] >= share, "Not enough share");

        uint256 amountA = (liquidityA * share) / totalShares;
        uint256 amountB = (liquidityB * share) / totalShares;

        lpShares[msg.sender] -= share;
        totalShares -= share;

        liquidityA -= amountA;
        liquidityB -= amountB;

        IERC20(tokenA).safeTransfer(msg.sender, amountA);
        IERC20(tokenB).safeTransfer(msg.sender, amountB);
    }

    function addLiquidityWithOneToken(address tokenIn, uint256 amountIn) external nonReentrant {
        require(tokenIn == tokenA || tokenIn == tokenB, "Invalid token");
        require(amountIn > 0, "Zero input");
        require(liquidityA > 0 && liquidityB > 0, "Pool not initialized");

        uint256 totalLiquidity = liquidityA + liquidityB;

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        if (tokenIn == tokenA) {
            uint256 tokenToAddA = (liquidityA * amountIn) / totalLiquidity;
            uint256 tokenToAddB = amountIn - tokenToAddA;
            liquidityA += tokenToAddA;
            liquidityB += tokenToAddB;
        } else {
            uint256 tokenToAddB = (liquidityB * amountIn) / totalLiquidity;
            uint256 tokenToAddA = amountIn - tokenToAddB;
            liquidityB += tokenToAddB;
            liquidityA += tokenToAddA;
        }

        lpShares[msg.sender] += amountIn;
        totalShares += amountIn;
    }
}
