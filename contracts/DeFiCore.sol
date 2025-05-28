// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract DEFI{

    // A simple mapping for information of each user
    mapping(address => uint) public collateralA;
    mapping(address => uint) public collateralB;
    mapping(address => uint) public debtA;
    mapping(address => uint) public debtB;

    // A constructor for when the smart contract is deployed, should store storage for tokens
    constructor(){}

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
