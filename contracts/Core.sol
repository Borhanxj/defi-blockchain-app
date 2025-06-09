// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./AMM.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Core is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address[] public allPools;

    event PoolCreated(
        address indexed creator,
        address indexed token0,
        address indexed token1,
        address poolAddress,
        uint256 amount0,
        uint256 amount1,
        uint256 timestamp
    );

    function createPool(address token0, address token1, uint256 amount0, uint256 amount1) external nonReentrant returns (address) {
        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);

        AMM newPool = new AMM(token0, token1, msg.sender);

        IERC20(token0).safeTransfer(address(newPool), amount0);
        IERC20(token1).safeTransfer(address(newPool), amount1);

        newPool.initializeLiquidity(amount0, amount1);
        allPools.push(address(newPool));

        emit PoolCreated(
            msg.sender,
            token0,
            token1,
            address(newPool),
            amount0,
            amount1,
            block.timestamp
        );

        return address(newPool);
    }

    function getAllPools() external view returns (address[] memory) {
        return allPools;
    }

    function bestPool(address tokenToSwapp, address tokenFromSwapp, uint256 amountToSwap) public view returns (address bestAMM) {
        address[] memory pools = allPools;
        uint256 bestAmountOut = 0;

        for (uint256 i = 0; i < pools.length; i++) {
            AMM pool = AMM(pools[i]);
            address tokenA = pool.token0();
            address tokenB = pool.token1();

            if ((tokenToSwapp == tokenA && tokenFromSwapp == tokenB) || (tokenToSwapp == tokenB && tokenFromSwapp == tokenA)) {
                uint256 liquidityIn = tokenToSwapp == tokenA ? pool.liquidity0() : pool.liquidity1();
                uint256 liquidityOut = tokenToSwapp == tokenA ? pool.liquidity1() : pool.liquidity0();

                uint256 amountInWithFee = (amountToSwap * 997) / 1000;
                uint256 amountOut = (liquidityOut * amountInWithFee) / (liquidityIn + amountInWithFee);

                if (amountOut > bestAmountOut) {
                    bestAmountOut = amountOut;
                    bestAMM = pools[i];
                }
            }
        }
    }
}
