// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Errors} from "./Errors.sol";

/**
 * @title ITollanItems
 * @notice Interface for Tollan ERC1155 in-game item contract.
 *
 * @dev
 * Supports:
 * - Physical item ID → NFT ID mapping (auto-incrementing NFT IDs)
 * - Oracle-based minting
 * - Admin metadata management
 * - Consumables via burn
 * - Loot box opening
 * - Item claiming from oracle
 */
interface ITollanItems is Errors {
    struct Item {
        uint256 physicalId;
        string name;
        uint256 amountCap;
    }

    // =============================================================
    // ERRORS
    // =============================================================

    /**
     * @notice Error thrown when an item is already defined.
     * @param _physicalId Physical item ID.
     */
    error ItemAlreadyDefined(uint256 _physicalId);

    /**
     * @notice Error thrown when an item is not defined.
     * @param _physicalId Physical item ID.
     */
    error ItemNotDefined(uint256 _physicalId);

    /**
     * @notice Error thrown when the caller is not an admin or oracle.
     * @param _address Caller address.
     */
    error NotAdminOrOracle(address _address);

    /**
     * @notice Error thrown when the address is not oracle.
     * @param _address oracle address.
     */
    error InvalidOracle(address _address);

    /**
     * @notice Error thrown when the caller does not own a loot box.
     * @param _boxId Loot box ID.
     */
    error NoLootBoxOwned(uint256 _boxId);

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
        uint256 indexed physicalId,
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
     * @notice Emitted when an oracle is added.
     * @param oracle Oracle contract address.
     */
    event OracleAdded(address indexed oracle);

    /**
     * @notice Emitted when an oracle is removed.
     * @param oracle Oracle contract address.
     */
    event OracleRemoved(address indexed oracle);

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
     * @notice Emitted when user opens a loot box.
     * @param user User address.
     * @param boxId Loot box token ID that was burned.
     * @param rewardIds Array of reward token IDs received.
     * @param amounts Array of reward amounts received.
     */
    event LootBoxOpened(
        address indexed user,
        uint256 indexed boxId,
        uint256[] rewardIds,
        uint256[] amounts
    );

    // =============================================================
    // ITEM DEFINITION
    // =============================================================

    /**
     * @notice Defines a new physical item and auto-assigns NFT ID.
     * @param physicalId Backend item ID.
     * @param metadataURI Metadata URI for token.
     * @return nftId Auto-assigned ERC1155 token ID.
     */
    function defineItem(
        uint256 physicalId,
        string calldata name,
        string calldata metadataURI,
        uint256 amountCap
    ) external returns (uint256 nftId);

    /**
     * @notice Defines new physical items and auto-assigns NFT IDs.
     * @param physicalIds Backend item IDs.
     * @param metadataURIs Metadata URIs for tokens.
     * @return nftIds Auto-assigned ERC1155 token IDs.
     */
    function defineItems(
        uint256[] calldata physicalIds,
        string[] calldata names,
        string[] calldata metadataURIs,
        uint256[] calldata amountCaps
    ) external returns (uint256[] memory nftIds);

    /**
     * @notice Returns NFT ID mapped to physical ID.
     * @param physicalId Backend item ID.
     * @return nftId ERC1155 token ID (0 if not defined).
     */
    function getNftIdByPhysical(
        uint256 physicalId
    ) external view returns (uint256);

    /**
     * @notice Returns physical ID mapped to NFT ID.
     * @param nftId ERC1155 token ID.
     * @return physicalId Backend item ID.
     */
    function getPhysicalIdByNft(uint256 nftId) external view returns (uint256);

    /**
     * @notice Returns the next token ID to be assigned.
     * @return Next token ID.
     */
    function getNextTokenId() external view returns (uint256);

    /**
     * @notice Checks if a physical ID has been defined.
     * @param physicalId Backend item ID.
     * @return True if defined.
     */
    function isPhysicalIdDefined(
        uint256 physicalId
    ) external view returns (bool);

    // =============================================================
    // MINTING (ORACLE_ROLE only)
    // =============================================================

    /**
     * @notice Oracle mint by physical ID.
     * @param to Receiver address.
     * @param physicalId Backend item ID.
     * @param amount Amount to mint.
     */
    function mintByPhysicalId(
        address to,
        uint256 physicalId,
        uint256 amount
    ) external;

    /**
     * @notice Oracle batch mint by physical IDs.
     * @param to Receiver address.
     * @param physicalIds Backend item IDs.
     * @param amounts Amounts to mint.
     */
    function mintBatchByPhysicalId(
        address to,
        uint256[] calldata physicalIds,
        uint256[] calldata amounts
    ) external;

    // =============================================================
    // USER FUNCTIONS
    // =============================================================

    /**
     * @notice User claims items from oracle.
     * @param oracle Oracle contract address to claim from.
     * @param tokenIds Array of token IDs to claim.
     * @param amounts Array of amounts to claim.
     */
    function claim(
        address oracle,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts
    ) external;

    /**
     * @notice User opens a loot box, burning it and receiving rewards.
     * @param oracle Oracle contract address with reward data.
     * @param boxId Loot box token ID to open.
     */
    function openLootBox(address oracle, uint256 boxId) external;

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
    // ORACLE MANAGEMENT
    // =============================================================

    /**
     * @notice Adds an oracle address (grants ORACLE_ROLE).
     * @param oracle Oracle contract address.
     */
    function addOracle(address oracle) external;

    /**
     * @notice Removes an oracle address (revokes ORACLE_ROLE).
     * @param oracle Oracle contract address.
     */
    function removeOracle(address oracle) external;

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
