// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AMM.sol";

contract DeFi is ReentrancyGuard{

    using SafeERC20 for IERC20;

    enum LoanType { TokenA, TokenB }

    struct Loan {
        uint256 collateralAmount;
        uint256 borrowedAmount;
        LoanType loanType;
    }

    struct Share{
        uint256 tokenA_share;
        uint256 tokenB_share;
    }

    mapping(address => Loan) public loans;
    mapping(address => mapping(address => Share)) public shares;

    
    mapping(address => uint256) public totalTokenAStaked;
    mapping(address => uint256) public totalInterestTokenA;

    mapping(address => uint256) public totalTokenBStaked;
    mapping(address => uint256) public totalInterestTokenB;

    uint256 public constant INTEREST_RATE_NUMERATOR = 500; // 5% interest
    uint256 public constant INTEREST_RATE_DENOMINATOR = 10000;

    uint256 public constant COLLATERAL_RATIO_NUMERATOR = 15000; // 150%
    uint256 public constant COLLATERAL_RATIO_DENOMINATOR = 10000;

    uint256 public constant LIQUIDATOR_REWARD_NUMERATOR = 9500; // 95%
    uint256 public constant LIQUIDATOR_REWARD_DENOMINATOR = 10000;

    uint256 public constant LIQUIDATION_FACTOR_NUMERATOR = 5000; // 50%
    uint256 public constant LIQUIDATION_FACTOR_DENOMINATOR = 10000;


    function borrowTokenA(uint256 collateralAmount, uint256 borrowAmount, address poolAddress) external nonReentrant {
        require(loans[msg.sender].borrowedAmount == 0, "Loan already active");

        AMM pool = AMM(poolAddress);
        address tokenA = pool.token0();
        address tokenB = pool.token1();
        uint256 liquidityA = pool.liquidity0();
        uint256 liquidityB = pool.liquidity1();

        uint256 collateralValueInA = (liquidityA * collateralAmount) / liquidityB;

        require(collateralValueInA * 100 >= borrowAmount * 150,"Insufficient collateral: min 150% required");
        require(totalTokenAStaked[poolAddress] >= borrowAmount, "Insufficient TokenA liquidity");

        loans[msg.sender] = Loan({
            collateralAmount: collateralAmount,
            borrowedAmount: borrowAmount,
            loanType: LoanType.TokenA
        });
        
        totalTokenAStaked[poolAddress]-= borrowAmount;
        totalTokenBStaked[poolAddress]+= collateralAmount;

        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), collateralAmount);
        IERC20(tokenA).safeTransfer(msg.sender, borrowAmount);
    }

    function borrowTokenB(uint256 collateralAmount, uint256 borrowAmount, address poolAddress) external nonReentrant {
        require(loans[msg.sender].borrowedAmount == 0, "Loan already active");

        AMM pool = AMM(poolAddress);
        address tokenA = pool.token0();
        address tokenB = pool.token1();
        uint256 liquidityA = pool.liquidity0();
        uint256 liquidityB = pool.liquidity1();

        uint256 collateralValueInB = (liquidityB * collateralAmount) / liquidityA;

        require(collateralValueInB * 100 >= borrowAmount * 150, "Insufficient collateral: min 150% required");
        require(totalTokenBStaked[poolAddress] >= borrowAmount, "Insufficient TokenB liquidity");

        loans[msg.sender] = Loan({
            collateralAmount: collateralAmount,
            borrowedAmount: borrowAmount,
            loanType: LoanType.TokenB
        });


        totalTokenBStaked[poolAddress]-= borrowAmount;
        totalTokenAStaked[poolAddress]+= collateralAmount;

        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), collateralAmount);
        IERC20(tokenB).safeTransfer(msg.sender, borrowAmount);
    }

    function repayLoan(address poolAddress, uint256 amount) external nonReentrant  {
        Loan storage loan = loans[msg.sender];
        require(loan.borrowedAmount > 0, "No active loan");
        require(amount > 0 && amount <= loan.borrowedAmount, "Invalid repayment amount");

        AMM pool = AMM(poolAddress);
        address tokenA = pool.token0();
        address tokenB = pool.token1();

        uint256 previousBorrowedAmount = loan.borrowedAmount;
        uint256 amountIntrest = amount * INTEREST_RATE_NUMERATOR / INTEREST_RATE_DENOMINATOR;

        if (loan.loanType == LoanType.TokenA) {
            totalTokenAStaked[poolAddress] += amount;
            totalInterestTokenA[poolAddress] += amountIntrest;
        } else {
            totalTokenBStaked[poolAddress] += amount;
            totalInterestTokenB[poolAddress] += amountIntrest;
        }

        loan.borrowedAmount -= amount;

        uint256 collateralReturn = (loan.collateralAmount * amount) / previousBorrowedAmount;
        loan.collateralAmount -= collateralReturn;

        if (loan.borrowedAmount == 0) {
            delete loans[msg.sender];
        }

        if (loan.loanType == LoanType.TokenA) {
            IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amount+amountIntrest);
            IERC20(tokenB).safeTransfer(msg.sender, collateralReturn);
        } else {
            IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amount+amountIntrest);
            IERC20(tokenA).safeTransfer(msg.sender, collateralReturn);
        }
    }

    function getHealthFactor(address user, address poolAddress) public view returns (uint256) {
        Loan memory loan = loans[user];
        if (loan.borrowedAmount == 0) return type(uint256).max;

        AMM pool = AMM(poolAddress);
        uint256 price = loan.loanType == LoanType.TokenA
            ? (pool.liquidity0() * 1e18) / pool.liquidity1()
            : (pool.liquidity1() * 1e18) / pool.liquidity0();

        uint256 collateralValue = loan.loanType == LoanType.TokenA
            ? (loan.collateralAmount * price) / 1e18
            : (loan.collateralAmount * price) / 1e18;

        // health factor = (collateral value * ratio) / borrowed
        return (collateralValue * COLLATERAL_RATIO_NUMERATOR * 1e18) / (loan.borrowedAmount * COLLATERAL_RATIO_DENOMINATOR);
    }

    function liquidate(address user, address poolAddress) external nonReentrant {
        Loan storage loan = loans[user];
        require(loan.borrowedAmount > 0, "No active loan");

        uint256 healthFactor = getHealthFactor(user, poolAddress);
        require(healthFactor < 1e18, "Health factor is healthy");

        uint256 repayAmount = (loan.borrowedAmount * LIQUIDATION_FACTOR_NUMERATOR) / LIQUIDATION_FACTOR_DENOMINATOR;
        uint256 collateralToSeize = (loan.collateralAmount * LIQUIDATION_FACTOR_NUMERATOR) / LIQUIDATION_FACTOR_DENOMINATOR;

        AMM pool = AMM(poolAddress);
        address tokenA = pool.token0();
        address tokenB = pool.token1();

        if (loan.loanType == LoanType.TokenA) {
            totalTokenAStaked[poolAddress] += repayAmount;
            totalInterestTokenA[poolAddress] += (repayAmount * INTEREST_RATE_NUMERATOR) / INTEREST_RATE_DENOMINATOR;
        } 
        else {
            totalTokenBStaked[poolAddress] += repayAmount;
            totalInterestTokenB[poolAddress] += (repayAmount * INTEREST_RATE_NUMERATOR) / INTEREST_RATE_DENOMINATOR;
        }

        loan.borrowedAmount -= repayAmount;
        loan.collateralAmount -= collateralToSeize;

        if (loan.borrowedAmount == 0) {
            delete loans[user];
        }

        if (loan.loanType == LoanType.TokenA) {
            IERC20(tokenA).safeTransferFrom(msg.sender, address(this), repayAmount);
            IERC20(tokenB).safeTransfer(msg.sender, collateralToSeize);
        } 
        else {
            IERC20(tokenB).safeTransferFrom(msg.sender, address(this), repayAmount);
            IERC20(tokenA).safeTransfer(msg.sender, collateralToSeize);
        }
    }

    function lendTokenA(uint256 amount, address poolAddress) external nonReentrant {
        require(amount > 0, "Cannot lend 0");

        address tokenA = AMM(poolAddress).token0();
        totalTokenAStaked[poolAddress] += amount;

        shares[msg.sender][poolAddress].tokenA_share += amount;
        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amount);
    }

    function lendTokenB(uint256 amount, address poolAddress) external nonReentrant {
        require(amount > 0, "Cannot lend 0");

        address tokenB = AMM(poolAddress).token1();
        totalTokenBStaked[poolAddress] += amount;

        shares[msg.sender][poolAddress].tokenB_share += amount;
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdrawTokenA(address poolAddress) external nonReentrant {
        Share storage share = shares[msg.sender][poolAddress];
        uint256 userShare = share.tokenA_share;
        require(userShare > 0, "Nothing to withdraw");

        uint256 totalStaked = totalTokenAStaked[poolAddress];
        uint256 interest = totalInterestTokenA[poolAddress];
        uint256 userInterest = (userShare * interest) / totalStaked;

        uint256 totalAmount = userShare + userInterest;

        totalTokenAStaked[poolAddress] -= userShare;
        totalInterestTokenA[poolAddress] -= userInterest;
        share.tokenA_share = 0;

        address tokenA = AMM(poolAddress).token0();
        IERC20(tokenA).safeTransfer(msg.sender, totalAmount);
    }

    function withdrawTokenB(address poolAddress) external nonReentrant {
        Share storage share = shares[msg.sender][poolAddress];
        uint256 userShare = share.tokenB_share;
        require(userShare > 0, "Nothing to withdraw");

        uint256 totalStaked = totalTokenBStaked[poolAddress];
        uint256 interest = totalInterestTokenB[poolAddress];
        uint256 userInterest = (userShare * interest) / totalStaked;

        uint256 totalAmount = userShare + userInterest;

        totalTokenBStaked[poolAddress] -= userShare;
        totalInterestTokenB[poolAddress] -= userInterest;
        share.tokenB_share = 0;

        address tokenB = AMM(poolAddress).token1();
        IERC20(tokenB).safeTransfer(msg.sender, totalAmount);
    }

}
