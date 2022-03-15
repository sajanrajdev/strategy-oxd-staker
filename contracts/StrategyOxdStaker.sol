// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {IERC20Upgradeable} from "@openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {BaseStrategy} from "@badger-finance/BaseStrategy.sol";
import {IBaseV1Pair} from "../interfaces/solidly/IBaseV1Pair.sol";

import "../interfaces/oxd/IUserProxy.sol";
import "../interfaces/oxd/IOxLens.sol";
import "../interfaces/oxd/IMultiRewards.sol";


contract StrategyOxdStaker is BaseStrategy {
    // address public want; // Inherited from BaseStrategy
    // address public lpComponent; // Token that represents ownership in a pool, not always used
    // address public reward; // Token we farm

    // OxDAO
    address public constant userProxyInterface =
        0xDA00BFf59141cA6375c4Ae488DA7b387960b4F10;
    address public constant oxLens =
        0xDA00137c79B30bfE06d04733349d98Cf06320e69;

    address public stakingAddress;

    // Solidly
    address public constant router =
        0xa38cd27185a464914D3046f0AB9d43356B34829D;

    // Badger
    address public constant badgerTree =
        0x89122c767A5F543e663DB536b603123225bc3823;

    // ===== Token Registry =====

    IERC20Upgradeable public constant solid =
        IERC20Upgradeable(0x888EF71766ca594DED1F0FA3AE64eD2941740A20);
    IERC20Upgradeable public constant oxd =
        IERC20Upgradeable(0xc5A9848b9d145965d821AaeC8fA32aaEE026492d);
    IERC20Upgradeable public constant wftm =
        IERC20Upgradeable(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);

    IERC20Upgradeable public token0;
    IERC20Upgradeable public token1;

    /// @dev Initialize the Strategy with security settings as well as tokens
    /// @notice Proxies will set any non constant variable you declare as default value
    /// @dev add any extra changeable variable at end of initializer as shown
    function initialize(address _vault, address[1] memory _wantConfig) public initializer {
        __BaseStrategy_init(_vault);
        /// @dev Add config here
        want = _wantConfig[0];

        // Get staking OxDAO Staking Contract for pool
        stakingAddress = IOxLens(oxLens).stakingRewardsBySolidPool(want);

        // Want is LP with 2 tokens
        IBaseV1Pair lpToken = IBaseV1Pair(want);
        token0 = IERC20Upgradeable(lpToken.token0());
        token1 = IERC20Upgradeable(lpToken.token1());

        // Token approvals
        IERC20Upgradeable(want).safeApprove(userProxyInterface, type(uint256).max);
    }

    /// @dev Return the name of the strategy
    function getName() external pure override returns (string memory) {
        return "StrategyOxdStaker";
    }

    /// @dev Return a list of protected tokens
    /// @notice It's very important all tokens that are meant to be in the strategy to be marked as protected
    /// @notice this provides security guarantees to the depositors they can't be sweeped away
    function getProtectedTokens() public view virtual override returns (address[] memory) {
        address[] memory protectedTokens = new address[](4);
        protectedTokens[0] = want;
        protectedTokens[1] = address(solid);
        protectedTokens[1] = address(oxd);
        protectedTokens[1] = address(wftm);
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
        // No-op as we don't do anything with funds
        // use autoCompoundRatio here to convert rewards to want ...

        // Nothing harvested, we have 2 tokens, return both 0s
        harvested = new TokenAmount[](1);
        harvested[0] = TokenAmount(want, 0);

        // // keep this to get paid!
        // _reportToVault(0);

        // // Use this if your strategy doesn't sell the extra tokens
        // // This will take fees and send the token to the badgerTree
        // _processExtraToken(token, amount);

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
