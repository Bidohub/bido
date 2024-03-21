from brownie import MockBido, accounts, reverts
from pytest import fixture

ZERO_ADDR = "0x0000000000000000000000000000000000000000"
DEAD_ADDR = "0x000000000000000000000000000000000000dead"
MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935


@fixture
def mock_bido():
    return MockBido.deploy({'from': accounts[0]})


def test_stake(mock_bido):
    # Account0 stake when not initialize
    with reverts("NOT_INITIALIZED"):
        mock_bido.stake(ZERO_ADDR, {'from': accounts[0], "value": 0.15 * 1e18})

    # Account0 initialize
    mock_bido.initialize({'from': accounts[0], "value": 0.1 * 1e18})
    assert mock_bido.sharesOf(DEAD_ADDR) == 0.1 * 1e18
    assert mock_bido.getTotalShares() == 0.1 * 1e18

    # Account0 stake
    mock_bido.stake(ZERO_ADDR, {'from': accounts[0], "value": 0.15 * 1e18})
    assert mock_bido.sharesOf(accounts[0].address) == 0.15 * 1e18

    with reverts("BALANCE_EXCEEDED"):
        mock_bido.unstake(0.2 * 1e18, {'from': accounts[0]})

    # Account0 unstake
    before_balance = accounts[0].balance()
    result = mock_bido.unstake(0.1 * 1e18, {'from': accounts[0]})
    gas_fee = result.gas_used * result.gas_price
    after_balance = accounts[0].balance()
    assert after_balance == before_balance - gas_fee + 0.1 * 1e18

    # Account0 unstake all
    before_balance = accounts[0].balance()
    result = mock_bido.unstake(MAX_INT, {'from': accounts[0]})
    gas_fee = result.gas_used * result.gas_price
    after_balance = accounts[0].balance()
    assert after_balance == before_balance - gas_fee + 0.05 * 1e18

    # Account0 unstake zero
    with reverts("BURN_ZERO"):
        mock_bido.unstake(MAX_INT, {'from': accounts[0]})

    # Account0 stake
    mock_bido.stake(ZERO_ADDR, {'from': accounts[0], "value": 0.1 * 1e18})
    assert mock_bido.sharesOf(accounts[0].address) == 0.1 * 1e18

    # Account1 stake
    mock_bido.stake(ZERO_ADDR, {'from': accounts[1], "value": 0.15 * 1e18})
    assert mock_bido.sharesOf(accounts[1].address) == 0.15 * 1e18

    # Account2 stake by transfer
    accounts[2].transfer(mock_bido.address, 0.23 * 1e18)
    assert mock_bido.sharesOf(accounts[2].address) == 0.23 * 1e18

    # Account2 stake by transfer with data
    with reverts("NON_EMPTY_DATA"):
        accounts[2].transfer(mock_bido.address, 0.23 * 1e18, data="0x1234")

    # Check total supply
    total_deposit = (0.1 + 0.1 + 0.15 + 0.23) * 1e18
    assert mock_bido.totalSupply() == total_deposit

    # Simulate BTC transaction fees distributed to stakers
    mock_bido.distributeReward({'from': accounts[2], "value": 0.18 * 1e18})
    total_deposit_with_reward = total_deposit + 0.18 * 1e18

    # Account1 unstake with transaction fee reward
    before_balance = accounts[1].balance()
    result = mock_bido.unstake(MAX_INT, {'from': accounts[1]})
    gas_fee = result.gas_used * result.gas_price
    after_balance = accounts[1].balance()
    expect_balance = before_balance - gas_fee + 0.15 * 1e18 * total_deposit_with_reward / total_deposit
    assert abs(after_balance - expect_balance) <= 1e-14 * 1e18

    # Pause stake
    mock_bido.pauseStaking({'from': accounts[0]})
    with reverts("STAKING_PAUSED"):
        mock_bido.stake(ZERO_ADDR, {'from': accounts[3], "value": 0.11 * 1e18})
    mock_bido.resumeStaking({'from': accounts[0]})

    # Account3 stake
    mock_bido.stake(ZERO_ADDR, {'from': accounts[3], "value": 0.11 * 1e18})

    # Account2 unstake with transaction fee reward
    before_balance = accounts[2].balance()
    result = mock_bido.unstake(MAX_INT, {'from': accounts[2]})
    gas_fee = result.gas_used * result.gas_price
    after_balance = accounts[2].balance()
    expect_balance = before_balance - gas_fee + 0.23 * 1e18 * total_deposit_with_reward / total_deposit
    assert abs(after_balance - expect_balance) <= 1e-14 * 1e18

    # Stop transfer
    mock_bido.stop({'from': accounts[0]})
    with reverts("Pausable: paused"):
        mock_bido.transfer(accounts[4].address, 0.05 * 1e18, {"from": accounts[3]})
    mock_bido.resume({'from': accounts[0]})

    # Account3 transfer
    mock_bido.transfer(accounts[4].address, 0.05 * 1e18, {"from": accounts[3]})

    # Account3 unstake without transaction fee reward
    before_balance = accounts[3].balance()
    result = mock_bido.unstake(MAX_INT, {'from': accounts[3]})
    gas_fee = result.gas_used * result.gas_price
    after_balance = accounts[3].balance()
    expect_balance = before_balance - gas_fee + 0.06 * 1e18
    assert abs(after_balance - expect_balance) <= 1e-14 * 1e18

    # Account4 unstake without transaction fee reward
    before_balance = accounts[4].balance()
    result = mock_bido.unstake(MAX_INT, {'from': accounts[4]})
    gas_fee = result.gas_used * result.gas_price
    after_balance = accounts[4].balance()
    expect_balance = before_balance - gas_fee + 0.05 * 1e18
    assert abs(after_balance - expect_balance) <= 1e-14 * 1e18
