// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {IERC20Upgradeable} from "@openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {BaseStrategy} from "@badger-finance/BaseStrategy.sol";
import {route, IBaseV1Router01} from "../interfaces/solidly/IBaseV1Router01.sol";
import {IVault} from "../interfaces/badger/IVault.sol";

import "../interfaces/oxd/IUserProxy.sol";
import "../interfaces/oxd/IOxLens.sol";
import "../interfaces/oxd/IMultiRewards.sol";

contract StrategyOxdStakingOptimizer is BaseStrategy {

    // OxDAO
    address public constant userProxyInterface =
        0xDA00BFf59141cA6375c4Ae488DA7b387960b4F10;
    address public constant oxLens =
        0xDA00137c79B30bfE06d04733349d98Cf06320e69;

    address public stakingAddress;

    // Solidly
    IBaseV1Router01 public constant router =
        IBaseV1Router01(0xa38cd27185a464914D3046f0AB9d43356B34829D);

    IVault public bveOXD;
    IVault public bOxSolid;

    // ===== Token Registry =====

    IERC20Upgradeable public constant solid =
        IERC20Upgradeable(0x888EF71766ca594DED1F0FA3AE64eD2941740A20);
    IERC20Upgradeable public constant oxd =
        IERC20Upgradeable(0xc5A9848b9d145965d821AaeC8fA32aaEE026492d);
    IERC20Upgradeable public constant oxSolid =
        IERC20Upgradeable(0xDA0053F0bEfCbcaC208A3f867BB243716734D809);

    /// @dev Initialize the Strategy with security settings as well as tokens
    /// @notice Proxies will set any non constant variable you declare as default value
    /// @dev add any extra changeable variable at end of initializer as shown
    function initialize(address _vault, address[3] memory _wantConfig) public initializer {
        __BaseStrategy_init(_vault);
        /// @dev Add config here
        want = _wantConfig[0];
        bveOXD = IVault(_wantConfig[1]);
        bOxSolid = IVault(_wantConfig[2]);

        // Get staking OxDAO Staking Contract for pool
        stakingAddress = IOxLens(oxLens).stakingRewardsBySolidPool(want);

        // Token approvals
        IERC20Upgradeable(want).safeApprove(userProxyInterface, type(uint256).max);
        solid.safeApprove(address(router), type(uint256).max);
        oxd.safeApprove(address(bveOXD), type(uint256).max);
        oxSolid.safeApprove(address(bOxSolid), type(uint256).max);
    }

    /// @dev Return the name of the strategy
    function getName() external pure override returns (string memory) {
        return "StrategyOxdStakingOptimizer";
    }

    /// @dev Return a list of protected tokens
    /// @notice It's very important all tokens that are meant to be in the strategy to be marked as protected
    /// @notice this provides security guarantees to the depositors they can't be sweeped away
    function getProtectedTokens() public view virtual override returns (address[] memory) {
        address[] memory protectedTokens = new address[](6);
        protectedTokens[0] = want;
        protectedTokens[1] = address(solid);
        protectedTokens[2] = address(oxd);
        protectedTokens[3] = address(oxSolid);
        protectedTokens[4] = address(bveOXD);
        protectedTokens[5] = address(bOxSolid);
        return protectedTokens;
    }

    /// @dev Deposit `_amount` of want, investing it to earn yield
    function _deposit(uint256 _amount) internal override {
        IUserProxy(userProxyInterface).depositLpAndStake(want, _amount);
    }

    /// @dev Withdraw all funds, this is used for migrations, most of the time for emergency reasons
    function _withdrawAll() internal override {
        IUserProxy(userProxyInterface).unstakeLpAndWithdraw(want); // No amount argument means MAX amount
    }

    /// @dev Withdraw `_amount` of want, so that it can be sent to the vault / depositor
    /// @notice just unlock the funds and return the amount you could unlock
    function _withdrawSome(uint256 _amount) internal override returns (uint256) {
        IUserProxy(userProxyInterface).unstakeLpAndWithdraw(want, _amount);
        return _amount;
    }

    /// @dev Does this function require `tend` to be called?
    function _isTendable() internal override pure returns (bool) {
        return false; // Change to true if the strategy should be tended
    }

    function _harvest() internal override returns (TokenAmount[] memory harvested) {
        harvested = new TokenAmount[](2);

        // 1. Claim all staking rewards (OXD, SOLID and oxSOLID in some cases).
        IUserProxy(userProxyInterface).claimStakingRewards();

        // 2. Desposit all OXD into bveOXD and distribute
        uint256 oxdBalance = oxd.balanceOf(address(this));
        harvested[0].token = address(bveOXD);
        if (oxdBalance > 0) {
            bveOXD.deposit(oxdBalance);
            uint256 vaultBalance = bveOXD.balanceOf(address(this));

            harvested[0].amount = vaultBalance;
            _processExtraToken(address(bveOXD), vaultBalance);
        }

        // 3. Swap SOLID for oxSOLID
        uint256 solidBalance = solid.balanceOf(address(this));
        if (solidBalance > 0) {
            (, bool stable) = router.getAmountOut(
                solidBalance,
                address(solid),
                address(oxSolid)
            );

            route[] memory routeArray = new route[](1);
            routeArray[0] = route(address(solid), address(oxSolid), stable);
            router.swapExactTokensForTokens(
                solidBalance,
                solidBalance, // at least 1:1
                routeArray,
                address(this),
                block.timestamp
            );
        }

        // 4. Deposit all oxSOLID into bOxSolid and distribute
        uint256 oxSolidBalance = oxSolid.balanceOf(address(this));
        harvested[1].token = address(bOxSolid);
        if (oxSolidBalance > 0) {
            bOxSolid.deposit(oxSolidBalance);
            uint256 vaultBalance = bOxSolid.balanceOf(address(this));

            harvested[1].amount = vaultBalance;
            _processExtraToken(address(bOxSolid), vaultBalance);
        }

        // keep this to get paid!
        _reportToVault(0);

        // Harvested: bveOXD and bOxSolid
        return harvested;
    }

    // Example tend is a no-op which returns the values, could also just revert
    function _tend() internal override returns (TokenAmount[] memory tended) {
        revert("no op");
    }

    /// @dev Return the balance (in want) that the strategy has invested somewhere
    function balanceOfPool() public view override returns (uint256) {
        // Fetch UserProxy
        address userProxy = getUserProxy();

        // UserProxy is created upon the first deposit
        if (userProxy != address(0)) {
            // Determine amount currently staked
            return IMultiRewards(stakingAddress).balanceOf(userProxy);
        } else {
            return 0;
        }
    }

    /// @dev Return the balance of rewards that the strategy has accrued
    /// @notice Used for offChain APY and Harvest Health monitoring
    function balanceOfRewards() external view override returns (TokenAmount[] memory rewards) {
        uint256 length = IMultiRewards(stakingAddress).rewardTokensLength();
        rewards = new TokenAmount[](length);
        address reward;

        for (uint256 i; i < length; i++) {
            reward = IMultiRewards(stakingAddress).rewardTokens(i);
            rewards[i] = TokenAmount(
                reward,
                IMultiRewards(stakingAddress).earned(
                    getUserProxy(),
                    reward
                )
            );
        }
        return rewards;
    }

    /// @dev Return the address of the userProxy deployed upon the first deposit
    /// @notice The userProxy is used to fetch user balance and rewards
    function getUserProxy() public view returns (address) {
        return IOxLens(oxLens).userProxyByAccount(
            address(this)
        );
    }
}
