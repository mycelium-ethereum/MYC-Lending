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
        request = f"https://api.arbiscan.io/api?module=account&action=txlist&address={LENT_MYC_ADDRESS}&startblock=0&endblock=19345791&sort=asc&apikey={ETHERSCAN_API_KEY}"
        response = requests.get(request)
        print(len(response.json()['result']))
        print("hi")
        time.sleep(5)
        for tx in response.json()["result"]:
            # if w3.toChecksumAddress(tx["from"]) not in addresses:
                addresses.append(w3.toChecksumAddress(tx["from"]))
        request = f"https://api.arbiscan.io/api?module=account&action=txlist&address={LENT_MYC_ADDRESS}&startblock=19345791&endblock=29018687&sort=asc&apikey={ETHERSCAN_API_KEY}"
        response = requests.get(request)
        print(len(response.json()['result']))
        print("hi")
        time.sleep(5)
        for tx in response.json()["result"]:
            # if w3.toChecksumAddress(tx["from"]) not in addresses:
                addresses.append(w3.toChecksumAddress(tx["from"]))

        request = f"https://api.arbiscan.io/api?module=account&action=txlist&address={LENT_MYC_ADDRESS}&startblock=29018687&endblock=38691583&sort=asc&apikey={ETHERSCAN_API_KEY}"
        response = requests.get(request)
        print(len(response.json()['result']))
        print("hi")
        time.sleep(5)
        for tx in response.json()["result"]:
            # if w3.toChecksumAddress(tx["from"]) not in addresses:
                addresses.append(w3.toChecksumAddress(tx["from"]))

        request = f"https://api.arbiscan.io/api?module=account&action=txlist&address={LENT_MYC_ADDRESS}&startblock=38691583&endblock=999999999&sort=asc&apikey={ETHERSCAN_API_KEY}"
        response = requests.get(request)
        print(len(response.json()['result']))
        print("hi")
        time.sleep(5)
        for tx in response.json()["result"]:
            # if w3.toChecksumAddress(tx["from"]) not in addresses:
                addresses.append(w3.toChecksumAddress(tx["from"]))
    else:

        request  = f"https://api.etherscan.io/api?module=token&action=tokenholderlist&contractaddress={LENT_MYC_ADDRESS}&page=1&offset=10&apikey={ETHERSCAN_API_KEY}"
        response = requests.get(request)

        headers = {
            'Authorization': 'Basic Y2tleV9mNjY5MzViYWNhZTA0MmU3ODgxMzAwMjk4MGI6',
        }

        response = requests.get('https://api.covalenthq.com/v1/42161/tokens/0x9B225FF56C48671d4D04786De068Ed8b88b672d6/token_holders/?quote-currency=USD&format=JSON&page-number=0&block-height=latest&page-size=100&key=ckey_7a1ed71b2b294e33bd1bd49e7c4')
        for item in (response.json()["data"]["items"]):
            print(f"{item['address']} : {item['balance']}")
            addresses.append(Web3.toChecksumAddress(item["address"]))
        response = requests.get('https://api.covalenthq.com/v1/42161/tokens/0x9B225FF56C48671d4D04786De068Ed8b88b672d6/token_holders/?quote-currency=USD&format=JSON&page-number=1&block-height=latest&page-size=100&key=ckey_7a1ed71b2b294e33bd1bd49e7c4')
        for item in (response.json()["data"]["items"]):
            print(f"{item['address']} : {item['balance']}")
            addresses.append(Web3.toChecksumAddress(item["address"]))
        response = requests.get('https://api.covalenthq.com/v1/42161/tokens/0x9B225FF56C48671d4D04786De068Ed8b88b672d6/token_holders/?quote-currency=USD&format=JSON&page-number=2&block-height=latest&page-size=100&key=ckey_7a1ed71b2b294e33bd1bd49e7c4')
        for item in (response.json()["data"]["items"]):
            print(f"{item['address']} : {item['balance']}")
            addresses.append(Web3.toChecksumAddress(item["address"]))
        response = requests.get('https://api.covalenthq.com/v1/42161/tokens/0x9B225FF56C48671d4D04786De068Ed8b88b672d6/token_holders/?quote-currency=USD&format=JSON&page-number=3&block-height=latest&page-size=100&key=ckey_7a1ed71b2b294e33bd1bd49e7c4')
        for item in (response.json()["data"]["items"]):
            print(f"{item['address']} : {item['balance']}")
            addresses.append(Web3.toChecksumAddress(item["address"]))

    print(len(addresses))
    print(f"Addresses: {addresses[0:40]}")
    print("0x8714CB75d996FD0708e9ae14D31C1D82446527CD" in addresses)

    time.sleep(10)


    """
    print(len(response.json()['result']))
    for address in response.json()["result"]:
        print(address)
    for tx in response.json()["result"]:
        if w3.toChecksumAddress(tx["from"]) not in addresses:
            addresses.append(w3.toChecksumAddress(tx["from"]))
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
    # addresses = [Web3.toChecksumAddress("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266".lower())]
    # addresses = ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"]
    # ACCOUNT = Web3.toChecksumAddress("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266".lower())
    # print(addresses)
    # print(len(addresses))
    # print("0x4D1271Bf27901DfCB3Fe8D67C52C907B2BB7afcA" in addresses)
    # addresses = ["0xc2F78A17a2e6Fc26C112385c7bEF8991a335a7d6", "0x4D1271Bf27901DfCB3Fe8D67C52C907B2BB7afcA"]
    # addresses = ["0x4D1271Bf27901DfCB3Fe8D67C52C907B2BB7afcA"]

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
            print(i)
            if (address == "0x8714CB75d996FD0708e9ae14D31C1D82446527CD"):
                print("here")
            if address in no_migrate:
                if (address == "0x8714CB75d996FD0708e9ae14D31C1D82446527CD"):
                    print(1)
                continue
            hasMigrated = contract.functions.hasMigrated(address).call()
            has0TrueBalance = contract.functions.trueBalanceOf(address).call()
            
            if has0TrueBalance == 0 or hasMigrated or address.lower() == LENT_MYC_ADDRESS.lower():
                print(f"adding address {has0TrueBalance} {hasMigrated} {address}")
                f.write(address + "\n")
                if (address == "0x8714CB75d996FD0708e9ae14D31C1D82446527CD"):
                    print(2)
                continue

            new_addresses.append(address)
            print(new_addresses)
            print(f"Current Length: {len(new_addresses)}")
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

    i = 0

    with open("no_migrate.csv", 'r') as f:
        for line in f.readlines():
            line = line.rstrip()
            if line in addresses:
                print(f" Removing {line} from arr")
                addresses.remove(line)

    with open("addresses.csv", 'w') as f:
        for elem in addresses:
            f.write(str(elem) + "\n")

    print(addresses)

    print("Sleeping for 10 seconds")
    print(addresses[i:min(i + 30, len(addresses))])
    time.sleep(10)
    """


    while i < len(addresses):
        tx = contract.functions.multiMigrate(addresses[i:min(i + 30, len(addresses))]).buildTransaction(tx_skeleton(w3, ACCOUNT))
        print(f"Submitting TX: \n{tx}")

        print("")
        print("")
        print(tx)
        send_and_process_tx(w3, tx)
        time.sleep(5)
        with open("migrated.csv", 'a') as f:
            for elem in addresses[i:min(i + 30, len(addresses))]:
                f.write(str(elem) + "\n")
        i += 30
    """


if __name__ == "__main__":
    main()