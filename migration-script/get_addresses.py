import sys
import warnings
import time
import os
import collections
from typing import List, Tuple
import requests
from web3 import Web3

LENT_MYC_ADDRESS = "0x9B225FF56C48671d4D04786De068Ed8b88b672d6"
# LENT_MYC_ADDRESS = "0x22753E4264FDDc6181dc7cce468904A80a363E44"
ETHERSCAN_API_KEY = os.getenv("ETHERSCAN_API_KEY")
PRIVATE_KEY = os.getenv("PRIVATE_KEY")
ACCOUNT = os.getenv("ACCOUNT")
DEFAULT_RPC = "https://arb1.arbitrum.io/rpc"
# DEFAULT_RPC = "http://127.0.0.1:8545"

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
    first_method = True
    addresses = []
    if first_method:
        increment = 18_000_000
        max_block = 50_000_000
        for i in range(0, max_block, increment):
            time.sleep(5)
            request = f"https://api.arbiscan.io/api?module=account&action=txlist&address={LENT_MYC_ADDRESS}&startblock={i}&endblock={i + increment}&sort=asc&apikey={ETHERSCAN_API_KEY}"
            response = requests.get(request)
            for tx in response.json()["result"]:
                addresses.append(w3.toChecksumAddress(tx["from"]))
    else:
        headers = {
            'Authorization': 'Basic Y2tleV9mNjY5MzViYWNhZTA0MmU3ODgxMzAwMjk4MGI6',
        }

        pages = 4
        for i in range(0, pages):
            response = requests.get('https://api.covalenthq.com/v1/42161/tokens/0x9B225FF56C48671d4D04786De068Ed8b88b672d6/token_holders/?quote-currency=USD&format=JSON&page-number={i}&block-height=latest&page-size=100&key=ckey_7a1ed71b2b294e33bd1bd49e7c4')
            for item in (response.json()["data"]["items"]):
                addresses.append(Web3.toChecksumAddress(item["address"]))

    time.sleep(10)


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
    },
        {
      "inputs": [
        {
          "internalType": "address",
          "name": "",
          "type": "address"
        }
      ],
      "name": "hasMigrated",
      "outputs": [
        {
          "internalType": "bool",
          "name": "",
          "type": "bool"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
        {
      "inputs": [
        {
          "internalType": "address",
          "name": "user",
          "type": "address"
        }
      ],
      "name": "trueBalanceOf",
      "outputs": [
        {
          "internalType": "uint256",
          "name": "",
          "type": "uint256"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    }]"""
    contract = w3.eth.contract(address=LENT_MYC_ADDRESS, abi=_abi)

    warnings.simplefilter("ignore")
    i = 0

    new_addresses = []
    no_migrate = []
    with open("no_migrate.csv", 'r') as f:
        for address in f.readlines():
            no_migrate.append(address.rstrip())

    with open("no_migrate.csv", 'a') as f:
        for address in addresses:
            address = Web3.toChecksumAddress(address.lower())
            i+= 1
            if address in no_migrate:
                continue
            hasMigrated = contract.functions.hasMigrated(address).call()
            has0TrueBalance = contract.functions.trueBalanceOf(address).call()
            
            if has0TrueBalance == 0 or hasMigrated or address.lower() == LENT_MYC_ADDRESS.lower():
                f.write(address + "\n")
                continue

            new_addresses.append(address)
            if (len(new_addresses) >= 30):
                tx = contract.functions.multiMigrate(new_addresses).buildTransaction(tx_skeleton(w3, ACCOUNT))
                print(f"Submitting TX: \n{tx}")
                time.sleep(5)
                print("")
                print("")
                print(tx)
                send_and_process_tx(w3, tx)
                time.sleep(1)
                with open("migrated.csv", 'a') as f2:
                    for elem in new_addresses:
                        f2.write(str(elem) + "\n")
                new_addresses = []
    
    if len(new_addresses) > 0:
        tx = contract.functions.multiMigrate(new_addresses).buildTransaction(tx_skeleton(w3, ACCOUNT))
        print(f"Submitting TX: \n{tx}")
        print("")
        print("")
        print(tx)
        send_and_process_tx(w3, tx)
    sys.exit()


if __name__ == "__main__":
    main()