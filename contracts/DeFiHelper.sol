// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPool {
    function tokenA() external view returns (address);
    function tokenB() external view returns (address);
    function liquidityA() external view returns (uint256);
    function liquidityB() external view returns (uint256);
    function lpShares(address user) external view returns (uint256);
    function totalShares() external view returns (uint256);
}

contract DeFiHelper {
    address[] public allPools;
    mapping(address => address[]) public userPools;

    event SwapLogged(address indexed user, address indexed pool, address tokenIn, uint256 amountIn, uint256 amountOut, uint256 timestamp);
    event LiquidityAddedLogged(address indexed user, address indexed pool, uint256 amount0, uint256 amount1, uint256 shareMinted, uint256 timestamp);
    event LiquidityRemovedLogged(address indexed user, address indexed pool, uint256 amount0, uint256 amount1, uint256 shareBurned, uint256 timestamp);
    event LendingActivityLogged(address indexed user, address indexed pool, string activityType, uint256 amount, uint256 timestamp);

    function addPool(address pool) external {
        allPools.push(pool);
    }

    function getPools() external view returns (address[] memory) {
        return allPools;
    }

    function getPoolInfo(address pool) external view returns (address, address, uint256, uint256) {
        return (
            IPool(pool).tokenA(),
            IPool(pool).tokenB(),
            IPool(pool).liquidityA(),
            IPool(pool).liquidityB()
        );
    }

    function getUserShare(address pool, address user) external view returns (uint256 userShare, uint256 totalShare) {
        userShare = IPool(pool).lpShares(user);
        totalShare = IPool(pool).totalShares();
    }

    // Logging functions to be called by other contracts
    function logSwap(address user, address pool, address tokenIn, uint256 amountIn, uint256 amountOut) external {
        emit SwapLogged(user, pool, tokenIn, amountIn, amountOut, block.timestamp);
    }

    function logLiquidityAdd(address user, address pool, uint256 amount0, uint256 amount1, uint256 shareMinted) external {
        emit LiquidityAddedLogged(user, pool, amount0, amount1, shareMinted, block.timestamp);
    }

    function logLiquidityRemove(address user, address pool, uint256 amount0, uint256 amount1, uint256 shareBurned) external {
        emit LiquidityRemovedLogged(user, pool, amount0, amount1, shareBurned, block.timestamp);
    }

    function logLendingActivity(address user, address pool, string calldata activityType, uint256 amount) external {
        emit LendingActivityLogged(user, pool, activityType, amount, block.timestamp);
    }
}
