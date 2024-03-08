// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./common/UnstructuredStorage.sol";
import "./common/Math256.sol";
import "../openzeppelin-contracts/contracts/access/Ownable.sol";
import "../openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

import "./StBTCPermit.sol";

/**
 * @title Liquid staking pool implementation
 *
 * Bido is an BEVM liquid staking protocol
 */
contract Bido is StBTCPermit, Ownable {
    using UnstructuredStorage for bytes32;
    using SafeMath for uint256;

    uint256 public constant MAX_INT = type(uint256).max;

    // storage slot position for the Bido protocol contracts paused
    bytes32 internal constant BIDO_PAUSED_POSITION =
        0x84f95e6c19b0228c43737080e7d42c25c8e65dbeaa3c220ab8f695c78772ac57; // keccak256("bido.Bido.paused")

    // Staking was paused (don't accept user's btc stakes)
    event StakingPaused();
    // Staking was resumed (accept user's btc stakes)
    event StakingResumed();

    // Records a stake made by a user
    event Staked(address indexed sender, uint256 amount, address referral);

    // Records a unstake made by a user
    event UnStaked(address indexed sender, uint256 amount);

    /**
     * The contract's balance must be non-zero to allow initial holder bootstrap.
     */
    function initialize() public payable onlyOwner {
        _bootstrapInitialHolder();
    }

    /**
     * @notice Stops accepting new Btc to the protocol
     *
     * @dev While accepting new Btc is stopped, calls to the `stake` function,
     * as well as to the default payable function, will revert.
     *
     * Emits `StakingPaused` event.
     */
    function pauseStaking() external onlyOwner {
        _pauseStaking();
    }

    /**
     * @notice Resumes accepting new Btc to the protocol (if `pauseStaking` was called previously)
     * NB: Staking could be rate-limited by imposing a limit on the stake amount
     * at each moment in time, see `setStakingLimit()` and `removeStakingLimit()`
     *
     * @dev Preserves staking limit if it was set previously
     *
     * Emits `StakingResumed` event
     */
    function resumeStaking() external onlyOwner {
        _resumeStaking();
    }

    /**
     * @notice Check staking state: whbtc it's paused or not
     */
    function isStakingPaused() external view returns (bool) {
        return BIDO_PAUSED_POSITION.getStorageBool();
    }

    /**
     * @notice Stop pool routine operations
     */
    function stop() external onlyOwner {
        _pause();
        _pauseStaking();
    }

    /**
     * @notice Resume pool routine operations
     * @dev Staking is resumed after this call using the previously set limits (if any)
     */
    function resume() external onlyOwner {
        _unpause();
        _resumeStaking();
    }

    // solhint-disable-next-line no-complex-fallback
    fallback() external payable {
        // protection against accidental submissions by calling non-existent function
        revert("NON_EMPTY_DATA");
    }

    /**
     * @notice Send funds to the pool
     */
    // solhint-disable-next-line no-complex-fallback
    receive() external payable {
        // protection against accidental submissions by calling non-existent function
        _stake(address(0));
    }

    /**
     * @notice Send funds to the pool with optional _referral parameter
     * @dev This function is alternative way to stake funds. Supports optional referral address.
     * @return Amount of StBTC shares generated
     */
    function stake(address _referral) external payable returns (uint256) {
        return _stake(_referral);
    }

    /**
     * @notice Process user unstake, burns liquid tokens
     */
    function unstake(uint256 _amount) external {
        _unstake(_amount);
    }

    /**
     * @dev Process user stake, mints liquid tokens
     * @param _referral address of referral.
     * @return amount of StBTC shares generated
     */
    function _stake(address _referral) internal returns (uint256) {
        require(_sharesOf(INITIAL_TOKEN_HOLDER) != 0, "NOT_INITIALIZED");
        require(msg.value != 0, "ZERO_DEPOSIT");

        require(!BIDO_PAUSED_POSITION.getStorageBool(), "STAKING_PAUSED");

        uint256 totalPooledBtc = _getTotalPooledBtc();
        require(totalPooledBtc > msg.value, "INVALID_VALUE");
        uint256 preTotalPooledBtc = totalPooledBtc.sub(msg.value);

        uint256 sharesAmount = msg.value.mul(_getTotalShares()).div(
            preTotalPooledBtc
        );

        _mintShares(msg.sender, sharesAmount);

        emit Staked(msg.sender, msg.value, _referral);

        _emitTransferAfterMintingShares(msg.sender, sharesAmount);
        return sharesAmount;
    }

    /**
     * @dev Process user unstake, burns liquid tokens
     */
    function _unstake(uint256 _amount) internal {
        require(!BIDO_PAUSED_POSITION.getStorageBool(), "STAKING_PAUSED");
        require(_amount > 0, "UNSTAKE_ZERO");

        uint256 sharesAmount;
        if (_amount == MAX_INT) {
            sharesAmount = _sharesOf(msg.sender);
        } else {
            sharesAmount = getSharesByPooledBtc(_amount);
        }

        require(sharesAmount > 0, "BURN_ZERO");

        (, uint256 preRebaseTokenAmount) = _burnShares(
            msg.sender,
            sharesAmount
        );

        _sendValue(msg.sender, preRebaseTokenAmount);

        emit UnStaked(msg.sender, msg.value);
    }

    /**
     * @dev Gets the total amount of Btc controlled by the system
     * @return total balance in wei
     */
    function _getTotalPooledBtc() internal view override returns (uint256) {
        return address(this).balance;
    }

    function _pauseStaking() internal {
        BIDO_PAUSED_POSITION.setStorageBool(true);
        emit StakingPaused();
    }

    function _resumeStaking() internal {
        BIDO_PAUSED_POSITION.setStorageBool(false);
        emit StakingResumed();
    }

    /**
     * @notice Mints shares on behalf of 0xdead address,
     * the shares amount is equal to the contract's balance.     *
     *
     * Allows to get rid of zero checks for `totalShares` and `totalPooledBtc`
     * and overcome corner cases.
     *
     * NB: reverts if the current contract's balance is zero.
     *
     * @dev must be invoked before using the token
     */
    function _bootstrapInitialHolder() internal {
        uint256 balance = address(this).balance;
        require(balance != 0, "ZERO_BALANCE");

        if (_getTotalShares() == 0) {
            // emitting `Staked` before Transfer events to preserver events order in tx
            emit Staked(INITIAL_TOKEN_HOLDER, balance, address(0));
            _mintInitialShares(balance);
        }
    }

    function _sendValue(address _recipient, uint256 _amount) internal {
        if (address(this).balance < _amount) revert("NOT_ENOUGH_BTC");

        // solhint-disable-next-line
        (bool success, ) = _recipient.call{value: _amount}("");
        if (!success) revert("CANT_SEND_VALUE");
    }
}
