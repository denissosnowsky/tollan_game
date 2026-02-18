// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {ERC1155URIStorageUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol";
import {ERC1155SupplyUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import {ERC1155PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155PausableUpgradeable.sol";
import {ERC1155BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {ITollanItems} from "./interfaces/ITollanItems.sol";
import {ITollanItemsOracle} from "./interfaces/ITollanItemsOracle.sol";

/**
 * @title TollanItems
 * @notice Upgradeable ERC1155 contract for Tollan in-game items.
 *
 * @dev
 * Extensions used:
 * - ERC1155URIStorageUpgradeable
 * - ERC1155SupplyUpgradeable
 * - ERC1155PausableUpgradeable
 * - ERC1155BurnableUpgradeable
 * - AccessControlUpgradeable
 *
 * Features:
 * - Auto-incrementing NFT IDs when defining items
 * - Physical ID to NFT ID mapping
 * - Oracle-based claiming and loot box rewards
 * - Multiple oracle support via ORACLE_ROLE
 *
 * Designed for TransparentUpgradeableProxy (EIP-1967).
 * Uses ERC-7201 namespaced storage.
 */
contract TollanItems is
    Initializable,
    ERC1155Upgradeable,
    ERC1155URIStorageUpgradeable,
    ERC1155SupplyUpgradeable,
    ERC1155PausableUpgradeable,
    ERC1155BurnableUpgradeable,
    AccessControlUpgradeable,
    ITollanItems
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    /// @custom:storage-location erc7201:tollan.storage.TollanItems
    struct TollanItemsStorage {
        uint256 nextTokenId;
        mapping(uint256 => uint256) physicalIdToTokenId;
        mapping(uint256 => uint256) tokenIdToPhysicalId;
        mapping(uint256 => Item) physicalIdToItem;
    }

    // keccak256(abi.encode(uint256(keccak256("tollan.storage.TollanItems")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TOLLAN_ITEMS_STORAGE_LOCATION =
        0xebce24a7c80ac26c1050f30ba74c411f45bcbf5c41f56dd4c9b4a247494aed00;

    /**
     * @notice Checks if the address is not zero.
     */
    modifier notZeroAddress(address _address) {
        _notZeroAddress(_address);
        _;
    }

    /**
     * @notice Checks if the value is not zero.
     */
    modifier notZero(uint256 _value) {
        _notZero(_value);
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin
    ) external initializer notZeroAddress(admin) {
        __ERC1155_init("");
        __ERC1155URIStorage_init();
        __ERC1155Supply_init();
        __ERC1155Pausable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);

        TollanItemsStorage storage $ = _getTollanItemsStorage();
        $.nextTokenId = 1; // Start from 1, reserve 0 as "undefined"
    }

    // =============================================================
    // ADMIN FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ITollanItems
     */
    function defineItem(
        uint256 physicalId,
        string calldata name,
        string calldata metadataURI,
        uint256 amountCap
    ) public onlyRole(ADMIN_ROLE) notZero(physicalId) returns (uint256 nftId) {
        TollanItemsStorage storage $ = _getTollanItemsStorage();

        if ($.physicalIdToTokenId[physicalId] != 0)
            revert ItemAlreadyDefined(physicalId);

        nftId = $.nextTokenId++;

        $.physicalIdToTokenId[physicalId] = nftId;
        $.tokenIdToPhysicalId[nftId] = physicalId;
        $.physicalIdToItem[physicalId] = Item({
            physicalId: physicalId,
            name: name,
            amountCap: amountCap
        });

        _setURI(nftId, metadataURI);

        emit ItemDefined(physicalId, nftId, metadataURI);
    }

    /**
     * @inheritdoc ITollanItems
     */
    function defineItems(
        uint256[] calldata physicalId,
        string[] calldata names,
        string[] calldata metadataURI,
        uint256[] calldata amountCap
    ) public onlyRole(ADMIN_ROLE) returns (uint256[] memory nftIds) {
        if (
            physicalId.length != names.length ||
            physicalId.length != metadataURI.length ||
            physicalId.length != amountCap.length
        ) revert LengthMismatch();

        for (uint256 i = 0; i < physicalId.length; i++) {
            nftIds[i] = defineItem(
                physicalId[i],
                names[i],
                metadataURI[i],
                amountCap[i]
            );
        }
    }

    /**
     * @inheritdoc ITollanItems
     */
    function mintByPhysicalId(
        address to,
        uint256 physicalId,
        uint256 amount
    )
        external
        override
        onlyRole(ADMIN_ROLE)
        notZeroAddress(to)
        notZero(physicalId)
        whenNotPaused
    {
        TollanItemsStorage storage $ = _getTollanItemsStorage();

        uint256 nftId = $.physicalIdToTokenId[physicalId];
        if (nftId == 0) revert ItemNotDefined(physicalId);

        _mint(to, nftId, amount, "");
    }

    /**
     * @inheritdoc ITollanItems
     */
    function mintBatchByPhysicalId(
        address to,
        uint256[] calldata physicalIds,
        uint256[] calldata amounts
    ) external override onlyRole(ADMIN_ROLE) notZeroAddress(to) whenNotPaused {
        if (physicalIds.length != amounts.length) revert LengthMismatch();

        TollanItemsStorage storage $ = _getTollanItemsStorage();
        uint256[] memory nftIds = new uint256[](physicalIds.length);

        for (uint256 i = 0; i < physicalIds.length; i++) {
            uint nftId = $.physicalIdToTokenId[physicalIds[i]];
            if (nftId == 0) revert ItemNotDefined(physicalIds[i]);
            nftIds[i] = nftId;
        }

        _mintBatch(to, nftIds, amounts, "");
    }

    // =============================================================
    // USER FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ITollanItems
     */
    function claim(
        address oracle,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts
    ) external override whenNotPaused {
        if (tokenIds.length != amounts.length) {
            revert LengthMismatch();
        }
        if (!hasRole(ORACLE_ROLE, oracle)) {
            revert InvalidOracle(oracle);
        }

        TollanItemsStorage storage $ = _getTollanItemsStorage();
        ITollanItemsOracle oracleContract = ITollanItemsOracle(oracle);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 physicalId = $.tokenIdToPhysicalId[tokenIds[i]];
            if (physicalId == 0) revert ItemNotDefined(physicalId);
            oracleContract.consumeClaimable(
                _msgSender(),
                tokenIds[i],
                amounts[i]
            );
        }

        _mintBatch(_msgSender(), tokenIds, amounts, "");

        emit ItemsClaimed(_msgSender(), tokenIds, amounts);
    }

    /**
     * @inheritdoc ITollanItems
     */
    function openLootBox(
        address oracle,
        uint256 boxId
    ) external override whenNotPaused notZero(boxId) {
        if (!hasRole(ORACLE_ROLE, oracle)) {
            revert InvalidOracle(oracle);
        }
        if (balanceOf(_msgSender(), boxId) == 0) {
            revert NoLootBoxOwned(boxId);
        }

        TollanItemsStorage storage $ = _getTollanItemsStorage();
        uint256 physicalId = $.tokenIdToPhysicalId[boxId];
        if (physicalId == 0) revert ItemNotDefined(physicalId);

        ITollanItemsOracle oracleContract = ITollanItemsOracle(oracle);

        // Get rewards from oracle (this also deletes the rewards)
        (uint256[] memory rewardIds, uint256[] memory amounts) = oracleContract
            .consumeLootBoxRewards(_msgSender(), boxId);

        require(rewardIds.length > 0, "No rewards set");
        if (rewardIds.length == 0) revert NoRewardsSet();

        // Burn the loot box
        _burn(_msgSender(), boxId, 1);

        // Mint reward items
        _mintBatch(_msgSender(), rewardIds, amounts, "");

        emit LootBoxOpened(msg.sender, boxId, rewardIds, amounts);
    }

    // =============================================================
    // METADATA MANAGEMENT
    // =============================================================

    /**
     * @inheritdoc ITollanItems
     */
    function setTokenURI(
        uint256 tokenId,
        string calldata newURI
    ) external override onlyRole(ADMIN_ROLE) notZero(tokenId) {
        TollanItemsStorage storage $ = _getTollanItemsStorage();
        uint256 physicalId = $.tokenIdToPhysicalId[tokenId];
        if (physicalId == 0) revert ItemNotDefined(physicalId);

        _setURI(tokenId, newURI);

        emit TokenURIUpdated(tokenId, newURI);
    }

    /**
     * @inheritdoc ITollanItems
     */
    function setBaseURI(
        string calldata newBaseURI
    ) external override onlyRole(ADMIN_ROLE) {
        _setBaseURI(newBaseURI);

        emit BaseURIUpdated(newBaseURI);
    }

    /**
     * @inheritdoc ITollanItems
     */
    function addOracle(
        address oracle
    ) external override notZeroAddress(oracle) onlyRole(ADMIN_ROLE) {
        grantRole(ORACLE_ROLE, oracle);
        emit OracleAdded(oracle);
    }

    /**
     * @inheritdoc ITollanItems
     */
    function removeOracle(
        address oracle
    ) external override notZeroAddress(oracle) onlyRole(ADMIN_ROLE) {
        revokeRole(ORACLE_ROLE, oracle);
        emit OracleRemoved(oracle);
    }

    /**
     * @inheritdoc ITollanItems
     */
    function pause() external override onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @inheritdoc ITollanItems
     */
    function unpause() external override onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // =============================================================
    // VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ITollanItems
     */
    function getNftIdByPhysical(
        uint256 physicalId
    ) external view override returns (uint256) {
        TollanItemsStorage storage $ = _getTollanItemsStorage();
        return $.physicalIdToTokenId[physicalId];
    }

    /**
     * @inheritdoc ITollanItems
     */
    function getPhysicalIdByNft(
        uint256 nftId
    ) external view override returns (uint256) {
        TollanItemsStorage storage $ = _getTollanItemsStorage();
        return $.tokenIdToPhysicalId[nftId];
    }

    /**
     * @inheritdoc ITollanItems
     */
    function getNextTokenId() external view override returns (uint256) {
        TollanItemsStorage storage $ = _getTollanItemsStorage();
        return $.nextTokenId;
    }

    /**
     * @inheritdoc ITollanItems
     */
    function isPhysicalIdDefined(
        uint256 physicalId
    ) external view override returns (bool) {
        TollanItemsStorage storage $ = _getTollanItemsStorage();
        return $.physicalIdToTokenId[physicalId] != 0;
    }

    // =============================================================
    // REQUIRED OZ OVERRIDES
    // =============================================================

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    )
        internal
        override(
            ERC1155Upgradeable,
            ERC1155SupplyUpgradeable,
            ERC1155PausableUpgradeable
        )
    {
        super._update(from, to, ids, values);
    }

    function uri(
        uint256 tokenId
    )
        public
        view
        override(ERC1155Upgradeable, ERC1155URIStorageUpgradeable)
        returns (string memory)
    {
        TollanItemsStorage storage $ = _getTollanItemsStorage();
        uint256 physicalId = $.tokenIdToPhysicalId[tokenId];
        if (physicalId == 0) revert ItemNotDefined(physicalId);
        return super.uri(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _getTollanItemsStorage()
        private
        pure
        returns (TollanItemsStorage storage $)
    {
        assembly {
            $.slot := TOLLAN_ITEMS_STORAGE_LOCATION
        }
    }

    function _notZeroAddress(address _address) internal pure {
        if (_address == address(0)) {
            revert ZeroAddress(_address);
        }
    }

    function _notZero(uint256 _value) internal pure {
        if (_value == 0) {
            revert ZeroValue(_value);
        }
    }
}
