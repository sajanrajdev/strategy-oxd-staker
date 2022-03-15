// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../erc20/IERC20.sol";

interface IOxSolid is IERC20 {
    function mint(address, uint256) external;

    function convertNftToOxSolid(uint256) external;
}
