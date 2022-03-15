// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IOxPoolFactory {
    function oxPoolsLength() external view returns (uint256);

    function isOxPool(address) external view returns (bool);

    function isOxPoolOrLegacyOxPool(address) external view returns (bool);

    function OXD() external view returns (address);

    function syncPools(uint256) external;

    function oxPools(uint256) external view returns (address);

    function oxPoolBySolidPool(address) external view returns (address);

    function vlOxdAddress() external view returns (address);

    function solidPoolByOxPool(address) external view returns (address);

    function syncedPoolsLength() external returns (uint256);

    function solidlyLensAddress() external view returns (address);

    function voterProxyAddress() external view returns (address);

    function rewardsDistributorAddress() external view returns (address);

    function tokensAllowlist() external view returns (address);
}
