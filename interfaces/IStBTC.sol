// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0; // latest available for using OZ

import "../../openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IStBTC is IERC20 {
    function getPooledBtcByShares(uint256 _sharesAmount)
        external
        view
        returns (uint256);

    function getSharesByPooledBtc(uint256 _pooledBtcAmount)
        external
        view
        returns (uint256);

    function stake(address _referral) external payable returns (uint256);
}
