// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Pool.sol";
import "./DeFiHelper.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LendingCore {
    enum LoanType { Token0, Token1 }

    struct Loan {
        uint256 collateralAmount;
        uint256 borrowedAmount;
        LoanType loanType;
    }

    mapping(address => mapping(address => Loan)) public loans;
    mapping(address => mapping(address => uint256)) public stakes0;
    mapping(address => mapping(address => uint256)) public stakes1;
    mapping(address => mapping(address => uint256)) public withdrawnInterest0;
    mapping(address => mapping(address => uint256)) public withdrawnInterest1;

    mapping(address => uint256) public totalInterest0;
    mapping(address => uint256) public totalInterest1;
    mapping(address => uint256) public totalStaked0;
    mapping(address => uint256) public totalStaked1;

    DeFiHelper public helper;

    uint256 public constant INTEREST_RATE_NUMERATOR = 500;
    uint256 public constant INTEREST_RATE_DENOMINATOR = 10000;
    uint256 public constant COLLATERAL_RATIO_NUMERATOR = 15000;
    uint256 public constant COLLATERAL_RATIO_DENOMINATOR = 10000;
    uint256 public constant LIQUIDATOR_REWARD_NUMERATOR = 9500;
    uint256 public constant LIQUIDATOR_REWARD_DENOMINATOR = 10000;

    constructor(address _helper) {
        helper = DeFiHelper(_helper);
    }

    function borrowToken0(uint256 collateralAmount, uint256 borrowAmount, address poolAddress) external {
        require(loans[msg.sender][poolAddress].borrowedAmount == 0, "Loan already active");

        Pool pool = Pool(poolAddress);
        address token0 = pool.token0();
        address token1 = pool.token1();
        uint256 liquidity0 = pool.liquidity0();
        uint256 liquidity1 = pool.liquidity1();

        uint256 collateralValueIn0 = (liquidity0 * collateralAmount) / liquidity1;
        require(collateralValueIn0 * 100 >= borrowAmount * 150, "Insufficient collateral");

        IERC20(token1).transferFrom(msg.sender, address(this), collateralAmount);
        IERC20(token0).transfer(msg.sender, borrowAmount);

        _finalizeBorrowToken0(poolAddress, token0, token1, collateralAmount, borrowAmount);
    }

    function _finalizeBorrowToken0(
        address poolAddress,
        address token0,
        address token1,
        uint256 collateralAmount,
        uint256 borrowAmount
    ) internal {
        uint256 borrowWithInterest = borrowAmount + (borrowAmount * INTEREST_RATE_NUMERATOR) / INTEREST_RATE_DENOMINATOR;

        loans[msg.sender][poolAddress] = Loan(collateralAmount, borrowWithInterest, LoanType.Token0);
        helper.logBorrow(msg.sender, poolAddress, token0, borrowAmount, token1, collateralAmount);
    }


    function borrowToken1(uint256 collateralAmount, uint256 borrowAmount, address poolAddress) external {
        require(loans[msg.sender][poolAddress].borrowedAmount == 0, "Loan already active");

        Pool pool = Pool(poolAddress);
        address token0 = pool.token0();
        address token1 = pool.token1();
        uint256 liquidity0 = pool.liquidity0();
        uint256 liquidity1 = pool.liquidity1();

        uint256 collateralValueIn1 = (liquidity1 * collateralAmount) / liquidity0;
        require(collateralValueIn1 * 100 >= borrowAmount * 150, "Insufficient collateral");

        IERC20(token0).transferFrom(msg.sender, address(this), collateralAmount);
        IERC20(token1).transfer(msg.sender, borrowAmount);

        _finalizeBorrowToken1(poolAddress, token0, token1, collateralAmount, borrowAmount);
    }

    function _finalizeBorrowToken1(
        address poolAddress,
        address token0,
        address token1,
        uint256 collateralAmount,
        uint256 borrowAmount
    ) internal {
        uint256 borrowWithInterest = borrowAmount + (borrowAmount * INTEREST_RATE_NUMERATOR) / INTEREST_RATE_DENOMINATOR;
        loans[msg.sender][poolAddress] = Loan(collateralAmount, borrowWithInterest, LoanType.Token1);
        helper.logBorrow(msg.sender, poolAddress, token1, borrowAmount, token0, collateralAmount);
    }

    function repay(uint256 amount, address poolAddress) external {
        Loan storage loan = loans[msg.sender][poolAddress];
        require(loan.borrowedAmount > 0, "No active loan");

        Pool pool = Pool(poolAddress);
        address token = loan.loanType == LoanType.Token0 ? pool.token0() : pool.token1();

        require(amount > 0 && amount <= loan.borrowedAmount, "Invalid repay amount");
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        uint256 previousDebt = loan.borrowedAmount;
        loan.borrowedAmount -= amount;

        if (loan.borrowedAmount == 0) {
            address collateralToken = loan.loanType == LoanType.Token0 ? pool.token1() : pool.token0();
            IERC20(collateralToken).transfer(msg.sender, loan.collateralAmount);

            uint256 interestPaid = amount > previousDebt ? amount - previousDebt : 0;

            if (loan.loanType == LoanType.Token0) {
                totalInterest0[poolAddress] += interestPaid;
            } else {
                totalInterest1[poolAddress] += interestPaid;
            }

            delete loans[msg.sender][poolAddress];
        }
    }

    function liquidate(address borrower, address poolAddress) external {
        Loan memory loan = loans[borrower][poolAddress];
        require(loan.borrowedAmount > 0, "No active loan");

        Pool pool = Pool(poolAddress);
        uint256 liquidity0 = pool.liquidity0();
        uint256 liquidity1 = pool.liquidity1();

        uint256 collateralValue = loan.loanType == LoanType.Token0
            ? (liquidity0 * loan.collateralAmount) / liquidity1
            : (liquidity1 * loan.collateralAmount) / liquidity0;

        uint256 healthFactor = (collateralValue * 1e18 * COLLATERAL_RATIO_DENOMINATOR) /
                               (loan.borrowedAmount * COLLATERAL_RATIO_NUMERATOR);

        require(healthFactor < 1e18, "Loan is still healthy");

        address collateralToken = loan.loanType == LoanType.Token0 ? pool.token1() : pool.token0();
        uint256 reward = (loan.collateralAmount * LIQUIDATOR_REWARD_NUMERATOR) / LIQUIDATOR_REWARD_DENOMINATOR;

        IERC20(collateralToken).transfer(msg.sender, reward);
        delete loans[borrower][poolAddress];
    }

    function lendToken0(uint256 amount, address poolAddress) external {
        require(amount > 0, "Cannot lend 0");
        address token0 = Pool(poolAddress).token0();

        stakes0[msg.sender][poolAddress] += amount;
        totalStaked0[poolAddress] += amount;

        IERC20(token0).transferFrom(msg.sender, address(this), amount);
        helper.logLend(msg.sender, poolAddress, token0, amount);
    }

    function withdrawLentToken0(uint256 amount, address poolAddress) external {
        require(amount > 0, "Cannot withdraw 0");
        require(stakes0[msg.sender][poolAddress] >= amount, "Insufficient balance");

        address token0 = Pool(poolAddress).token0();

        uint256 totalShare = totalStaked0[poolAddress];
        uint256 userShare = stakes0[msg.sender][poolAddress];
        uint256 totalInterest = totalInterest0[poolAddress];

        uint256 earnedInterest = (userShare * totalInterest) / totalShare;
        uint256 withdrawableInterest = earnedInterest - withdrawnInterest0[msg.sender][poolAddress];

        stakes0[msg.sender][poolAddress] -= amount;
        totalStaked0[poolAddress] -= amount;
        withdrawnInterest0[msg.sender][poolAddress] += withdrawableInterest;

        uint256 totalPayout = amount + withdrawableInterest;
        IERC20(token0).transfer(msg.sender, totalPayout);
    }

    function lendToken1(uint256 amount, address poolAddress) external {
        require(amount > 0, "Cannot lend 0");
        address token1 = Pool(poolAddress).token1();

        stakes1[msg.sender][poolAddress] += amount;
        totalStaked1[poolAddress] += amount;

        IERC20(token1).transferFrom(msg.sender, address(this), amount);
        helper.logLend(msg.sender, poolAddress, token1, amount);
    }

    function withdrawLentToken1(uint256 amount, address poolAddress) external {
        require(amount > 0, "Cannot withdraw 0");
        require(stakes1[msg.sender][poolAddress] >= amount, "Insufficient balance");

        address token1 = Pool(poolAddress).token1();

        uint256 totalShare = totalStaked1[poolAddress];
        uint256 userShare = stakes1[msg.sender][poolAddress];
        uint256 totalInterest = totalInterest1[poolAddress];

        uint256 earnedInterest = (userShare * totalInterest) / totalShare;
        uint256 withdrawableInterest = earnedInterest - withdrawnInterest1[msg.sender][poolAddress];

        stakes1[msg.sender][poolAddress] -= amount;
        totalStaked1[poolAddress] -= amount;
        withdrawnInterest1[msg.sender][poolAddress] += withdrawableInterest;

        uint256 totalPayout = amount + withdrawableInterest;
        IERC20(token1).transfer(msg.sender, totalPayout);
    }

    function getHealthFactor(address borrower, address poolAddress) external view returns (uint256) {
        Loan memory loan = loans[borrower][poolAddress];
        if (loan.borrowedAmount == 0) return type(uint256).max;

        Pool pool = Pool(poolAddress);
        uint256 liquidity0 = pool.liquidity0();
        uint256 liquidity1 = pool.liquidity1();

        uint256 collateralValue = loan.loanType == LoanType.Token0
            ? (liquidity0 * loan.collateralAmount) / liquidity1
            : (liquidity1 * loan.collateralAmount) / liquidity0;

        return (collateralValue * 1e18 * COLLATERAL_RATIO_DENOMINATOR) /
               (loan.borrowedAmount * COLLATERAL_RATIO_NUMERATOR);
    }
}
