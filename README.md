# Cronos to Crypto.org Chain ICA Demo

This repository demonstrates sending ICA message from smart contract running on Cronos EVM to Crypto.org Chain.

It uses the precompile feature on Ethermint to enable smart contract interacting with Cosmos layer and uses the ICA middleware for contract notification via calling the callback methods. You can refer to the example contracts in [./hardhat/contracts](./hardhat/contracts/) folder for more details.

## WARNING

All the mnemonics and private keys used in this repository are considered NOT SAFE. Never use them other than this repository or you may lost your funds.

## Pre-requisite

### Clone the projects and build binary locally

```
make init
make build
```

## Staking contract example

### 1. Start the network
```
make start-network
```

### 2. Load Cronos Devnet wallets to MetaMask

#### Wallet 1

> Mnemonics: banner spread envelope side kite person disagree path silver will brother under couch edit food venture squirrel civil budget number acquire point work mass
> HD Path: m/44'/60'/0'/0/0
> Address: 0xCdEf4A3e3350EE111f2c48030ee956483143E288
> Public Key: 0x02f9373eb5a88fc021539e8f35d53cbd8d2abf5cbd399e9a77459857bae5050235
> Private Key: 0xd5b31e2d217cdf224aa8ec8603125b91b4cf45939d4ec78ed4f33b81ea7fdea0

Refer to [./network/wallets.md](./network/wallets.md) for wallet details.

### 3. Deploy Staking contract using Remix

1. Open https://remix.ethereum.org/
1. Load the contract `./hardhat/contracts/Staking.sol`
1. Deploy with Wallet 1 with the following constructor arguments:
    - CONNECTIONID_: `connection-0`
    - VALIDATORADDRESS_: `tcrocncl1qrcgju2vdr9w3hfh072g73khnzprfw9akrh75g`
    - BASECROREWARDRATE_: `10`

### 4. Finish Staking contract setup

On Remix, wait for 1 minute and call the method `setup` with owner account. This method will revert if the Staking contract Interchain account is not registered yet.

### 5. Query Staking contract Interchain Account

If the last step is successful, the contract should now be associated with an account.

On Remix, call the view method `getInterchainAccount` and you should see an `tcro`-prefixed address.

### 6. Funds the Staking contract and Interchain Account

1. On MetaMask, send 10000TCRO to the Staking contract
1. On Remix, verify the contract has the balance by calling the view method `balance`
1. Run the following command, replace `${INTERCHAIN_ACCOUNT}` with the result from last step

    ```bash
    ./cryptoorgchain/chain-maind --home=./data/cryptoorgchaindevnet-2 \
        tx bank send \
        tcro1yademsjml2m7zsjrn6hpwkug9eqv76k5dexhps \
        ${INTERCHAIN_ACCOUNT} \
        100tcro \
        --keyring-backend=test \
        --chain-id=cryptoorgchaindevnet-2 -y
    ```

1. Verify the Staking contract Interchain Account has the balance by running

    ```bash
    ./cryptoorgchain/chain-maind --node=http://127.0.0.1:26657 \
        query bank balances ${INTERCHAIN_ACCOUNT}
    ```

### 7. User registers

1. Send 10TCRO a new Cronos wallet (named it User Wallet) with MetaMask.
1. On Remix, call the view method `queryInterchainAccount` with User Wallet address. It should return an empty string.
1. On Remix, use the User Wallet to call the method `registerInterchainAccount`
1. On Remix, call the view method `queryInterchainAccount` with User Wallet address. It should now return the User Wallet Interchain account

### 8. User stakes

1. Query the validator delegations before user stake by running

    ```
    ./cryptoorgchain/chain-maind --node=http://127.0.0.1:26657 \
        query staking delegations-to tcrocncl1qrcgju2vdr9w3hfh072g73khnzprfw9akrh75g
    ```

1. Send 10TCRO a new Cronos wallet (named it User Wallet) with MetaMask
1. On Remix, use the User Wallet to call the method `stake` with the 1TCRO 
1. Wait for 1 minute, query the validator delegations again. You should see the contract Interchan account has delegated 1TCRO

    ```
    ./cryptoorgchain/chain-maind --node=http://127.0.0.1:26657 \
        query staking delegations-to tcrocncl1qrcgju2vdr9w3hfh072g73khnzprfw9akrh75g
    ```
1. On Remix, call the view method `stakeOf` with the User Wallet address. You should see 1TCRO. You can also play around other view methods.

### 9. User unstakes

1. On Remix, use the User Wallet to call the method `unstake` with the argument
    - uint256 amount: `100000000000000000` (0.1TCRO)
1. You should see the User Wallet is credited with 0.1TCRO + reward. The reward follows the simple interest formula: `Stake Amount * Reward Rate / 100 * (Current Block Height - Stake Height)`

## Contract development environment

### Install

```bash
cd hardhat
npm i
```

### Watch and auto-compile contract

```bash
npx hardhat watch compile
```


## Makefile Reference

### Start the network
```
make init-network
make start-network
```

### Stop and resume network

```
make stop-all
make start-all
```

### Clean the network and remove all data

All data will be gone. Please run it with caution.
```
make unsafe-clean-all
```

### License

This repository is under [MIT License](./LICENSE)