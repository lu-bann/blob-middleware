// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/BlobMiddleware.sol";

contract BlobMiddlewareTest is Test {
    BlobMiddleware blobMiddleware;
    address blockBuilder = address(0x1234);

    function setUp() public {
        blobMiddleware = new BlobMiddleware();
        blobMiddleware.addBlockBuilder(blockBuilder);
    }

    function testSubmitBlob() public {
        vm.blobBaseFee(100 gwei);

        bytes32[] memory hashes = new bytes32[](3);
        hashes[0] = keccak256("blob1");
        hashes[1] = keccak256("blob2");
        hashes[2] = keccak256("blob3");
        vm.blobhashes(hashes);

        uint256 blobCount = blobMiddleware.countBlobs();
        assertEq(blobCount, vm.getBlobhashes().length, "Blob count mismatch");

        uint256 tipPerBlob = 1 gwei;
        uint256 blockNumber = block.number;
        uint256 deadline = 10;
        uint256 totalTip = tipPerBlob * hashes.length;
        uint256 inclusionBlock = blockNumber + deadline;

        vm.roll(inclusionBlock);
        vm.prank(address(0x1));
        vm.deal(address(0x1), totalTip);
        blobMiddleware.submitBlob{value: totalTip}(tipPerBlob, blockNumber, blockBuilder, deadline);

        assertEq(blobMiddleware.blobTipLedger(blockBuilder), totalTip, "Blob tip ledger mismatch");
    }
}
