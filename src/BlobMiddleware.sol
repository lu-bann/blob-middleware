// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title BlobMiddleware
 * @author da-bao-jian
 * @dev Contract to enable blob submitter to specify a tip per blob for the block builder
 */
contract BlobMiddleware {
    /**
     * @dev Emitted when a blob is submitted.
     * @param submitter The address of the submitter.
     * @param blobTip The tip provided per blob.
     * @param blockBuilder The address of the block builder.
     * @param blobNumber The block number the blob is associated with.
     */
    event BlobSubmitted(address indexed submitter, uint256 blobTip, address indexed blockBuilder, uint256 blobNumber);

    /**
     * @dev Emitted when a block builder is added.
     * @param blockBuilder The address of the block builder.
     */
    event BlockBuilderAdded(address indexed blockBuilder);

    /**
     * @dev Emitted when a block builder withdraws tips.
     * @param blockBuilder The address of the block builder.
     * @param amount The amount of tips withdrawn.
     */
    event Withdrawal(address indexed blockBuilder, uint256 amount);

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    /// @dev Mapping of block builders to their accumulated blob tips.
    mapping(address => uint256) public blobTipLedger;

    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice Submits multiple blobs with a tip per blob for the block builder.
     * @param blobTip The tip for blobs included in the blob carrying transaction that's calling this function.
     * @param blockNumber The block number the blob needs to be included in.
     * @param blockBuilder The address of the block builder who will include the blob.
     * @param deadline The deadline for including the blob.
     */
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

    /**
     * @notice Allows a block builder to withdraw their accumulated tips.
     */
    function withdrawTips() external {
        uint256 amount = blobTipLedger[msg.sender];
        require(amount > 0, "No tips to withdraw");
        blobTipLedger[msg.sender] = 0; // Update state before transfer
        payable(msg.sender).transfer(amount);
        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @notice Adds a block builder to the ledger.
     * @param blockBuilder The address of the block builder to add.
     */
    function addBlockBuilder(address blockBuilder) external onlyOwner {
        require(blobTipLedger[blockBuilder] == 0, "Block builder already exists");
        blobTipLedger[blockBuilder] = 0;
        emit BlockBuilderAdded(blockBuilder);
    }

    receive() external payable {}
}
