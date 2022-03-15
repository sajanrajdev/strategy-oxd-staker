// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./IMultiRewards.sol";

interface IOxdV1Rewards is IMultiRewards {
    function stakingCap(address account) external view returns (uint256 cap);
}
