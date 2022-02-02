from unicodedata import decimal
from brownie import accounts, network, config, MockV3Aggregator, Contract
from web3 import Web3

FORKED_LOCAL_ENVIRONMENTS = ["mainnet-fork", "mainnet-fork-dev"]
LOCAL_BLOCKCHAIN_ENVIRONMENTS = ["development", "ganache-local"]

DECIMALS = 8
STARTING_PRICE = 200000000000

# based on the type of environment, will pull in the appropriate accounts


def get_account(index=None, id=None):
    if index:
        return accounts[index]
    if id:
        return accounts.load(id)
    if (
        network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS
        or network.show_active() in FORKED_LOCAL_ENVIRONMENTS
    ):
        return accounts[0]
    return accounts.add(config["wallets"]["from_key"])


contract_to_mock = {
    "eth_usd_price_feed": MockV3Aggregator
}


def get_contract(contract_name):
    """This function will grab the contract addresses from the brownie config if defined. Otherwise, it will deploy a mock
    version of that contract and return that mock contract. 

    Args: 
        contract_name(string)
    Returns: 
        brownie.network.contract.ProjectContract: The most recently deployed version of this contract  
    """
    # from the name, we get the type of contract it is. to do this we need a mapping of contract names to type (see "map")
    contract_type = contract_to_mock(contract_name)
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        if len(contract_type) <= 0:
            deploy_mocks()
        contract = contract_type[-1]
    else:
        contract_address = config["networks"][network.show_active(
        )][contract_name]
        contract = Contract.from_abi(
            contract_type._name, contract_address, contract_type.abi)
    return contract


def deploy_mocks(decimals=DECIMALS, starting_price=STARTING_PRICE):
    account = get_account()
    MockV3Aggregator.deploy(decimals, starting_price, {"from": account})
    print("Deployed Mocks")

# DONT FORGET TO ADD IN YAML AND CREATE .env
# dotenv: .env
# wallets:
#  from_key: ${PRIVATE_KEY}

# .env
# export PRIVATE_KEY=
# export WEB3_INFURA_PROJECT_ID=
# export ETHERSCAN_TOKEN=
