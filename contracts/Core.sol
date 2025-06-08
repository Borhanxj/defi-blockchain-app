// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AMM.sol";

contract Core is ReentrancyGuard {

    using SafeERC20 for IERC20;

    address[] public allPools;

    function createPool(address token0,address token1,uint256 amount0, uint256 amount1) external nonReentrant returns (address) {

        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);

        AMM newPool = new AMM(token0, token1, msg.sender);

        IERC20(token0).safeTransfer(address(newPool), amount0);
        IERC20(token1).safeTransfer(address(newPool), amount1);

        newPool.initializeLiquidity(amount0, amount1);
        allPools.push(address(newPool));

        return address(newPool);
    }
}
