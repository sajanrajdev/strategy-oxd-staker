// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./IOxd.sol";
import "./IVlOxd.sol";
import "./IOxPoolFactory.sol";
import "./IOxSolid.sol";
import "./ISolid.sol";
import "./ISolidlyLens.sol";
import "./IUserProxy.sol";
import "./IVe.sol";
import "./IVotingSnapshot.sol";
import "./IVoterProxy.sol";
import "./IOxdV1Rewards.sol";
import "./ITokensAllowlist.sol";

interface IOxLens {
    struct ProtocolAddresses {
        address oxPoolFactoryAddress;
        address solidlyLensAddress;
        address oxdAddress;
        address vlOxdAddress;
        address oxSolidAddress;
        address voterProxyAddress;
        address solidAddress;
        address voterAddress;
        address poolsFactoryAddress;
        address gaugesFactoryAddress;
        address minterAddress;
        address veAddress;
        address userProxyInterfaceAddress;
        address votingSnapshotAddress;
    }

    struct UserPosition {
        address userProxyAddress;
        uint256 veTotalBalanceOf;
        ISolidlyLens.PositionVe[] vePositions;
        ISolidlyLens.PositionPool[] poolsPositions;
        IUserProxy.PositionStakingPool[] stakingPools;
        uint256 oxSolidBalanceOf;
        uint256 oxdBalanceOf;
        uint256 solidBalanceOf;
        uint256 vlOxdBalanceOf;
    }

    struct TokenMetadata {
        address id;
        string name;
        string symbol;
        uint8 decimals;
        uint256 priceUsdc;
    }

    struct OxPoolData {
        address id;
        address stakingAddress;
        uint256 stakedTotalSupply;
        uint256 totalSupply;
        ISolidlyLens.Pool poolData;
    }

    struct Pool {
        address id;
        string symbol;
        bool stable;
        address token0Address;
        address token1Address;
        address gaugeAddress;
        address bribeAddress;
        address[] bribeTokensAddresses;
        address fees;
    }

    struct RewardTokenData {
        address id;
        uint256 rewardRate;
        uint256 periodFinish;
    }

    /* ========== PUBLIC VARS ========== */

    function oxPoolFactoryAddress() external view returns (address);

    function userProxyFactoryAddress() external view returns (address);

    function solidlyLensAddress() external view returns (address);

    function oxdAddress() external view returns (address);

    function vlOxdAddress() external view returns (address);

    function oxSolidAddress() external view returns (address);

    function voterProxyAddress() external view returns (address);

    function veAddress() external view returns (address);

    function solidAddress() external view returns (address);

    function oxSolidRewardsPoolAddress() external view returns (address);

    function partnersRewardsPoolAddress() external view returns (address);

    function treasuryAddress() external view returns (address);

    function cvlOxdAddress() external view returns (address);

    function oxdV1RewardsAddress() external view returns (address);

    function oxdV1RedeemAddress() external view returns (address);

    function oxdV1Address() external view returns (address);

    /* ========== PUBLIC VIEW FUNCTIONS ========== */

    function voterAddress() external view returns (address);

    function poolsFactoryAddress() external view returns (address);

    function gaugesFactoryAddress() external view returns (address);

    function minterAddress() external view returns (address);

    function protocolAddresses()
        external
        view
        returns (ProtocolAddresses memory);

    function positionsOf(address accountAddress)
        external
        view
        returns (UserPosition memory);

    function rewardTokensPositionsOf(address, address)
        external
        view
        returns (IUserProxy.RewardToken[] memory);

    function stakingPoolsPositions(address accountAddress)
        external
        view
        returns (IUserProxy.PositionStakingPool[] memory);

    function veTotalBalanceOf(ISolidlyLens.PositionVe[] memory positions)
        external
        pure
        returns (uint256);

    function oxPoolsLength() external view returns (uint256);

    function userProxiesLength() external view returns (uint256);

    function userProxyByAccount(address accountAddress)
        external
        view
        returns (address);

    function userProxyByIndex(uint256 index) external view returns (address);

    function gaugeBySolidPool(address) external view returns (address);

    function solidPoolByOxPool(address oxPoolAddress)
        external
        view
        returns (address);

    function oxPoolBySolidPool(address solidPoolAddress)
        external
        view
        returns (address);

    function stakingRewardsBySolidPool(address solidPoolAddress)
        external
        view
        returns (address);

    function stakingRewardsByOxPool(address solidPoolAddress)
        external
        view
        returns (address);

    function isOxPool(address oxPoolAddress) external view returns (bool);

    function oxPoolsAddresses() external view returns (address[] memory);

    function oxPoolData(address oxPoolAddress)
        external
        view
        returns (OxPoolData memory);

    function oxPoolsData(address[] memory _oxPoolsAddresses)
        external
        view
        returns (OxPoolData[] memory);

    function oxPoolsData() external view returns (OxPoolData[] memory);

    function oxSolid() external view returns (IOxSolid);

    function oxd() external view returns (IOxd);

    function vlOxd() external view returns (IVlOxd);

    function oxPoolFactory() external view returns (IOxPoolFactory);

    function solid() external view returns (ISolid);

    function ve() external view returns (IVe);

    function voterProxy() external view returns (IVoterProxy);

    function votingSnapshot() external view returns (IVotingSnapshot);

    function tokensAllowlist() external view returns (ITokensAllowlist);

    function isPartner(address userProxyAddress) external view returns (bool);

    function stakedOxSolidBalanceOf(address accountAddress)
        external
        view
        returns (uint256 stakedBalance);

    function solidInflationSinceInception() external view returns (uint256);
}