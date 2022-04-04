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
    IBaseV1Router01 public constant SOLIDLY_ROUTER =
        IBaseV1Router01(0xa38cd27185a464914D3046f0AB9d43356B34829D);

    // Badger
    IVault public bBveOxd_Oxd;
    IVault public bOxSolid;
    IVault public bveOXD;

    // slippage tolerance 95% (divide by MAX_BPS) - Changeable by Governance or Strategist
    uint256 public sl;

    // ===== Token Registry =====

    IERC20Upgradeable public constant SOLID =
        IERC20Upgradeable(0x888EF71766ca594DED1F0FA3AE64eD2941740A20);
    IERC20Upgradeable public constant OXD =
        IERC20Upgradeable(0xc5A9848b9d145965d821AaeC8fA32aaEE026492d);
    IERC20Upgradeable public constant OXSOLID =
        IERC20Upgradeable(0xDA0053F0bEfCbcaC208A3f867BB243716734D809);
    IERC20Upgradeable public constant BVEOXD =
        IERC20Upgradeable(0x96d4dBdc91Bef716eb407e415c9987a9fAfb8906);
    IERC20Upgradeable public constant BVEOXD_OXD =
        IERC20Upgradeable(0x6519546433dCB0a34A0De908e1032c46906EF664);

    // Helpers
    address public constant BBVEOXD_OXD = 0xbF2F3a9ba42A00CA5B18842D8eB1954120e4a2A9;
    address public constant BOXSOLID = 0xa8bD8655A0dCABE76913D821Ab437562276b3B59;

    /// @dev Initialize the Strategy with security settings as well as tokens
    /// @notice Proxies will set any non constant variable you declare as default value
    /// @dev add any extra changeable variable at end of initializer as shown
    function initialize(address _vault, address _want) public initializer {
        __BaseStrategy_init(_vault);
        want = _want;

        bBveOxd_Oxd = IVault(BBVEOXD_OXD);
        bOxSolid = IVault(BOXSOLID);
        bveOXD = IVault(address(BVEOXD));

        // Get staking OxDAO Staking Contract for pool
        stakingAddress = IOxLens(oxLens).stakingRewardsBySolidPool(want);

        // Set default slippage value (95%)
        sl = 9_500;

        // Token approvals
        IERC20Upgradeable(want).safeApprove(userProxyInterface, type(uint256).max);
        SOLID.safeApprove(address(SOLIDLY_ROUTER), type(uint256).max);
        OXD.safeApprove(address(SOLIDLY_ROUTER), type(uint256).max);
        OXD.safeApprove(address(BVEOXD), type(uint256).max);
        BVEOXD.safeApprove(address(SOLIDLY_ROUTER), type(uint256).max);
        BVEOXD_OXD.safeApprove(BBVEOXD_OXD, type(uint256).max);
        OXSOLID.safeApprove(BOXSOLID, type(uint256).max);
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
        protectedTokens[1] = address(SOLID);
        protectedTokens[2] = address(OXD);
        protectedTokens[3] = address(OXSOLID);
        protectedTokens[4] = address(bveOXD);
        protectedTokens[5] = address(BVEOXD_OXD);
        return protectedTokens;
    }

    /// @notice sets slippage tolerance for liquidity provision
    function setSlippageTolerance(uint256 _s) external whenNotPaused {
        _onlyGovernanceOrStrategist();
        sl = _s;
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
        harvested[0].token = address(bBveOxd_Oxd);
        harvested[1].token = address(bOxSolid);

        // 1. Claim all staking rewards (OXD, SOLID and oxSOLID in some cases).
        IUserProxy(userProxyInterface).claimStakingRewards();

        // 2. Desposit all OXD into bBveOXD/OXD and distribute
        uint256 oxdBalance = OXD.balanceOf(address(this));
        if (oxdBalance > 0) {
            // Get bveOXD/OXD pool's reserves ratio
            uint256 ratio = getSolidlyPoolRatio(
                address(OXD),
                address(BVEOXD),
                false
            );

            // Estimate the amounts required for liquidity provision
            uint256 amount_bveOXD = oxdBalance.mul(MAX_BPS).div(MAX_BPS + ratio);
            uint256 amount_OXD = oxdBalance - amount_bveOXD;

            // Check if swap quote is within the slippage tolerance from the
            // required amount, otherwise deposit on bveOXD directly
            (uint256 solidlyQuote,) = IBaseV1Router01(SOLIDLY_ROUTER)
                .getAmountOut(amount_OXD, address(OXD), address(BVEOXD));

            if (solidlyQuote > amount_bveOXD.mul(1e18).div(bveOXD.getPricePerFullShare())) {
                route[] memory routeArray = new route[](1);
                routeArray[0] = route(address(OXD), address(BVEOXD), false); // Volatile pool
                SOLIDLY_ROUTER.swapExactTokensForTokens(
                    amount_OXD,
                    0,
                    routeArray,
                    address(this),
                    block.timestamp
                );
            } else {
                bveOXD.deposit(amount_bveOXD);
            }

            // Add liquidity to the bveOXD/OXD LP Volatile pool
            uint256 bveOXDIn = BVEOXD.balanceOf(address(this));
            uint256 oxdIn = OXD.balanceOf(address(this));
            SOLIDLY_ROUTER.addLiquidity(
                address(BVEOXD),
                address(OXD),
                false,
                bveOXDIn,
                oxdIn,
                bveOXDIn.mul(sl).div(MAX_BPS),
                oxdIn.mul(sl).div(MAX_BPS),
                address(this),
                now
            );

            // Deposit all acquired bveOXD/OXD LP into the Badger helper
            bBveOxd_Oxd.depositAll();
            uint256 vaultBalance = bBveOxd_Oxd.balanceOf(address(this));

            harvested[0].amount = vaultBalance;
            _processExtraToken(address(bBveOxd_Oxd), vaultBalance);
        }

        // 3. Swap SOLID for oxSOLID
        uint256 solidBalance = SOLID.balanceOf(address(this));
        if (solidBalance > 0) {
            (, bool stable) = SOLIDLY_ROUTER.getAmountOut(
                solidBalance,
                address(SOLID),
                address(OXSOLID)
            );

            route[] memory routeArray = new route[](1);
            routeArray[0] = route(address(SOLID), address(OXSOLID), stable);
            SOLIDLY_ROUTER.swapExactTokensForTokens(
                solidBalance,
                solidBalance, // at least 1:1
                routeArray,
                address(this),
                block.timestamp
            );
        }

        // 4. Deposit all oxSOLID into bOxSolid and distribute
        uint256 oxSolidBalance = OXSOLID.balanceOf(address(this));
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

    /// @dev View function to find the reserves ratio of a certain pool on Solidly
    function getSolidlyPoolRatio(
        address tokenA,
        address tokenB,
        bool volatile
    ) public view returns (uint256) {
        (uint256 reservesA, uint256 reservesB) = SOLIDLY_ROUTER.getReserves(
            tokenA,
            tokenB,
            volatile
        );
        return reservesA.mul(MAX_BPS).div(reservesB);
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
