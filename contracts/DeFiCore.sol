// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract DEFI{
    // For liquidity providers 
    function addLiquidity()
    function removeLiquidity()

    // For Liquidators
    function liquidate() // liquidate a user if health factor is low

    // For Users
    function swap() // Swap A - B
    function depositCollateral() // Deposit an amount 
    function borrow() // Borrow from collateralized debt
    function repayDebt() // Repay the borrowed and obtain collateral 
    function getInfo() // Get info about debt and collaterals
    function getHealthFactor() // Get the health factor of the debt
}
