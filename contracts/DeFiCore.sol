// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Pool.sol";
import "./LendingCore.sol";

contract DeFiCore {

    mapping(bytes32 => address[]) public pools;
    address[] public allPools;
    address public lendingCore;

    function _getPoolId(address token0, address token1) internal pure returns (bytes32) {
    (address a, address b) = token0 < token1 ? (token0, token1) : (token1, token0);
    return keccak256(abi.encodePacked(a, b));
    }


    function createPool(address token0, address token1, uint256 amount0, uint256 amount1) external {
    bytes32 poolId = _getPoolId(token0, token1);
    
    IERC20(token0).transferFrom(msg.sender, address(this), amount0);
    IERC20(token1).transferFrom(msg.sender, address(this), amount1);

    Pool newPool = new Pool(token0, token1, msg.sender);

    IERC20(token0).transfer(address(newPool), amount0);
    IERC20(token1).transfer(address(newPool), amount1);

    newPool.initializeLiquidity(amount0, amount1);

    pools[poolId].push(address(newPool));
    allPools.push(address(newPool));
    }

    function getPools(address token0, address token1) external view returns (address[] memory) {
        bytes32 poolId = _getPoolId(token0, token1); // ✅
        return pools[poolId];
    }



    function setLendingCore(address _lendingCore) external {
        require(lendingCore == address(0), "LendingCore already set");
        lendingCore = _lendingCore;
    }

    function borrowToken0(uint256 collateralAmount, uint256 borrowAmount, address poolAddress) external {
        LendingCore(lendingCore).borrowToken0(collateralAmount, borrowAmount, poolAddress);
    }

    function borrowToken1(uint256 collateralAmount, uint256 borrowAmount, address poolAddress) external {
        LendingCore(lendingCore).borrowToken1(collateralAmount, borrowAmount, poolAddress);
    }

    function repay(uint256 amount, address poolAddress) external {
        LendingCore(lendingCore).repay(amount, poolAddress);
    }

    function liquidate(address borrower, address poolAddress) external {
        LendingCore(lendingCore).liquidate(borrower, poolAddress);
    }

    function lendToken0(uint256 amount, address poolAddress) external {
        LendingCore(lendingCore).lendToken0(amount, poolAddress);
    }

    function withdrawLentToken0(uint256 amount, address poolAddress) external {
        LendingCore(lendingCore).withdrawLentToken0(amount, poolAddress);
    }

    function lendToken1(uint256 amount, address poolAddress) external {
        LendingCore(lendingCore).lendToken1(amount, poolAddress);
    }

    function withdrawLentToken1(uint256 amount, address poolAddress) external {
        LendingCore(lendingCore).withdrawLentToken1(amount, poolAddress);
    }

    function getHealthFactor(address borrower, address poolAddress) external view returns (uint256) {
        return LendingCore(lendingCore).getHealthFactor(borrower, poolAddress);
    }


    function swap(address poolAddress, address tokenIn, uint256 amountIn, uint256 minAmountOut) external {
        Pool(poolAddress).swap(tokenIn, amountIn, minAmountOut);
    }

    function addLiquidity(address poolAddress, uint256 amount0, uint256 amount1) external {
        Pool(poolAddress).addLiquidity(amount0, amount1);
    }

    function addLiquiditySingleToken(address poolAddress, address tokenIn, uint256 amountIn) external {
        Pool(poolAddress).addLiquiditySingleToken(tokenIn, amountIn);
    }

    function removeLiquidity(address poolAddress, uint256 share) external {
        Pool(poolAddress).removeLiquidity(share);
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
