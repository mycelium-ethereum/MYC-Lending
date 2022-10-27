import sys
import warnings
import time
import os
import collections
from typing import List, Tuple
import requests
from web3 import Web3

# LENT_MYC_ADDRESS = "0x9B225FF56C48671d4D04786De068Ed8b88b672d6"
LENT_MYC_ADDRESS = "0x22753E4264FDDc6181dc7cce468904A80a363E44"
ETHERSCAN_API_KEY = os.getenv("ETHERSCAN_API_KEY")
PRIVATE_KEY = os.getenv("PRIVATE_KEY")
ACCOUNT = os.getenv("ACCOUNT")
# DEFAULT_RPC = "https://arb1.arbitrum.io/rpc"
DEFAULT_RPC = "http://127.0.0.1:8545"

def tx_skeleton(w3, wallet_address):
    nonce = w3.eth.getTransactionCount(wallet_address)
    tx_data = {
        'nonce': nonce,
        'gas': 12500000,
    }
    return tx_data

def send_and_process_tx(w3, tx):
    signed_tx = w3.eth.account.signTransaction(tx, private_key=PRIVATE_KEY)
    w3.eth.sendRawTransaction(signed_tx.rawTransaction)
    print(f"Transaction hash: {signed_tx.hash.hex()}")
    print(f"Waiting for receipt")
    w3.eth.wait_for_transaction_receipt(signed_tx.hash, timeout=120)

def main():
    w3 = Web3(Web3.HTTPProvider(DEFAULT_RPC))
    """
    request = f"https://api.arbiscan.io/api?module=account&action=txlist&address={LENT_MYC_ADDRESS}&startblock=0&endblock=9999999999&sort=asc&apikey={ETHERSCAN_API_KEY}"
    response = requests.get(request)
    print(len(response.json()['result']))
    addresses = []
    for tx in response.json()["result"]:
        if w3.toChecksumAddress(tx["from"]) not in addresses:
            addresses.append(w3.toChecksumAddress(tx["from"]))
    print(f"Addresses: {addresses[0:40]}")

    """
    _abi = """[    {
      "inputs": [
        {
          "internalType": "address[]",
          "name": "_users",
          "type": "address[]"
        }
      ],
      "name": "multiMigrate",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    }]"""
    print(_abi)
    contract = w3.eth.contract(address=LENT_MYC_ADDRESS, abi=_abi)
    # addresses = [Web3.toChecksumAddress("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266".lower())]
    addresses = ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"]
    ACCOUNT = Web3.toChecksumAddress("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266".lower())
    print(addresses)

    warnings.simplefilter("ignore")
    i = 0
    while i < len(addresses):
        tx = contract.functions.multiMigrate(addresses[i:min(i + 30, len(addresses))]).buildTransaction(tx_skeleton(w3, ACCOUNT))
        print(f"Submitting TX: \n{tx}")

        print("")
        print("")
        print(tx)
        send_and_process_tx(w3, tx)
        time.sleep(5)
        i += 30


if __name__ == "__main__":
    main()