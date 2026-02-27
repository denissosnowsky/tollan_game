// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IErrors} from "./IErrors.sol";

interface ITollanUniverseItemsView is IErrors {
    /**
     * @notice Returns NFT ID mapped to physical ID.
     * @param physicalId Backend item ID.
     * @return nftId ERC1155 token ID (0 if not defined).
     */
    function getNftIdByPhysicalId(
        string calldata physicalId
    ) external view returns (uint256);

    /**
     * @notice Returns physical ID mapped to NFT ID.
     * @param tokenId ERC1155 token ID.
     * @return physicalId Backend item ID.
     */
    function getPhysicalIdByTokenId(
        uint256 tokenId
    ) external view returns (string memory);

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
        string calldata physicalId
    ) external view returns (bool);

    /**
     * @notice Checks user's balance of a physical ID.
     * @param user user address
     * @param physicalId Backend item ID.
     * @return owned amount.
     */
    function balanceOfPhysicalId(
        address user,
        string calldata physicalId
    ) external view returns (uint256);

    /**
     * @notice Returns amount cap of nft
     * @param physicalId Backend item ID
     * @return amount cap
     */
    function getAmountCap(
        string calldata physicalId
    ) external view returns (uint256);

    /**
     * @notice Returns number of claimed tokens
     * @param user wallet address
     * @param physicalId partial ID.
     * @return amount claimed tokens by id
     */
    function getClaimed(
        address user,
        string calldata physicalId
    ) external view returns (uint256);

    /**
     * @notice Returns the current signer address used for claim signature validation.
     * @return signer Current signer address.
     */
    function getSigner() external view returns (address);
}
