// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IErrors} from "./IErrors.sol";

/**
 * @title ITollanUniverseItems
 * @notice Interface for Tollan ERC1155 in-game item contract.
 *
 * @dev
 * Supports:
 * - Physical item ID(string) → NFT ID(uint) mapping (auto-incrementing NFT IDs)
 * - Admin metadata management
 * - Consumables via burn
 */
interface ITollanUniverseItems is IErrors {
    // =============================================================
    // EVENTS
    // =============================================================

    /**
     * @notice Emitted when a new item is defined.
     * @param physicalId Backend physical item ID.
     * @param nftId ERC1155 token ID (auto-assigned).
     * @param metadataURI Metadata URI assigned.
     */
    event ItemDefined(
        string indexed physicalId,
        uint256 indexed nftId,
        string metadataURI
    );

    /**
     * @notice Emitted when token URI is updated.
     * @param tokenId ERC1155 token ID.
     * @param newURI New metadata URI.
     */
    event TokenURIUpdated(uint256 indexed tokenId, string newURI);

    /**
     * @notice Emitted when base URI is updated.
     * @param newBaseURI New base URI.
     */
    event BaseURIUpdated(string newBaseURI);

    /**
     * @notice Emitted when user claims items.
     * @param user User address.
     * @param tokenIds Array of claimed token IDs.
     * @param amounts Array of claimed amounts.
     */
    event ItemsClaimed(
        address indexed user,
        uint256[] tokenIds,
        uint256[] amounts
    );

    /**
     * @notice Emitted when user claims item.
     * @param user User address.
     * @param tokenId Claimed token ID.
     * @param amount Claimed amounts.
     */
    event ItemClaimed(address indexed user, uint256 tokenId, uint256 amount);

    /**
     * @notice Emitted when user claims items by physical ids.
     * @param user User address.
     * @param physicalIds Array of claimed physical IDs.
     * @param amounts Array of claimed amounts.
     */
    event ItemsClaimedByPhysicalIds(
        address indexed user,
        string[] physicalIds,
        uint256[] amounts
    );

    /**
     * @notice Emitted when user claims item by physical id.
     * @param user User address.
     * @param physicalId Claimed token ID.
     * @param amount Claimed amounts.
     */
    event ItemClaimedPhysicalId(
        address indexed user,
        string physicalId,
        uint256 amount
    );

    /**
     * @notice Emitted when the signer address is updated.
     * @param oldSigner Previous signer address.
     * @param newSigner New signer address.
     */
    event SignerUpdated(address indexed oldSigner, address indexed newSigner);

    // =============================================================
    // ITEM DEFINITION
    // =============================================================

    /**
     * @notice Defines a new physical item and auto-assigns NFT ID.
     * @param physicalId Backend item ID.
     * @param metadataURI Metadata URI for token.
     * @param amountCap Maximum amount number (0 - for unlimited)
     * @return nftId Auto-assigned ERC1155 token ID.
     */
    function defineItem(
        string calldata physicalId,
        string calldata metadataURI,
        uint256 amountCap
    ) external returns (uint256 nftId);

    /**
     * @notice Defines new physical items and auto-assigns NFT IDs.
     * @param physicalIds Backend item IDs.
     * @param metadataUrIs Metadata URIs for tokens.
     * @param amountCaps Maximum amount numbers (0 - for unlimited)
     * @return nftIds Auto-assigned ERC1155 token IDs.
     */
    function defineItems(
        string[] calldata physicalIds,
        string[] calldata metadataUrIs,
        uint256[] calldata amountCaps
    ) external returns (uint256[] memory nftIds);

    /**
     * @notice Mint by physical ID.
     * @param to Receiver address.
     * @param physicalId Backend item ID.
     * @param amount Amount to mint.
     */
    function mintByPhysicalId(
        address to,
        string calldata physicalId,
        uint256 amount
    ) external;

    /**
     * @notice Batch mint by physical IDs.
     * @param to Receiver address.
     * @param physicalIds Backend item IDs.
     * @param amounts Amounts to mint.
     */
    function mintBatchByPhysicalId(
        address to,
        string[] calldata physicalIds,
        uint256[] calldata amounts
    ) external;

    /**
     * @notice Burn by physical ID.
     * @param from From address.
     * @param physicalId Backend item ID.
     * @param amount Amount to mint.
     */
    function burnByPhysicalId(
        address from,
        string calldata physicalId,
        uint256 amount
    ) external;

    /**
     * @notice Batch burn by physical IDs.
     * @param from From address.
     * @param physicalIds Backend item IDs.
     * @param amounts Amounts to mint.
     */
    function burnBatchByPhysicalId(
        address from,
        string[] calldata physicalIds,
        uint256[] calldata amounts
    ) external;

    /**
     * @notice Set royalty for a token.
     * @param tokenId Token ID.
     * @param receiver Royalty receiver.
     * @param feeNumerator Royalty fee numerator.
     */
    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) external;

    /**
     * @notice Set default royalty.
     * @param receiver Royalty receiver.
     * @param feeNumerator Royalty fee numerator.
     */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external;

    // =============================================================
    // USER FUNCTIONS
    // =============================================================

    /**
     * @notice User claims item.
     * @param tokenId token ID to claim.
     * @param physicalId physical ID to claim.
     * @param amount amount to claim.
     * @param deadline deadline when signature expires (0 - for never expires)
     * @param signature Signature of the claim.
     */
    function claim(
        uint256 tokenId,
        string calldata physicalId,
        uint256 amount,
        uint256 deadline,
        bytes calldata signature
    ) external;

    /**
     * @notice User claims items.
     * @param tokenIds Array of token IDs to claim.
     * @param physicalIds Array of physical IDs to claim.
     * @param amounts Array of amounts to claim.
     * @param deadline deadline when signature expires (0 - for never expires)
     * @param signature Signature of the claim.
     */
    function claimBatch(
        uint256[] calldata tokenIds,
        string[] calldata physicalIds,
        uint256[] calldata amounts,
        uint256 deadline,
        bytes calldata signature
    ) external;

    // =============================================================
    // METADATA MANAGEMENT
    // =============================================================

    /**
     * @notice Updates metadata URI for token.
     * @param tokenId ERC1155 token ID.
     * @param newURI New metadata URI.
     */
    function setTokenURI(uint256 tokenId, string calldata newURI) external;

    /**
     * @notice Sets new base URI.
     * @param newBaseURI New base URI.
     */
    function setBaseURI(string calldata newBaseURI) external;

    // =============================================================
    // SIGNER MANAGEMENT
    // =============================================================

    /**
     * @notice Updates the signer address used for claim signature validation.
     * @param newSigner New signer address.
     */
    function setSigner(address newSigner) external;

    // =============================================================
    // PAUSE MANAGEMENT
    // =============================================================

    /**
     * @notice Pauses the contract.
     */
    function pause() external;

    /**
     * @notice Unpauses the contract.
     */
    function unpause() external;
}
