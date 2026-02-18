// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ITollanItemsOracle} from "./interfaces/ITollanItemsOracle.sol";

/**
 * @title TollanItemsOracle
 * @notice Oracle contract responsible for managing claimable rewards
 *         and loot box reward assignments for users.
 *
 * @dev
 * This contract stores data set by the relayer:
 * - Claimable item amounts for users
 * - Loot box rewards (token IDs and amounts)
 *
 * The TollanItems contract consumes this data when users claim items
 * or open loot boxes. Only addresses with ITEMS_CONTRACT_ROLE can
 * consume data.
 */
contract TollanItemsOracle is ITollanItemsOracle, AccessControl {
    /// @notice Role allowed to assign claims and loot box rewards.
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    /// @notice Role for TollanItems contract to consume rewards.
    bytes32 public constant ITEMS_CONTRACT_ROLE =
        keccak256("ITEMS_CONTRACT_ROLE");

    /// @notice user => tokenId => claimable amount
    mapping(address => mapping(uint256 => uint256)) private _claimable;

    /// @notice user => boxId => LootBoxReward
    mapping(address => mapping(uint256 => LootBoxReward))
        private _lootBoxRewards;

    /**
     * @notice Initializes the oracle.
     * @param admin Admin address.
     * @param relayer Relayer address.
     * @param itemsContract TollanItems contract address.
     */
    constructor(address admin, address relayer, address itemsContract) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(RELAYER_ROLE, relayer);
        _grantRole(ITEMS_CONTRACT_ROLE, itemsContract);
    }

    // =============================================================
    // RELAYER FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ITollanItemsOracle
     */
    function setClaimable(
        address user,
        uint256 tokenId,
        uint256 amount
    ) public onlyRole(RELAYER_ROLE) {
        _claimable[user][tokenId] = amount;
        emit ClaimableSet(user, tokenId, amount);
    }

    /**
     * @inheritdoc ITollanItemsOracle
     */
    function setClaimables(
        address[] calldata users,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts
    ) external onlyRole(RELAYER_ROLE) {
        if (users.length != tokenIds.length || users.length != amounts.length) {
            revert LengthMismatch();
        }

        for (uint256 i = 0; i < users.length; i++) {
            setClaimable(users[i], tokenIds[i], amounts[i]);
        }
    }

    /**
     * @inheritdoc ITollanItemsOracle
     */
    function setLootBoxRewards(
        address user,
        uint256 boxId,
        uint256[] calldata rewardTokenIds,
        uint256[] calldata amounts
    ) external onlyRole(RELAYER_ROLE) {
        if (rewardTokenIds.length != amounts.length) {
            revert LengthMismatch();
        }

        _lootBoxRewards[user][boxId] = LootBoxReward({
            tokenIds: rewardTokenIds,
            amounts: amounts
        });

        emit LootBoxRewardsSet(user, boxId, rewardTokenIds, amounts);
    }

    // =============================================================
    // ITEMS CONTRACT FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ITollanItemsOracle
     */
    function consumeClaimable(
        address user,
        uint256 tokenId,
        uint256 amount
    ) external onlyRole(ITEMS_CONTRACT_ROLE) {
        uint256 available = _claimable[user][tokenId];
        if (available < amount) {
            revert InsufficientClaimable();
        }
        _claimable[user][tokenId] = available - amount;

        emit ClaimableConsumed(user, tokenId, amount);
    }

    /**
     * @inheritdoc ITollanItemsOracle
     */
    function consumeLootBoxRewards(
        address user,
        uint256 boxId
    )
        external
        onlyRole(ITEMS_CONTRACT_ROLE)
        returns (uint256[] memory rewardIds, uint256[] memory amounts)
    {
        LootBoxReward storage reward = _lootBoxRewards[user][boxId];

        if (reward.tokenIds.length == 0) {
            revert NoRewardsSet();
        }

        rewardIds = reward.tokenIds;
        amounts = reward.amounts;

        delete _lootBoxRewards[user][boxId];

        emit LootBoxRewardsConsumed(user, boxId, rewardIds, amounts);
    }

    // =============================================================
    // VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc ITollanItemsOracle
     */
    function getClaimable(
        address user,
        uint256 tokenId
    ) external view returns (uint256) {
        return _claimable[user][tokenId];
    }

    /**
     * @inheritdoc ITollanItemsOracle
     */
    function getLootBoxRewards(
        address user,
        uint256 boxId
    )
        external
        view
        returns (uint256[] memory rewardIds, uint256[] memory amounts)
    {
        LootBoxReward storage reward = _lootBoxRewards[user][boxId];
        return (reward.tokenIds, reward.amounts);
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return 0xf23a6e61;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return 0xbc197c81;
    }
}
