// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Pool.sol";
import "./LendingCore.sol";

contract DeFiCore {

    mapping(bytes32 => address) public pools;
    address[] public allPools;
    address public lendingCore;

    function createPool(address tokenA,address tokenB,uint256 amountA, uint256 amountB) external {
        bytes32 poolId = keccak256(abi.encodePacked(tokenA, tokenB));
        require(pools[poolId] == address(0), "Pool already exists");

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        Pool newPool = new Pool(tokenA, tokenB, msg.sender);

        IERC20(tokenA).transfer(address(newPool), amountA);
        IERC20(tokenB).transfer(address(newPool), amountB);

        newPool.initializeLiquidity(amountA, amountB);
        pools[poolId] = address(newPool);
        allPools.push(address(newPool));
    }

    function getPool(address tokenA, address tokenB) external view returns (address) {
        bytes32 poolId = keccak256(abi.encodePacked(tokenA, tokenB));
        return pools[poolId];
    }

    function setLendingCore(address _lendingCore) external {
        require(lendingCore == address(0), "LendingCore already set");
        lendingCore = _lendingCore;
    }

    function borrowTokenA(uint256 collateralAmount, uint256 borrowAmount, address poolAddress) external {
        LendingCore(lendingCore).borrowTokenA(collateralAmount, borrowAmount, poolAddress);
    }

    function borrowTokenB(uint256 collateralAmount, uint256 borrowAmount, address poolAddress) external {
        LendingCore(lendingCore).borrowTokenB(collateralAmount, borrowAmount, poolAddress);
    }

    function repay(uint256 amount, address poolAddress) external {
        LendingCore(lendingCore).repay(amount, poolAddress);
    }

    function liquidate(address borrower, address poolAddress) external {
        LendingCore(lendingCore).liquidate(borrower, poolAddress);
    }

    function lendTokenA(uint256 amount, address poolAddress) external {
        LendingCore(lendingCore).lendTokenA(amount, poolAddress);
    }

    function withdrawLentTokenA(uint256 amount, address poolAddress) external {
        LendingCore(lendingCore).withdrawLentTokenA(amount, poolAddress);
    }

    function lendTokenB(uint256 amount, address poolAddress) external {
        LendingCore(lendingCore).lendTokenB(amount, poolAddress);
    }

    function withdrawLentTokenB(uint256 amount, address poolAddress) external {
        LendingCore(lendingCore).withdrawLentTokenB(amount, poolAddress);
    }

    function getHealthFactor(address borrower, address poolAddress) external view returns (uint256) {
        return LendingCore(lendingCore).getHealthFactor(borrower, poolAddress);
    }


    function swap(address poolAddress, address tokenIn, uint256 amountIn) external {
        Pool(poolAddress).swap(tokenIn, amountIn);
    }

    function addLiquidity(address poolAddress, uint256 amountA, uint256 amountB) external {
        Pool(poolAddress).addLiquidity(amountA, amountB);
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

    function getPoolInfo(address poolAddress) external view returns (address tokenA, address tokenB, uint256 liquidityA, uint256 liquidityB) {
    Pool pool = Pool(poolAddress);
    return (
        pool.tokenA(),
        pool.tokenB(),
        pool.liquidityA(),
        pool.liquidityB()
    );
}

}
