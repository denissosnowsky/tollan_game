// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC1155URIStorageUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol";
import {ERC1155SupplyUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import {ERC1155PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155PausableUpgradeable.sol";
import {ERC1155BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";

import {TollanUniverseItemsStorage} from "./TollanUniverseItemsStorage.sol";
import {ITollanUniverseItemsView} from "./interfaces/ITollanUniverseItemsView.sol";

contract TollanUniverseItemsView is
    ERC1155Upgradeable,
    ERC1155URIStorageUpgradeable,
    ERC2981Upgradeable,
    ERC1155SupplyUpgradeable,
    ERC1155PausableUpgradeable,
    ERC1155BurnableUpgradeable,
    AccessControlUpgradeable,
    ITollanUniverseItemsView,
    TollanUniverseItemsStorage
{
    function __TollanUniverseItemsView_init() internal onlyInitializing {
        __ERC1155_init("");
        __ERC1155URIStorage_init();
        __AccessControl_init();
        __ERC1155Supply_init();
        __ERC1155Pausable_init();
        __ERC1155Burnable_init();
        __ERC2981_init();
    }

    /**
     * @inheritdoc ITollanUniverseItemsView
     */
    function getNftIdByPhysicalId(
        string calldata physicalId
    ) external view returns (uint256) {
        _isItemDefinedPhysicalId(physicalId);
        TollanItemsStorage storage $ = _getTollanItemsStorage();
        return $.physicalIdToTokenId[physicalId];
    }

    /**
     * @inheritdoc ITollanUniverseItemsView
     */
    function getPhysicalIdByTokenId(
        uint256 tokenId
    ) external view override returns (string memory) {
        _isItemDefinedTokenId(tokenId);
        TollanItemsStorage storage $ = _getTollanItemsStorage();
        return $.tokenIdToPhysicalId[tokenId];
    }

    /**
     * @inheritdoc ITollanUniverseItemsView
     */
    function getNextTokenId() external view override returns (uint256) {
        TollanItemsStorage storage $ = _getTollanItemsStorage();
        return $.nextTokenId;
    }

    /**
     * @inheritdoc ITollanUniverseItemsView
     */
    function isPhysicalIdDefined(
        string calldata physicalId
    ) external view returns (bool) {
        TollanItemsStorage storage $ = _getTollanItemsStorage();
        return $.physicalIdToTokenId[physicalId] != 0;
    }

    /**
     * @inheritdoc ITollanUniverseItemsView
     */
    function balanceOfPhysicalId(
        address user,
        string calldata physicalId
    ) external view returns (uint256) {
        _isItemDefinedPhysicalId(physicalId);
        TollanItemsStorage storage $ = _getTollanItemsStorage();
        return super.balanceOf(user, $.physicalIdToTokenId[physicalId]);
    }

    /**
     * @inheritdoc ITollanUniverseItemsView
     */
    function getAmountCap(
        string calldata physicalId
    ) external view returns (uint256) {
        TollanItemsStorage storage $ = _getTollanItemsStorage();
        return $.physicalIdToAmountCap[physicalId];
    }

    /**
     * @inheritdoc ITollanUniverseItemsView
     */
    function getClaimed(
        address user,
        string calldata physicalId
    ) external view returns (uint256) {
        TollanItemsStorage storage $ = _getTollanItemsStorage();
        return $.claimed[user][physicalId];
    }

    function uri(
        uint256 tokenId
    )
        public
        view
        override(ERC1155Upgradeable, ERC1155URIStorageUpgradeable)
        returns (string memory)
    {
        _isItemDefinedTokenId(tokenId);
        return super.uri(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(
            ERC1155Upgradeable,
            AccessControlUpgradeable,
            ERC2981Upgradeable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // =============================================================
    // INTERNAL
    // =============================================================

    function _isItemDefinedPhysicalId(
        string calldata _physicalId
    ) internal view {
        TollanItemsStorage storage $ = _getTollanItemsStorage();
        uint256 tokenId = $.physicalIdToTokenId[_physicalId];
        if (tokenId == 0) revert ItemNotDefined(_physicalId);
    }

    function _isItemDefinedTokenId(uint256 _tokenId) internal view {
        TollanItemsStorage storage $ = _getTollanItemsStorage();
        string memory physicalId = $.tokenIdToPhysicalId[_tokenId];
        if (bytes(physicalId).length == 0) {
            revert ItemNotDefined(physicalId);
        }
    }

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
        TollanItemsStorage storage $ = _getTollanItemsStorage();
        for (uint256 i = 0; i < ids.length; i++) {
            string memory physicalId = $.tokenIdToPhysicalId[ids[i]];
            if (bytes(physicalId).length == 0) {
                revert ItemNotDefined(physicalId);
            }
            if (from == address(0)) {
                uint amountCap = $.physicalIdToAmountCap[physicalId];
                if (
                    amountCap != 0 &&
                    amountCap < values[i] + totalSupply(ids[i])
                ) {
                    revert AmountCapExceeded(values[i], amountCap);
                }
            }
        }
        super._update(from, to, ids, values);
    }
}
