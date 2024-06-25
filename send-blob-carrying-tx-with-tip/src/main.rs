#![allow(unused_imports)]
use alloy::{
    consensus::{SidecarBuilder, SimpleCoder},
    eips::eip4844::DATA_GAS_PER_BLOB,
    network::{EthereumWallet, TransactionBuilder},
    node_bindings::Anvil,
    primitives::{utils::Unit, U256},
    providers::{Provider, ProviderBuilder},
    rpc::types::TransactionRequest,
    signers::local::PrivateKeySigner,
    sol,
    sol_types::SolCall,
};
use eyre::Result;

sol! {
    #[sol(rpc)]
    BlobMiddleware,
    "artifact/BlobMiddleware.json"
}
sol! {
    function submitBlob(uint256 blobTip, uint256 blockNumber, address blockBuilder, uint256 deadline) external payable;
}

#[tokio::main]
async fn main() -> Result<()> {
    let anvil = Anvil::new().args(["--hardfork", "cancun"]).try_spawn()?;
    let signer: PrivateKeySigner = anvil.keys()[0].clone().into();
    let wallet = EthereumWallet::from(signer);

    let provider = ProviderBuilder::new()
        .with_recommended_fillers()
        .wallet(wallet)
        .on_builtin(&anvil.endpoint())
        .await?;

    let blob_middleware = BlobMiddleware::deploy(&provider).await?;
    let blob_middleware_addr = blob_middleware.address();

    let block_number = provider.get_block_number().await?;
    let _blob_sender = anvil.addresses()[0];
    let block_builder = anvil.addresses()[1];

    let sidecar: SidecarBuilder<SimpleCoder> = SidecarBuilder::from_slice(
        "Chancellor on the brink of second bailout for banks".as_bytes(),
    );
    let sidecar = sidecar.build()?;

    let calldata = BlobMiddleware::submitBlobCall {
        blobTip: Unit::ETHER.wei(),
        blockNumber: U256::from(block_number),
        blockBuilder: block_builder,
        deadline: U256::from(1),
    };

    let gas_price = provider.get_gas_price().await?;
    let eip1559_est = provider.estimate_eip1559_fees(None).await?;
    let tx = TransactionRequest::default()
        .with_to(*blob_middleware_addr)
        .with_nonce(1)
        .with_call(&calldata)
        .with_value(Unit::ETHER.wei())
        .with_max_fee_per_blob_gas(gas_price)
        .with_max_fee_per_gas(eip1559_est.max_fee_per_gas)
        .with_max_priority_fee_per_gas(eip1559_est.max_priority_fee_per_gas)
        .with_blob_sidecar(sidecar);

    let receipt = provider.send_transaction(tx).await?.get_receipt().await?;

    println!(
        "Transaction included in block {}",
        receipt.block_number.expect("Failed to get block number")
    );

    // assert_eq!(receipt.from, alice);
    // assert_eq!(receipt.to, Some(bob));
    // assert_eq!(
    //     receipt
    //         .blob_gas_used
    //         .expect("Expected to be EIP-4844 transaction"),
    //     DATA_GAS_PER_BLOB as u128
    // );

    Ok(())
}
