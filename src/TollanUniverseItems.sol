// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

import {TollanUniverseItemsView} from "./TollanUniverseItemsView.sol";
import {ITollanUniverseItems} from "./interfaces/ITollanUniverseItems.sol";

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
 * - ERC2981Upgradeable
 * - EIP712Upgradeable
 *
 * Features:
 * - Auto-incrementing NFT IDs when defining items
 * - Physical ID to NFT ID mapping
 * - Royalty support
 * - Signature verification for claiming items
 *
 * Designed for TransparentUpgradeableProxy (EIP-1967).
 * Uses ERC-7201 namespaced storage.
 */
contract TollanUniverseItems is
    Initializable,
    EIP712Upgradeable,
    NoncesUpgradeable,
    ITollanUniverseItems,
    TollanUniverseItemsView
{
    using ECDSA for bytes32;

    /**
     * @notice Checks if the address is not zero.
     */
    modifier notZeroAddress(address _address) {
        _notZeroAddress(_address);
        _;
    }

    /**
     * @notice Checks if the uint is not zero.
     */
    modifier notZeroUint(uint256 _value) {
        _notZeroUint(_value);
        _;
    }

    /**
     * @notice Checks if the string is not empty.
     */
    modifier notEmptyString(string calldata _value) {
        _notEmptyString(_value);
        _;
    }

    /**
     * @notice Checks if the deadline is not expired.
     */
    modifier notExpired(uint256 deadline) {
        _isExpired(deadline);
        _;
    }

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Defnies implementation initializer
     * @param admin admin address
     * @param minter minter address
     * @param burner burner address
     * @param signer signer address
     */
    function initialize(
        address admin,
        address minter,
        address burner,
        address signer,
        string memory name712,
        string memory version712
    )
        external
        initializer
        notZeroAddress(admin)
        notZeroAddress(minter)
        notZeroAddress(burner)
        notZeroAddress(signer)
    {
        __TollanUniverseItemsView_init();
        __Nonces_init();
        __EIP712_init(name712, version712);

        _grantRoles(admin, minter, burner);

        TollanItemsStorage storage $ = _getTollanItemsStorage();
        // Start from 1, reserve 0 as "undefined"
        $.nextTokenId = 1;
        $.signer = signer;
    }

    // =============================================================
    // ADMIN FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ITollanUniverseItems
     */
    function defineItem(
        string calldata physicalId,
        string calldata metadataURI,
        uint256 amountCap
    )
        public
        onlyRole(ADMIN_ROLE)
        notEmptyString(physicalId)
        returns (uint256 nftId)
    {
        return _defineItem(physicalId, metadataURI, amountCap);
    }

    /**
     * @inheritdoc ITollanUniverseItems
     */
    function defineItems(
        string[] calldata physicalIds,
        string[] calldata metadataUrIs,
        uint256[] calldata amountCaps
    ) public onlyRole(ADMIN_ROLE) returns (uint256[] memory nftIds) {
        uint256 length = physicalIds.length;

        if (length != metadataUrIs.length || length != amountCaps.length)
            revert LengthMismatch();

        nftIds = new uint256[](length);

        for (uint256 i; i < length; ) {
            _notEmptyString(physicalIds[i]);

            nftIds[i] = _defineItem(
                physicalIds[i],
                metadataUrIs[i],
                amountCaps[i]
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @inheritdoc ITollanUniverseItems
     */
    function setTokenURI(
        uint256 tokenId,
        string calldata newURI
    ) external override onlyRole(ADMIN_ROLE) notZeroUint(tokenId) {
        _isItemDefinedTokenId(tokenId);
        _setURI(tokenId, newURI);
        emit TokenURIUpdated(tokenId, newURI);
    }

    /**
     * @inheritdoc ITollanUniverseItems
     */
    function setBaseURI(
        string calldata newBaseURI
    ) external override onlyRole(ADMIN_ROLE) {
        _setBaseURI(newBaseURI);
        emit BaseURIUpdated(newBaseURI);
    }

    /**
     * @inheritdoc ITollanUniverseItems
     */
    function pause() external override onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @inheritdoc ITollanUniverseItems
     */
    function unpause() external override onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @inheritdoc ITollanUniverseItems
     */
    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) external onlyRole(ADMIN_ROLE) {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    /**
     * @inheritdoc ITollanUniverseItems
     */
    function setDefaultRoyalty(
        address receiver,
        uint96 feeNumerator
    ) external onlyRole(ADMIN_ROLE) {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    /**
     * @inheritdoc ITollanUniverseItems
     */
    function setSigner(
        address newSigner
    ) external onlyRole(ADMIN_ROLE) notZeroAddress(newSigner) {
        TollanItemsStorage storage $ = _getTollanItemsStorage();
        address oldSigner = $.signer;
        $.signer = newSigner;
        emit SignerUpdated(oldSigner, newSigner);
    }

    // =============================================================
    // MINTER FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ITollanUniverseItems
     */
    function mintByPhysicalId(
        address to,
        string calldata physicalId,
        uint256 amount
    )
        external
        onlyRole(MINT_ROLE)
        notZeroAddress(to)
        notZeroUint(amount)
        notEmptyString(physicalId)
        whenNotPaused
    {
        TollanItemsStorage storage $ = _getTollanItemsStorage();

        uint256 nftId = $.physicalIdToTokenId[physicalId];
        if (nftId == 0) revert ItemNotDefined(physicalId);

        _mint(to, nftId, amount, "");
    }

    /**
     * @inheritdoc ITollanUniverseItems
     */
    function mintBatchByPhysicalId(
        address to,
        string[] calldata physicalIds,
        uint256[] calldata amounts
    ) external onlyRole(MINT_ROLE) notZeroAddress(to) whenNotPaused {
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
    // BURNER FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ITollanUniverseItems
     */
    function burnByPhysicalId(
        address from,
        string calldata physicalId,
        uint256 amount
    )
        external
        onlyRole(BURN_ROLE)
        notZeroAddress(from)
        notZeroUint(amount)
        notEmptyString(physicalId)
        whenNotPaused
    {
        TollanItemsStorage storage $ = _getTollanItemsStorage();

        uint256 nftId = $.physicalIdToTokenId[physicalId];
        if (nftId == 0) revert ItemNotDefined(physicalId);

        _burn(from, nftId, amount);
    }

    /**
     * @inheritdoc ITollanUniverseItems
     */
    function burnBatchByPhysicalId(
        address from,
        string[] calldata physicalIds,
        uint256[] calldata amounts
    ) external onlyRole(BURN_ROLE) notZeroAddress(from) whenNotPaused {
        if (physicalIds.length != amounts.length) revert LengthMismatch();

        TollanItemsStorage storage $ = _getTollanItemsStorage();
        uint256[] memory nftIds = new uint256[](physicalIds.length);

        for (uint256 i = 0; i < physicalIds.length; i++) {
            uint nftId = $.physicalIdToTokenId[physicalIds[i]];
            if (nftId == 0) revert ItemNotDefined(physicalIds[i]);
            nftIds[i] = nftId;
        }

        _burnBatch(from, nftIds, amounts);
    }

    // =============================================================
    // USER FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ITollanUniverseItems
     */
    function claimBatch(
        uint256[] calldata tokenIds,
        string[] calldata physicalIds,
        uint256[] calldata amounts,
        uint256 deadline,
        bytes calldata signature
    ) external whenNotPaused notExpired(deadline) {
        uint256 length = tokenIds.length;
        if (length != amounts.length || length != physicalIds.length) {
            revert LengthMismatch();
        }
        for (uint256 i = 0; i < length; i++) {
            _isItemDefinedTokenId(tokenIds[i]);
        }

        /// new stack needed to avoid stack overflow
        {
            uint256 nonce = nonces(_msgSender());
            bytes32 tokenIdsHash = keccak256(abi.encode(tokenIds));
            bytes32 amountsHash = keccak256(abi.encode(amounts));
            bytes32 physicalIdsHash;
            {
                bytes32[] memory pHashes = new bytes32[](length);
                for (uint256 i = 0; i < length; i++) {
                    pHashes[i] = keccak256(bytes(physicalIds[i]));
                }
                physicalIdsHash = keccak256(abi.encode(pHashes));
            }
            bytes32 structHash = keccak256(
                abi.encode(
                    CLAIM_BATCH_TYPEHASH,
                    _msgSender(),
                    tokenIdsHash,
                    physicalIdsHash,
                    amountsHash,
                    nonce,
                    deadline
                )
            );
            _validateSignature(structHash, signature);
        }

        _useNonce(_msgSender());
        _mintBatch(_msgSender(), tokenIds, amounts, "");
        _claimIncreaseBatch(_msgSender(), physicalIds, amounts);
        emit ItemsClaimed(_msgSender(), tokenIds, amounts);
    }

    /**
     * @inheritdoc ITollanUniverseItems
     */
    function claim(
        uint256 tokenId,
        string calldata physicalId,
        uint256 amount,
        uint256 deadline,
        bytes calldata signature
    )
        external
        notZeroUint(amount)
        notEmptyString(physicalId)
        notExpired(deadline)
        whenNotPaused
    {
        _isItemDefinedTokenId(tokenId);
        uint256 nonce = nonces(_msgSender());
        bytes32 structHash = keccak256(
            abi.encode(
                CLAIM_TYPEHASH,
                _msgSender(),
                tokenId,
                keccak256(bytes(physicalId)),
                amount,
                nonce,
                deadline
            )
        );
        _validateSignature(structHash, signature);
        _useNonce(_msgSender());
        _mint(_msgSender(), tokenId, amount, "");
        _claimIncrease(_msgSender(), physicalId, amount);
        emit ItemClaimed(_msgSender(), tokenId, amount);
    }

    // =============================================================
    // INTERNAL
    // =============================================================

    function _defineItem(
        string calldata physicalId,
        string calldata metadataURI,
        uint256 amountCap
    ) internal returns (uint256 nftId) {
        TollanItemsStorage storage $ = _getTollanItemsStorage();

        if ($.physicalIdToTokenId[physicalId] != 0)
            revert ItemAlreadyDefined(physicalId);

        nftId = $.nextTokenId++;

        $.physicalIdToTokenId[physicalId] = nftId;
        $.tokenIdToPhysicalId[nftId] = physicalId;
        $.physicalIdToAmountCap[physicalId] = amountCap;

        _setURI(nftId, metadataURI);

        emit ItemDefined(physicalId, nftId, metadataURI);
    }

    function _notZeroAddress(address _address) internal pure {
        if (_address == address(0)) {
            revert ZeroAddress(_address);
        }
    }

    function _notZeroUint(uint256 _value) internal pure {
        if (_value == 0) {
            revert ZeroUint(_value);
        }
    }

    function _notEmptyString(string calldata _value) internal pure {
        if (bytes(_value).length == 0) {
            revert EmptyString(_value);
        }
    }

    function _isExpired(uint256 deadline) internal view {
        if (deadline != 0 && block.timestamp > deadline)
            revert SignatureExpired();
    }

    function _grantRoles(
        address admin,
        address minter,
        address burner
    ) internal {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(MINT_ROLE, minter);
        _grantRole(BURN_ROLE, burner);
    }

    function _validateSignature(
        bytes32 structHash,
        bytes calldata signature
    ) internal view {
        bytes32 digest = _hashTypedDataV4(structHash);
        address signer = digest.recover(signature);
        if (_getTollanItemsStorage().signer != signer) revert InvalidSigner();
    }

    function _claimIncrease(
        address user,
        string calldata physicalId,
        uint256 amount
    ) internal {
        TollanItemsStorage storage $ = _getTollanItemsStorage();
        $.claimed[user][physicalId] = $.claimed[user][physicalId] + amount;
    }

    function _claimIncreaseBatch(
        address user,
        string[] calldata physicalIds,
        uint256[] calldata amounts
    ) internal {
        TollanItemsStorage storage $ = _getTollanItemsStorage();
        for (uint256 i = 0; i < physicalIds.length; i++) {
            $.claimed[user][physicalIds[i]] =
                $.claimed[user][physicalIds[i]] +
                amounts[i];
        }
    }
}
