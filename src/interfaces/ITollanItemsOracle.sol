// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {Errors} from "./Errors.sol";

/**
 * @title ITollanItemsOracle
 * @notice Interface for TollanItemsOracle contract.
 * @dev Oracle manages claimable items and loot box rewards.
 *      Only stores data set by relayer; consumption is done by TollanItems contract.
 */
interface ITollanItemsOracle is IERC1155Receiver, Errors {
    /// @notice Struct to store loot box rewards with amounts.
    struct LootBoxReward {
        uint256[] tokenIds;
        uint256[] amounts;
    }

    // =============================================================
    // ERRORS
    // =============================================================

    /**
     * @notice Error thrown when the claimable amount is insufficient.
     */
    error InsufficientClaimable();

    // =============================================================
    // EVENTS
    // =============================================================

    /**
     * @notice Emitted when claimable amount is set for a user.
     * @param user User wallet address.
     * @param tokenId Token ID.
     * @param amount New claimable amount.
     */
    event ClaimableSet(
        address indexed user,
        uint256 indexed tokenId,
        uint256 amount
    );

    /**
     * @notice Emitted when claimable amount is consumed.
     * @param user User wallet address.
     * @param tokenId Token ID.
     * @param amount Amount consumed.
     */
    event ClaimableConsumed(
        address indexed user,
        uint256 indexed tokenId,
        uint256 amount
    );

    /**
     * @notice Emitted when loot box rewards are set for a user.
     * @param user User wallet address.
     * @param boxId Loot box token ID.
     * @param rewardIds Array of reward token IDs.
     * @param amounts Array of reward amounts.
     */
    event LootBoxRewardsSet(
        address indexed user,
        uint256 indexed boxId,
        uint256[] rewardIds,
        uint256[] amounts
    );

    /**
     * @notice Emitted when loot box rewards are consumed.
     * @param user User wallet address.
     * @param boxId Loot box token ID.
     * @param rewardIds Array of reward token IDs consumed.
     * @param amounts Array of reward amounts consumed.
     */
    event LootBoxRewardsConsumed(
        address indexed user,
        uint256 indexed boxId,
        uint256[] rewardIds,
        uint256[] amounts
    );

    // =============================================================
    // RELAYER FUNCTIONS
    // =============================================================

    /**
     * @notice Assigns claimable amount of item to user.
     * @param user User wallet address.
     * @param tokenId Token ID.
     * @param amount Claimable amount.
     */
    function setClaimable(
        address user,
        uint256 tokenId,
        uint256 amount
    ) external;

    /**
     * @notice Assigns claimable amount of items to user.
     * @param users User wallet addresses.
     * @param tokenIds Token IDs.
     * @param amounts Claimable amounts.
     */
    function setClaimables(
        address[] calldata users,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts
    ) external;

    /**
     * @notice Sets loot box rewards for a specific user.
     * @param user User address.
     * @param boxId Loot box token ID.
     * @param rewardTokenIds Reward token IDs.
     * @param amounts Reward amounts for each token.
     */
    function setLootBoxRewards(
        address user,
        uint256 boxId,
        uint256[] calldata rewardTokenIds,
        uint256[] calldata amounts
    ) external;

    // =============================================================
    // ITEMS CONTRACT FUNCTIONS
    // =============================================================

    /**
     * @notice Consumes claimable amount for user. Only callable by ITEMS_CONTRACT_ROLE.
     * @param user User wallet address.
     * @param tokenId Token ID.
     * @param amount Amount to consume.
     */
    function consumeClaimable(
        address user,
        uint256 tokenId,
        uint256 amount
    ) external;

    /**
     * @notice Consumes loot box rewards for user. Only callable by ITEMS_CONTRACT_ROLE.
     * @param user User wallet address.
     * @param boxId Loot box token ID.
     * @return rewardIds Array of reward token IDs.
     * @return amounts Array of reward amounts.
     */
    function consumeLootBoxRewards(
        address user,
        uint256 boxId
    ) external returns (uint256[] memory rewardIds, uint256[] memory amounts);

    // =============================================================
    // VIEW FUNCTIONS
    // =============================================================

    /**
     * @notice Returns claimable amount for user and token.
     * @param user User wallet address.
     * @param tokenId Token ID.
     * @return Claimable amount.
     */
    function getClaimable(
        address user,
        uint256 tokenId
    ) external view returns (uint256);

    /**
     * @notice Returns loot box rewards for user and box.
     * @param user User wallet address.
     * @param boxId Loot box token ID.
     * @return rewardIds Array of reward token IDs.
     * @return amounts Array of reward amounts.
     */
    function getLootBoxRewards(
        address user,
        uint256 boxId
    )
        external
        view
        returns (uint256[] memory rewardIds, uint256[] memory amounts);
}
