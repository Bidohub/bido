from pathlib import Path

from brownie import network, project, accounts, config
from brownie.network.account import Account


def get_account() -> Account:
    acc = accounts.add(config["wallets"]["from_key"])
    print(f"Load acc:{acc.address}")
    return acc


def change_network(dst_net):
    if network.show_active() == dst_net:
        return
    if network.is_connected():
        network.disconnect()
    network.connect(dst_net)


def load_project(net="bevm-test"):
    p = project.load(project_path=Path(__file__).parent.parent.parent, raise_if_loaded=False)
    p.load_config()
    change_network(net)
    return p


def main(net="bevm-test"):
    p = load_project(net)
    p["Bido"].deploy({"from": get_account()})

    p["WstBTC"].deploy(p["Bido"][-1].address, {"from": get_account()})

    p["Bido"][-1].initialize({'from': get_account(), "value": 0.00001 * 1e18})

    # GG
    p["Bido"][-1].transferOwnership("0x209867e6430D75D0Aff27E217A6a51580Ef4C31e", {"from": get_account()})


if __name__ == "__main__":
    main("bevm-main")
