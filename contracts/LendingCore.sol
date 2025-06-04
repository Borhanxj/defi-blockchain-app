// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Pool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LendingCore {

    enum LoanType { TokenA, TokenB }

    struct Loan {
        uint256 collateralAmount;
        uint256 borrowedAmount;
        LoanType loanType;
    }

    mapping(address => Loan) public loans;
    mapping(address => uint256) public tokenAStakes;
    mapping(address => uint256) public tokenBStakes;
    mapping(address => uint256) public tokenAWithdrawnInterest;
    mapping(address => uint256) public tokenBWithdrawnInterest;

    uint256 public totalInterestTokenA;
    uint256 public totalInterestTokenB;

    uint256 public totalTokenAStaked;
    uint256 public totalTokenBStaked;

    uint256 public constant INTEREST_RATE_NUMERATOR = 500; // 5% interest
    uint256 public constant INTEREST_RATE_DENOMINATOR = 10000;

    uint256 public constant COLLATERAL_RATIO_NUMERATOR = 15000; // 150%
    uint256 public constant COLLATERAL_RATIO_DENOMINATOR = 10000;

    uint256 public constant LIQUIDATOR_REWARD_NUMERATOR = 9500; // 95%
    uint256 public constant LIQUIDATOR_REWARD_DENOMINATOR = 10000;

    function borrowTokenA(uint256 collateralAmount, uint256 borrowAmount, address poolAddress) external {
        require(loans[msg.sender].borrowedAmount == 0, "Loan already active");

        Pool pool = Pool(poolAddress);
        address tokenA = pool.tokenA();
        address tokenB = pool.tokenB();
        uint256 liquidityA = pool.liquidityA();
        uint256 liquidityB = pool.liquidityB();

        uint256 collateralValueInA = (liquidityA * collateralAmount) / liquidityB;

        require(collateralValueInA * 100 >= borrowAmount * 150,"Insufficient collateral: min 150% required");

        IERC20(tokenB).transferFrom(msg.sender, address(this), collateralAmount);
        IERC20(tokenA).transfer(msg.sender, borrowAmount);

        uint256 borrowWithInterest = borrowAmount + (borrowAmount * INTEREST_RATE_NUMERATOR) / INTEREST_RATE_DENOMINATOR;

        loans[msg.sender] = Loan({
            collateralAmount: collateralAmount,
            borrowedAmount: borrowWithInterest,
            loanType: LoanType.TokenA
        });
    }

    function borrowTokenB(uint256 collateralAmount, uint256 borrowAmount, address poolAddress) external {
        require(loans[msg.sender].borrowedAmount == 0, "Loan already active");

        Pool pool = Pool(poolAddress);
        address tokenA = pool.tokenA();
        address tokenB = pool.tokenB();
        uint256 liquidityA = pool.liquidityA();
        uint256 liquidityB = pool.liquidityB();

        uint256 collateralValueInB = (liquidityB * collateralAmount) / liquidityA;

        require(collateralValueInB * 100 >= borrowAmount * 150, "Insufficient collateral: min 150% required");

        IERC20(tokenA).transferFrom(msg.sender, address(this), collateralAmount);
        IERC20(tokenB).transfer(msg.sender, borrowAmount);

        uint256 borrowWithInterest = borrowAmount + (borrowAmount * INTEREST_RATE_NUMERATOR) / INTEREST_RATE_DENOMINATOR;

        loans[msg.sender] = Loan({
            collateralAmount: collateralAmount,
            borrowedAmount: borrowWithInterest,
            loanType: LoanType.TokenB
        });
    }

    function repay(uint256 amount, address poolAddress) external {
        Loan storage loan = loans[msg.sender];
        require(loan.borrowedAmount > 0, "No active loan");

        Pool pool = Pool(poolAddress);
        address token = loan.loanType == LoanType.TokenA ? pool.tokenA() : pool.tokenB();

        require(amount > 0 && amount <= loan.borrowedAmount, "Invalid repay amount");

        IERC20(token).transferFrom(msg.sender, address(this), amount);

        uint256 remainingDebtBefore = loan.borrowedAmount;
        loan.borrowedAmount -= amount;

        if (loan.borrowedAmount == 0) {
            address collateralToken = loan.loanType == LoanType.TokenA ? pool.tokenB() : pool.tokenA();
            IERC20(collateralToken).transfer(msg.sender, loan.collateralAmount);

            uint256 interestPaid = amount > remainingDebtBefore ? amount - remainingDebtBefore : 0;

            if (loan.loanType == LoanType.TokenA) {
                totalInterestTokenA += interestPaid;
            } else {
                totalInterestTokenB += interestPaid;
            }

            delete loans[msg.sender];
        }
    }

    function liquidate(address borrower, address poolAddress) external {

        Loan memory loan = loans[borrower];
        require(loan.borrowedAmount > 0, "No active loan");

        Pool pool = Pool(poolAddress);

        uint256 liquidityA = pool.liquidityA();
        uint256 liquidityB = pool.liquidityB();

        uint256 collateralValue;

        if (loan.loanType == LoanType.TokenA) {
            collateralValue = (liquidityA * loan.collateralAmount) / liquidityB;
        } 
        else {
            collateralValue = (liquidityB * loan.collateralAmount) / liquidityA;
        }
        
        uint256 healthFactor = (collateralValue * 1e18 * COLLATERAL_RATIO_DENOMINATOR) / (loan.borrowedAmount * COLLATERAL_RATIO_NUMERATOR);
        require(healthFactor < 1e18, "Loan is still healthy");

        address collateralToken = loan.loanType == LoanType.TokenA ? pool.tokenB(): pool.tokenA();

        uint256 reward = (loan.collateralAmount * LIQUIDATOR_REWARD_NUMERATOR) / LIQUIDATOR_REWARD_DENOMINATOR;
        IERC20(collateralToken).transfer(msg.sender, reward);

        delete loans[borrower];
    }

    function lendTokenA(uint256 amount, address poolAddress) external {
        require(amount > 0, "Cannot lend 0");

        address tokenA = Pool(poolAddress).tokenA();
        IERC20(tokenA).transferFrom(msg.sender, address(this), amount);

        tokenAStakes[msg.sender] += amount;
        totalTokenAStaked += amount;
    }

    function withdrawLentTokenA(uint256 amount, address poolAddress) external {
        require(amount > 0, "Cannot withdraw 0");
        require(tokenAStakes[msg.sender] >= amount, "Not enough lent balance");

        address tokenA = Pool(poolAddress).tokenA();

        // Calculate interest share
        uint256 totalShare = totalTokenAStaked;
        uint256 userShare = tokenAStakes[msg.sender];
        uint256 totalInterest = totalInterestTokenA;

        // Calculate how much interest user is owed overall
        uint256 earnedInterest = (userShare * totalInterest) / totalShare;

        // Subtract already withdrawn
        uint256 withdrawableInterest = earnedInterest - tokenAWithdrawnInterest[msg.sender];

        // Update balances
        tokenAStakes[msg.sender] -= amount;
        totalTokenAStaked -= amount;
        tokenAWithdrawnInterest[msg.sender] += withdrawableInterest;

        // Transfer both principal and interest
        uint256 totalPayout = amount + withdrawableInterest;
        IERC20(tokenA).transfer(msg.sender, totalPayout);
    }

    function lendTokenB(uint256 amount, address poolAddress) external {
        require(amount > 0, "Cannot lend 0");

        address tokenB = Pool(poolAddress).tokenB();
        IERC20(tokenB).transferFrom(msg.sender, address(this), amount);

        tokenBStakes[msg.sender] += amount;
        totalTokenBStaked += amount;
    }

    function withdrawLentTokenB(uint256 amount, address poolAddress) external {
        require(amount > 0, "Cannot withdraw 0");
        require(tokenBStakes[msg.sender] >= amount, "Not enough lent balance");

        address tokenB = Pool(poolAddress).tokenB();

        uint256 totalShare = totalTokenBStaked;
        uint256 userShare = tokenBStakes[msg.sender];
        uint256 totalInterest = totalInterestTokenB;

        uint256 earnedInterest = (userShare * totalInterest) / totalShare;
        uint256 withdrawableInterest = earnedInterest - tokenBWithdrawnInterest[msg.sender];

        tokenBStakes[msg.sender] -= amount;
        totalTokenBStaked -= amount;
        tokenBWithdrawnInterest[msg.sender] += withdrawableInterest;

        uint256 totalPayout = amount + withdrawableInterest;
        IERC20(tokenB).transfer(msg.sender, totalPayout);
    }

    function getHealthFactor(address borrower, address poolAddress) external view returns (uint256) {
        Loan memory loan = loans[borrower];
        if (loan.borrowedAmount == 0) return type(uint256).max;

        Pool pool = Pool(poolAddress);
        uint256 liquidityA = pool.liquidityA();
        uint256 liquidityB = pool.liquidityB();

        uint256 collateralValue;

        if (loan.loanType == LoanType.TokenA) {
            collateralValue = (liquidityA * loan.collateralAmount) / liquidityB;
        } else {
            collateralValue = (liquidityB * loan.collateralAmount) / liquidityA;
        }

        return (collateralValue * 1e18 * COLLATERAL_RATIO_DENOMINATOR) / (loan.borrowedAmount * COLLATERAL_RATIO_NUMERATOR);
    }
}
