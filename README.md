# STX-Bitcoin-Backed Stablecoins Smart Contract

This project implements a decentralized system for issuing stablecoins backed by Bitcoin (BTC) using the **Stacks blockchain**. The smart contracts enable minting, burning, and managing stablecoins while ensuring proper collateralization through dynamic BTC price updates from a trusted oracle. The system supports liquidation of under-collateralized positions, dynamic adjustment of collateralization ratios, and incentivizes users through interest accrual.

---

## **Key Features**

### 1. **Collateralized Stablecoin System**
- Users can lock Bitcoin collateral (BTC) to mint stablecoins.
- Stablecoins are backed by BTC at a dynamically adjustable collateralization ratio (`min-collateral-ratio`).

### 2. **Dynamic Collateralization Ratio**
- Administrators can adjust the minimum collateral ratio (`min-collateral-ratio`) as needed to adapt to changing market conditions.

### 3. **BTC Price Oracle**
- BTC prices are sourced via a decentralized price oracle, updated by authorized reporters.
- Prices are aggregated and validated before being used in the system.

### 4. **Liquidation**
- Under-collateralized positions can be liquidated to maintain system stability.

### 5. **Interest Mechanism**
- Users holding stablecoins earn interest based on their balances.
- Interest is periodically distributed and can be claimed by users.

### 6. **System Pause**
- The system can be paused by the administrator to respond to emergencies, halting operations like minting and burning.

---

## **Contracts Overview**

### 1. **STX-Bitcoin-Backed Stablecoin Contract**

#### **Constants**
- **`min-collateral-ratio`**: The minimum BTC collateral required to mint stablecoins, adjustable by the admin.
- **`admin`**: The designated administrator of the system.

#### **Data Storage**
- **`collateral-map`**: Tracks the BTC collateral locked by each user.
- **`stablecoin-balance`**: Tracks the stablecoin balance of each user.
- **`interest-earned`**: Stores interest accrued by users.
- **`system-paused`**: A flag to halt operations in emergencies.

#### **Key Public Functions**
- **`lock-collateral(btc-amount)`**:
  Users lock BTC collateral to back their stablecoins.

- **`mint-stablecoin(amount)`**:
  Mint new stablecoins if the user's collateral is sufficient.

- **`burn-stablecoin(amount)`**:
  Burn stablecoins to unlock corresponding BTC collateral.

- **`withdraw-collateral(btc-amount)`**:
  Withdraw excess collateral if the user's position is over-collateralized.

- **`liquidate(user)`**:
  Liquidate under-collateralized positions.

- **`adjust-collateral-ratio(new-ratio)`**:
  Admin function to dynamically adjust the minimum collateral ratio.

- **`pause-system()`** / **`unpause-system()`**:
  Admin functions to pause/unpause the system.

- **`claim-interest()`**:
  Users claim accrued interest on their stablecoin balances.

#### **Read-Only Functions**
- **`get-collateral(user)`**:
  Get the locked BTC collateral of a user.

- **`get-stablecoin-balance(user)`**:
  Get the stablecoin balance of a user.

- **`check-collateral-ratio(user)`**:
  Check the collateralization ratio of a user's position.

- **`is-collateral-sufficient(user, mint-amount)`**:
  Validate if the user's collateral is sufficient to mint stablecoins.

- **`is-paused()`**:
  Check if the system is paused.

---

### 2. **BTC Price Oracle Contract**

#### **Constants**
- **`max-stale-blocks`**: Maximum allowable age for BTC price data before it is considered stale.
- **`admin`**: The administrator of the oracle system.

#### **Data Storage**
- **`btc-price`**: The current BTC price in USD.
- **`last-updated-block`**: The last block when the BTC price was updated.
- **`manual-block-height`**: A manually incremented block counter.
- **`reporter-whitelist`**: Tracks authorized reporters for the oracle.
- **`price-submissions`**: Stores BTC price submissions from reporters.
- **`price-list`**: A list to aggregate all submitted BTC prices.

#### **Key Public Functions**
- **`increment-block-height()`**:
  Manually increment the block counter.

- **`add-reporter(reporter)`** / **`remove-reporter(reporter)`**:
  Admin functions to manage the whitelist of authorized reporters.

- **`submit-price(price)`**:
  Authorized reporters submit BTC price data.

- **`update-btc-price()`**:
  Aggregate prices and update the official BTC price.

#### **Read-Only Functions**
- **`get-price()`**:
  Get the current BTC price.

- **`get-last-updated-block()`**:
  Get the last block height when the BTC price was updated.

- **`is-price-stale()`**:
  Check if the BTC price data is stale.

---

## **Key Workflows**

### **1. Minting Stablecoins**
1. Users lock BTC collateral using `lock-collateral`.
2. The system verifies that the collateralization ratio is sufficient using `is-collateral-sufficient`.
3. Users mint stablecoins using `mint-stablecoin`.

### **2. Burning Stablecoins**
1. Users burn stablecoins using `burn-stablecoin`.
2. The system unlocks the equivalent BTC collateral based on the current BTC price.

### **3. Liquidation**
1. Any user can call `liquidate` on under-collateralized positions.
2. The system seizes and deletes the user’s collateral and stablecoin balances.

### **4. Interest Accrual**
1. The admin periodically calls a script (off-chain) to distribute interest using `distribute-interest`.
2. Users claim their interest using `claim-interest`.

---

## **Admin Capabilities**
- Adjust the collateral ratio dynamically.
- Pause or unpause the system in emergencies.
- Manage the whitelist of oracle reporters.
- Submit and update BTC price data.

---

## **Security Features**
1. **Collateralization Ratio Enforcement**:
   - Ensures positions remain over-collateralized to protect against volatility.

2. **Liquidation**:
   - Removes under-collateralized positions to maintain system solvency.

3. **Oracle Whitelisting**:
   - Restricts BTC price submissions to trusted reporters.

4. **System Pause**:
   - Allows the admin to halt minting and burning operations in emergencies.

5. **Data Integrity**:
   - Validates BTC prices and ensures data is not stale.

---

## **Deployment Guide**
1. Deploy the `price-oracle` contract.
2. Deploy the `stx-bitcoin-backed-stablecoins` contract with the oracle's contract address set in `get-btc-price`.
3. Add reporters to the whitelist using `add-reporter`.
4. Begin submitting BTC price data through authorized reporters.
5. Users can lock collateral and mint stablecoins once the system is operational.

---

## **Future Improvements**
1. **DAO Governance**:
   - Transition admin rights to a decentralized autonomous organization (DAO).

2. **Dynamic Oracle Integration**:
   - Allow integration with multiple oracles for improved price reliability.

3. **Multi-Collateral Support**:
   - Expand the system to support other collateral types.

4. **Automated Interest Distribution**:
   - Implement automated scripts for distributing interest on-chain.