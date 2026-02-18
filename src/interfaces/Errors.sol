// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface Errors {
    /**
     * @notice Error thrown when the length of two arrays is not equal.
     */
    error LengthMismatch();

    /**
     * @notice Error thrown when a zero address is provided.
     * @param _address Zero address.
     */
    error ZeroAddress(address _address);

    /**
     * @notice Error thrown when a zero value is provided.
     * @param _value Zero value.
     */
    error ZeroValue(uint256 _value);

    /**
     * @notice Error thrown when the callet does not have rewards for the loot box
     */
    error NoRewardsSet();
}
