// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Pool.sol";
import "./LendingCore.sol";
import "./DeFiHelper.sol";

contract DeFiCore {
    mapping(bytes32 => address[]) public pools;
    address[] public allPools;
    address public lendingCore;
    DeFiHelper public helper;

    event PoolCreated(address indexed token0, address indexed token1, address pool);

    constructor(address _helper) {
        helper = DeFiHelper(_helper);
    }

    function _getPoolId(address token0, address token1) internal pure returns (bytes32) {
        (address a, address b) = token0 < token1 ? (token0, token1) : (token1, token0);
        return keccak256(abi.encodePacked(a, b));
    }

    function createPool(address token0, address token1, uint256 amount0, uint256 amount1) external {
        bytes32 poolId = _getPoolId(token0, token1);

        IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);

        Pool newPool = new Pool(token0, token1, msg.sender, address(helper));

        IERC20(token0).transfer(address(newPool), amount0);
        IERC20(token1).transfer(address(newPool), amount1);

        newPool.initializeLiquidity(amount0, amount1);

        pools[poolId].push(address(newPool));
        allPools.push(address(newPool));

        emit PoolCreated(token0, token1, address(newPool));
    }

    function getPools(address token0, address token1) external view returns (address[] memory) {
        bytes32 poolId = _getPoolId(token0, token1);
        return pools[poolId];
    }

    function setLendingCore(address _lendingCore) external {
        require(lendingCore == address(0), "LendingCore already set");
        lendingCore = _lendingCore;
    }

    function borrowToken0(uint256 collateralAmount, uint256 borrowAmount, address poolAddress) external {
        LendingCore(lendingCore).borrowToken0(collateralAmount, borrowAmount, poolAddress);
        helper.logLendingActivity(msg.sender, poolAddress, "borrow0", collateralAmount);
    }

    function borrowToken1(uint256 collateralAmount, uint256 borrowAmount, address poolAddress) external {
        LendingCore(lendingCore).borrowToken1(collateralAmount, borrowAmount, poolAddress);
        helper.logLendingActivity(msg.sender, poolAddress, "borrow1", collateralAmount);
    }

    function repay(uint256 amount, address poolAddress) external {
        LendingCore(lendingCore).repay(amount, poolAddress);
        helper.logLendingActivity(msg.sender, poolAddress, "repay", amount);
    }

    function liquidate(address borrower, address poolAddress) external {
        LendingCore(lendingCore).liquidate(borrower, poolAddress);
        helper.logLendingActivity(msg.sender, poolAddress, "liquidate", 0);
    }

    function lendToken0(uint256 amount, address poolAddress) external {
        LendingCore(lendingCore).lendToken0(amount, poolAddress);
        helper.logLendingActivity(msg.sender, poolAddress, "lend0", amount);
    }

    function withdrawLentToken0(uint256 amount, address poolAddress) external {
        LendingCore(lendingCore).withdrawLentToken0(amount, poolAddress);
        helper.logLendingActivity(msg.sender, poolAddress, "withdraw0", amount);
    }

    function lendToken1(uint256 amount, address poolAddress) external {
        LendingCore(lendingCore).lendToken1(amount, poolAddress);
        helper.logLendingActivity(msg.sender, poolAddress, "lend1", amount);
    }

    function withdrawLentToken1(uint256 amount, address poolAddress) external {
        LendingCore(lendingCore).withdrawLentToken1(amount, poolAddress);
        helper.logLendingActivity(msg.sender, poolAddress, "withdraw1", amount);
    }

    function getHealthFactor(address borrower, address poolAddress) external view returns (uint256) {
        return LendingCore(lendingCore).getHealthFactor(borrower, poolAddress);
    }

    function swap(address poolAddress, address tokenIn, uint256 amountIn, uint256 minAmountOut) external {
        Pool(poolAddress).swap(tokenIn, amountIn, minAmountOut);
        helper.logSwap(msg.sender, poolAddress, tokenIn, amountIn, minAmountOut);
    }

    function addLiquidity(address poolAddress, uint256 amount0, uint256 amount1) external {
        Pool(poolAddress).addLiquidity(amount0, amount1);
        // Optionally you could call helper.logLiquidityAdd here if share info is available
    }

    function addLiquiditySingleToken(address poolAddress, address tokenIn, uint256 amountIn) external {
        Pool(poolAddress).addLiquiditySingleToken(tokenIn, amountIn);
        // Same as above — optional logging if needed
    }

    function removeLiquidity(address poolAddress, uint256 share) external {
        Pool(poolAddress).removeLiquidity(share);
        // TODO: Optionally track LP withdrawal amount here using helper
    }

    function getAllPools() external view returns (address[] memory) {
        return allPools;
    }

    function getPoolInfo(address poolAddress) external view returns (address token0, address token1, uint256 liquidity0, uint256 liquidity1) {
        Pool pool = Pool(poolAddress);
        return (
            pool.token0(),
            pool.token1(),
            pool.liquidity0(),
            pool.liquidity1()
        );
    }
}
