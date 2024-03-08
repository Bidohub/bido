// SPDX-License-Identifier: GPL-3.0

/* See contracts/COMPILERS.md */
pragma solidity ^0.8.0;

import "../Bido.sol";

contract MockBido is Bido {
    /**
     * @notice Simulate BTC transaction fees distributed to stakers
     */
    function distributeReward() external payable {}
}
