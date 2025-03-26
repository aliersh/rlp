// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RLPHelpers} from "./utils/RLPHelpers.sol";

/**
 * @title RLPWriter
 * @notice Library for encoding data in Recursive Length Prefix (RLP) format.
 * @dev Library for encoding data in Recursive Length Prefix (RLP) format.
 * RLP is the main encoding method used to serialize objects in Ethereum.
 * This implementation follows the RLP specification as defined in the Ethereum Yellow Paper.
 */
library RLPWriter {
    /**
     * @notice Encodes bytes into RLP format
     * @dev Handles four different RLP encoding cases:
     *      1. Empty byte array - encode as 0x80
     *      2. Single byte < 0x80 - use the byte as is
     *      3. Short string (0-55 bytes) - prefix with 0x80 + length
     *      4. Long string (>55 bytes) - prefix with 0xb7 + length of length, followed by length
     * @param _input The bytes to encode
     * @return output_ The RLP encoded bytes
     */
    function writeBytes(bytes memory _input) internal pure returns (bytes memory output_) {
        // Case 1: Empty byte array - encode as 0x80
        if (_input.length == 0) {
            output_ = abi.encodePacked(bytes1(0x80));
        } 
        // Case 2: Single byte < 0x80 - use the byte as is
        else if (_input.length == 1 && _input[0] < 0x80) {
            output_ = abi.encodePacked(bytes1(_input[0]));
        } 
        // Case 3: Short string (0-55 bytes) - prefix with 0x80 + length
        else if (_input.length <= 55) {
            bytes memory lengthByte = abi.encodePacked(bytes1(uint8(0x80 + _input.length)));
            output_ = bytes.concat(lengthByte, _input);
        } 
        // Case 4: Long string (>55 bytes) - prefix with 0xb7 + length of length, followed by length
        else {
            // Get the bytes representation of the length using the helper function
            (uint8 lengthLength, bytes memory lengthBytes) = RLPHelpers.getLengthBytes(_input);
            // Create the prefix byte: 0xb7 + length of the length bytes
            bytes memory lengthLengthBytes = abi.encodePacked(bytes1(uint8(0xb7 + lengthLength)));
            // Concatenate: prefix + length bytes + actual data
            output_ = bytes.concat(lengthLengthBytes, lengthBytes, _input);
        }
        return output_;
    }

    /**
     * @notice Encodes a list of pre-encoded RLP items into an RLP list
     * @dev Takes pre-encoded RLP items (including nested lists) and wraps them in a list
     *      structure. Each element in the input must already be properly RLP encoded.
     *      This naturally supports nested lists since they will already be encoded in the input.
     * @param _input The array of pre-encoded RLP items
     * @return output_ The RLP encoded list
     */
    function writeList(bytes[] memory _input) internal pure returns (bytes memory output_) {
        // Validate that all items in the input are valid RLP items
        for (uint256 i = 0; i < _input.length; i++) {
            if (!RLPHelpers.validateRLPItem(_input[i])) {
                revert("Invalid RLP item in input array");
            }
        }

        // Flatten the array of pre-encoded items
        bytes memory flattenedPayload = RLPHelpers.getFlattenedArray(_input);

        // Case 1: Empty list - encode as 0xc0
        if (_input.length == 0) {
            output_ = abi.encodePacked(bytes1(0xc0));
        } 
        // Case 2: Short list (total payload length 0-55 bytes) - prefix with 0xc0 + length
        else if (flattenedPayload.length <= 55) {
            bytes memory lengthByte = abi.encodePacked(bytes1(uint8(0xc0 + flattenedPayload.length)));
            output_ = bytes.concat(lengthByte, flattenedPayload);
        } 
        // Case 3: Long list (total payload length >55 bytes) - prefix with 0xf7 + length of length, followed by length
        else {
            // Get the bytes representation of the payload length
            (uint8 payloadLengthLength, bytes memory payloadLengthBytes) = RLPHelpers.getLengthBytes(flattenedPayload);
            // Create the prefix byte: 0xf7 + length of the length bytes
            bytes memory payloadLengthLengthBytes = abi.encodePacked(bytes1(uint8(0xf7 + payloadLengthLength)));
            // Concatenate: prefix + length bytes + flattened payload
            output_ = bytes.concat(payloadLengthLengthBytes, payloadLengthBytes, flattenedPayload);
        }
        return output_;
    }
}
