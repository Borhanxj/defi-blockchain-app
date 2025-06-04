// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Pool.sol";

contract DeFiCore {

    mapping(bytes32 => address) public pools;

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
    }

    function getPool(address tokenA, address tokenB) external view returns (address) {
        bytes32 poolId = keccak256(abi.encodePacked(tokenA, tokenB));
        return pools[poolId];
    }
}
