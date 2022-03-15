// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../erc20/IERC20.sol";

interface IOxd is IERC20 {
    function mint(address to, uint256 amount) external;
}
