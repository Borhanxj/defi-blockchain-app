// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./Core.sol";

contract Arbitrageur is ReentrancyGuard {
    using SafeERC20 for IERC20;
    Core public core;

    struct ArbitragePath {
        address pool1;
        address pool2;
        address midToken;
        uint256 expectedOutput;
    }

    ArbitragePath public bestPath;

    constructor(address _core) {
        core = Core(_core);
    }

    function findBestArbitrage(address baseToken, uint256 amountIn) external {
        address[] memory pools = core.getAllPools();
        uint256 bestProfit = 0;

        for (uint i = 0; i < pools.length; i++) {
            AMM p1 = AMM(pools[i]);
            (bool ok1, address mid, uint256 amtMid) = simulateSwap(p1, baseToken, amountIn);
            if (!ok1) continue;

            for (uint j = 0; j < pools.length; j++) {
                if (i == j) continue;
                AMM p2 = AMM(pools[j]);
                (bool ok2, , uint256 amtFinal) = simulateSwap(p2, mid, amtMid);
                if (!ok2) continue;

                if (amtFinal > bestProfit) {
                    bestProfit = amtFinal;
                    bestPath = ArbitragePath(address(p1), address(p2), mid, amtFinal);
                }
            }
        }
    }

    function executeArbitrage(address baseToken, uint256 amountIn) external {
        require(bestPath.pool1 != address(0), "No arbitrage path");

        IERC20(baseToken).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(baseToken).approve(bestPath.pool1, amountIn);

        AMM(bestPath.pool1).swap(baseToken, amountIn);
        uint256 midAmount = IERC20(bestPath.midToken).balanceOf(address(this));
        IERC20(bestPath.midToken).approve(bestPath.pool2, midAmount);

        AMM(bestPath.pool2).swap(bestPath.midToken, midAmount);

        uint256 finalAmount = IERC20(baseToken).balanceOf(address(this));
        require(finalAmount > amountIn, "No profit");

        IERC20(baseToken).transfer(msg.sender, finalAmount);
    }

    function simulateSwap(AMM pool,address tokenIn,uint256 amountIn) internal view returns (bool, address, uint256) {
        address tA = pool.token0();
        address tB = pool.token1();
        if (tokenIn != tA && tokenIn != tB) return (false, address(0), 0);

        address tokenOut = tokenIn == tA ? tB : tA;
        uint256 liqIn = tokenIn == tA ? pool.liquidity0() : pool.liquidity1();
        uint256 liqOut = tokenIn == tA ? pool.liquidity1() : pool.liquidity0();
        if (liqIn == 0 || liqOut == 0) return (false, address(0), 0);

        uint256 amountInWithFee = amountIn * 997 / 1000;
        uint256 amountOut = (liqOut * amountInWithFee) / (liqIn + amountInWithFee);
        return (amountOut > 0, tokenOut, amountOut);
    }
}
