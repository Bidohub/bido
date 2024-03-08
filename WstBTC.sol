// SPDX-License-Identifier: GPL-3.0

/* See contracts/COMPILERS.md */
pragma solidity ^0.8.0;

import "../openzeppelin-contracts/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "./interfaces/IStBTC.sol";

/**
 * @title StBTC token wrapper with static balances.
 * @dev It's an ERC20 token that represents the account's share of the total
 * supply of stBTC tokens. WstBTC token's balance only changes on transfers,
 * unlike StBTC that is also changed when oracles report staking rewards and
 * penalties. It's a "power user" token for DeFi protocols which don't
 * support rebasable tokens.
 *
 * The contract is also a trustless wrapper that accepts stBTC tokens and mints
 * wstBTC in return. Then the user unwraps, the contract burns user's wstBTC
 * and sends user locked stBTC in return.
 *
 * The contract provides the staking shortcut: user can send BTC with regular
 * transfer and get wstBTC in return. The contract will send BTC to Lido submit
 * method, staking it and wrapping the received stBTC.
 *
 */
contract WstBTC is ERC20Permit {
    IStBTC public stBTC;

    /**
     * @param _stBTC address of the StBTC token to wrap
     */
    constructor(IStBTC _stBTC)
        public
        ERC20Permit("Wrapped liquid staked Btc 2.0")
        ERC20("Wrapped liquid staked Btc 2.0", "wstBTC")
    {
        stBTC = _stBTC;
    }

    /**
     * @notice Exchanges stBTC to wstBTC
     * @param _stBTCAmount amount of stBTC to wrap in exchange for wstBTC
     * @dev Requirements:
     *  - `_stBTCAmount` must be non-zero
     *  - msg.sender must approve at least `_stBTCAmount` stBTC to this
     *    contract.
     *  - msg.sender must have at least `_stBTCAmount` of stBTC.
     * User should first approve _stBTCAmount to the WstBTC contract
     * @return Amount of wstBTC user receives after wrap
     */
    function wrap(uint256 _stBTCAmount) external returns (uint256) {
        require(_stBTCAmount > 0, "wstBTC: can't wrap zero stBTC");
        uint256 wstBTCAmount = stBTC.getSharesByPooledBtc(_stBTCAmount);
        _mint(msg.sender, wstBTCAmount);
        stBTC.transferFrom(msg.sender, address(this), _stBTCAmount);
        return wstBTCAmount;
    }

    /**
     * @notice Exchanges wstBTC to stBTC
     * @param _wstBTCAmount amount of wstBTC to uwrap in exchange for stBTC
     * @dev Requirements:
     *  - `_wstBTCAmount` must be non-zero
     *  - msg.sender must have at least `_wstBTCAmount` wstBTC.
     * @return Amount of stBTC user receives after unwrap
     */
    function unwrap(uint256 _wstBTCAmount) external returns (uint256) {
        require(_wstBTCAmount > 0, "wstBTC: zero amount unwrap not allowed");
        uint256 stBTCAmount = stBTC.getPooledBtcByShares(_wstBTCAmount);
        _burn(msg.sender, _wstBTCAmount);
        stBTC.transfer(msg.sender, stBTCAmount);
        return stBTCAmount;
    }

    /**
     * @notice Shortcut to stake BTC and auto-wrap returned stBTC
     */
    receive() external payable {
        uint256 shares = stBTC.stake{value: msg.value}(address(0));
        _mint(msg.sender, shares);
    }

    /**
     * @notice Get amount of wstBTC for a given amount of stBTC
     * @param _stBTCAmount amount of stBTC
     * @return Amount of wstBTC for a given stBTC amount
     */
    function getWstBTCByStBTC(uint256 _stBTCAmount)
        external
        view
        returns (uint256)
    {
        return stBTC.getSharesByPooledBtc(_stBTCAmount);
    }

    /**
     * @notice Get amount of stBTC for a given amount of wstBTC
     * @param _wstBTCAmount amount of wstBTC
     * @return Amount of stBTC for a given wstBTC amount
     */
    function getStBTCByWstBTC(uint256 _wstBTCAmount)
        external
        view
        returns (uint256)
    {
        return stBTC.getPooledBtcByShares(_wstBTCAmount);
    }

    /**
     * @notice Get amount of stBTC for a one wstBTC
     * @return Amount of stBTC for 1 wstBTC
     */
    function stBtcPerToken() external view returns (uint256) {
        return stBTC.getPooledBtcByShares(1 ether);
    }

    /**
     * @notice Get amount of wstBTC for a one stBTC
     * @return Amount of wstBTC for a 1 stBTC
     */
    function tokensPerStBtc() external view returns (uint256) {
        return stBTC.getSharesByPooledBtc(1 ether);
    }
}
