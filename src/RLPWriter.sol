// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RLPHelpers} from "./utils/RLPHelpers.sol";

/**
 * @title RLPWriter
 * @notice Library for encoding data in Recursive Length Prefix (RLP) format
 * @dev Implementation of RLP encoding following the Ethereum Yellow Paper specification:
 * - Handles single values and lists
 * - Supports both short and long format encoding
 * - Includes validation of input data
 */
library RLPWriter {
    /**
     * RLP Encoding Rules:
     * 1. Single byte (0x00-0x7f) - use byte as is
     * 2. Short string (0-55 bytes) - prefix with 0x80 + length
     * 3. Long string (>55 bytes) - prefix with 0xb7 + length of length
     * 4. Short list (0-55 bytes) - prefix with 0xc0 + length
     * 5. Long list (>55 bytes) - prefix with 0xf7 + length of length
     */

    /**
     * @notice Encodes bytes into RLP format
     * @dev Handles the following RLP encoding cases:
     * 1. Empty byte array - encode as 0x80
     * 2. Single byte < 0x80 - use the byte as is
     * 3. Short string (0-55 bytes) - prefix with 0x80 + length
     * 4. Long string (>55 bytes) - prefix with 0xb7 + length of length, followed by length
     * @param _input The bytes to encode
     * @return output_ The RLP encoded bytes
     */
    function writeBytes(bytes memory _input) internal pure returns (bytes memory output_) {
        // Case: Empty byte array - encode as 0x80
        if (_input.length == 0) {
            output_ = abi.encodePacked(bytes1(0x80));
        } 
        // Case: Single byte (0x00-0x7f) - use as is
        else if (_input.length == 1 && _input[0] < 0x80) {
            output_ = abi.encodePacked(bytes1(_input[0]));
        } 
        // Case: Short string (0-55 bytes)
        else if (_input.length <= 55) {
            // Create prefix byte: 0x80 + length
            bytes memory lengthByte = abi.encodePacked(bytes1(uint8(0x80 + _input.length)));
            // Concatenate: prefix + actual data
            output_ = bytes.concat(lengthByte, _input);
        } 
        // Case: Long string (>55 bytes)
        else {
            // Get number of bytes needed for length
            (uint8 lengthLength, bytes memory lengthBytes) = RLPHelpers.getLengthBytes(_input);
            // Create prefix byte: 0xb7 + length of length
            bytes memory lengthLengthBytes = abi.encodePacked(bytes1(uint8(0xb7 + lengthLength)));
            // Concatenate: prefix + length bytes + actual data
            output_ = bytes.concat(lengthLengthBytes, lengthBytes, _input);
        }
        return output_;
    }

    /**
     * @notice Encodes a list of pre-encoded RLP items into an RLP list
     * @dev Handles the following RLP encoding cases:
     * 1. Empty list - encode as 0xc0
     * 2. Short list (total payload length 0-55 bytes) - prefix with 0xc0 + length
     * 3. Long list (total payload length >55 bytes) - prefix with 0xf7 + length of length, followed by length
     * @param _input The array of pre-encoded RLP items
     * @return output_ The RLP encoded list
     */
    function writeList(bytes[] memory _input) internal pure returns (bytes memory output_) {
        // Validate: all items must be valid RLP items
        for (uint256 i = 0; i < _input.length; i++) {
            if (!RLPHelpers.validateRLPItem(_input[i])) {
                revert("Invalid RLP item in input array");
            }
        }

        // Flatten array of pre-encoded items into single payload
        bytes memory flattenedPayload = RLPHelpers.getFlattenedArray(_input);

        // Case: Empty list - encode as 0xc0
        if (_input.length == 0) {
            output_ = abi.encodePacked(bytes1(0xc0));
        } 
        // Case: Short list (total payload 0-55 bytes)
        else if (flattenedPayload.length <= 55) {
            // Create prefix byte: 0xc0 + length
            bytes memory lengthByte = abi.encodePacked(bytes1(uint8(0xc0 + flattenedPayload.length)));
            // Concatenate: prefix + flattened payload
            output_ = bytes.concat(lengthByte, flattenedPayload);
        } 
        // Case: Long list (total payload >55 bytes)
        else {
            // Get number of bytes needed for payload length
            (uint8 payloadLengthLength, bytes memory payloadLengthBytes) = RLPHelpers.getLengthBytes(flattenedPayload);
            // Create prefix byte: 0xf7 + length of length
            bytes memory payloadLengthLengthBytes = abi.encodePacked(bytes1(uint8(0xf7 + payloadLengthLength)));
            // Concatenate: prefix + length bytes + flattened payload
            output_ = bytes.concat(payloadLengthLengthBytes, payloadLengthBytes, flattenedPayload);
        }
        return output_;
    }
}
