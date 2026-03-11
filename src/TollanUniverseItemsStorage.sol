// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract TollanUniverseItemsStorage {
    /// @custom:storage-location erc7201:tollan.storage.TollanUniverseItems
    struct TollanItemsStorage {
        address signer;
        address minter;
        address burner;
        uint256 nextTokenId;
        mapping(string => uint256) physicalIdToTokenId;
        mapping(uint256 => string) tokenIdToPhysicalId;
        mapping(string => uint256) physicalIdToAmountCap;
        mapping(address => mapping(string => uint256)) claimed;
    }

    // keccak256(abi.encode(uint256(keccak256("tollan.storage.TollanUniverseItems")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant TOLLAN_ITEMS_STORAGE_LOCATION =
        0x688f56fc52f912ae5c31135e1893fd5e877bf2f5be8c927461940f3a15af0800;

    /// keccak256("Claim(address to,uint256 tokenId,string physicalId,uint256 amount,uint256 nonce,uint256 deadline)")
    bytes32 internal constant CLAIM_TYPEHASH =
        0xea97b92824caa45e673dad22b48157385b7963088a25cd77eda4e99f0b4450a2;
    /// keccak256("ClaimBatch(address to,bytes32 tokenIdsHash,bytes32 physicalIdsHash,bytes32 amountsHash,uint256 nonce,uint256 deadline)")
    bytes32 internal constant CLAIM_BATCH_TYPEHASH =
        0x70dae5e3916ec9bad3f26be7851dac19106818068928cf478718012a94764f52;

    function _getTollanItemsStorage()
        internal
        pure
        returns (TollanItemsStorage storage $)
    {
        assembly {
            $.slot := TOLLAN_ITEMS_STORAGE_LOCATION
        }
    }
}
