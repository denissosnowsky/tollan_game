// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IErrors {
    /**
     * @notice Error thrown when an item is already defined.
     * @param _physicalId Physical item ID.
     */
    error ItemAlreadyDefined(string _physicalId);

    /**
     * @notice Error thrown when an item is not defined.
     * @param _physicalId Physical item ID.
     */
    error ItemNotDefined(string _physicalId);

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
    error ZeroUint(uint256 _value);

    /**
     * @notice Error thrown when an empty string is provided.
     * @param _value Empty string.
     */
    error EmptyString(string _value);

    /**
     * @notice Error thrown when an amount exceeds the cap.
     * @param _amount Amount.
     * @param _cap Cap.
     */
    error AmountCapExceeded(uint256 _amount, uint256 _cap);

    /**
     * @notice Error thrown when an invalid signer is provided.
     */
    error InvalidSigner();

    /**
     * @notice Error thrown when an invalid minter is provided.
     */
    error InvalidMinter();

    /**
     * @notice Error thrown when an invalid burner is provided.
     */
    error InvalidBurner();

    /**
     * @notice Error thrown when a signature has expired.
     */
    error SignatureExpired();
}
