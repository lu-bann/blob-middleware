
# BlobMiddleware

🚧 WARNING 🚧  

This project is currently experimental. 

It has not been audited for security purposes and should not be used in production.

## Problem

Recent blob fee surges after the Dencun upgrade, one caused by ["blobscription"](https://blockworks.co/news/ethereum-blob-base-fee-surges) and the other likely due to the [Layer Zero airdrop on Arbitrum](https://blockworks.co/news/ethereum-blob-base-fee-surges), revealed a problem with the current blob gas market.

- Currently, blobs do not have their own tip field like traditional 1559 transactions' priority fees. As such, blob submitters have to rely on execution `priorityFee` to express blob inclusion contention.
- Execution `priorityFee` is charged ex post in the sense that only the gas actually consumed is charged. For example, a transaction has 1 blob, sets max gas to 1,000,000, and a priority fee of 100 GWei. A builder would expect to be paid a 100,000,000 GWei = 0.1 ETH tip. However, if the transaction only ends up using 100,000 gas, it will only pay a 0.01 ETH tip instead, regardless of blob counts. 
- Using execution tip as a blob tip requires block builders to simulate the transaction beforehand to know exactly how much they will get paid, increasing the overhead on top of the NP-hard block building algorithm they already have to run. Moreover, since [blobs increase the risk of reorg](https://ethresear.ch/t/blobs-reorgs-and-the-role-of-mev-boost/19783), block builders have minimal incentives to include them other than private dealings.

## Solutions

[Execution-Independent Priority Fee](https://notes.ethereum.org/@ansgar/execution-independent-priority-fee) is a proposal to separate the priority fee from the actual gas used by a transaction. This however would likely require a protocol-level change.
**[Ethereum consensus researcher Terence Tsao suggests having a blob tip for its own field](https://x.com/terencechain/status/1804518290871697735). In this repo, we designed a simple solution based on his idea.**

We propose a simple solution to address the issue - using the 4844 transaction's `value` field to specify blob tips. 

To make this possible, we introduce a single contract `BlobMiddleware`. The core function, `submitBlob`, is a `payable` function that takes in ETH transfers. The transferred ETH will be exactly the tip a blob submitter is willing to pay for the blob inclusion, independent of execution.

```solidity
function submitBlob(uint256 blobTip, uint256 blockNumber, address blockBuilder, uint256 deadline)
    external
    payable
{
    require(msg.value >= blobTip, "Insufficient blob tip");

    uint256 inclusionBlock = block.number;
    if (deadline > 0) {
        require(inclusionBlock <= blockNumber + deadline, "Exceeded deadline");
    } else {
        require(inclusionBlock == blockNumber, "Must be included at the specified block number");
    }

    blobTipLedger[blockBuilder] += blobTip;
    emit BlobSubmitted(msg.sender, blobTip, blockBuilder, blockNumber);
}
```

A blob submitter who wants to post the blob would send the same transaction with the same `nonce` to different block builders. This require specifying different `blockBuilder` addresses in the function call. A single transaction request would look like this:

```rust
let tx = TransactionRequest::default()
    .with_to(*blob_middleware_addr) // `BlobMiddleware` contract deployed address
    .with_call(&calldata) // transaction calldata
    .with_value(Unit::ETHER.wei()) // This is the blob tip
    .with_max_fee_per_blob_gas(gas_price)
    .with_max_fee_per_gas(eip1559_est.max_fee_per_gas)
    .with_max_priority_fee_per_gas(eip1559_est.max_priority_fee_per_gas)
    .with_blob_sidecar(sidecar); // blobs
```

Upon receiving the transaction, the block builder would perform three checks:
1. The `to` address is the `BlobMiddleware` contract's deployed address.
2. The `blockBuilder` address is the block builder's own address.
3. Check the length of the `blob_versioned_hashes` array and `value` to determine whether the tip meets the price the block builder is willing to offer for a given block according to their proprietary pricing algorithm.

Note: Step 2 above still requires the block builder to simulate the transaction, not for execution gas but for function input checking. A more computationally easy way is for every block builder to deploy their own version of `BlobMiddleware`. In that case, the block builder only needs to perform steps 1 and 3 above.

## This Repo

This repo includes:
1. A POC implementation of [`BlobMiddleware` contract](https://github.com/lu-bann/blob-middleware/blob/main/src/BlobMiddleware.sol).
2. A simple example to [send a transaction calling the `submitBlob` method](https://github.com/lu-bann/blob-middleware/blob/main/send-blob-carrying-tx-with-tip/src/main.rs).
