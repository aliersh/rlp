// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./utils/RLPHelpers.sol";

/**
 * @title RLPWriter
 * @dev Library for encoding data in Recursive Length Prefix (RLP) format.
 * RLP is the main encoding method used to serialize objects in Ethereum.
 * This implementation follows the RLP specification as defined in the Ethereum Yellow Paper.
 */
library RLPWriter {
    /**
     * @dev Encodes bytes into RLP format
     * @param _input The bytes to encode
     * @return output_ The RLP encoded bytes
     *
     * RLP encoding follows these rules:
     * 1. For a single byte with value < 0x80, the byte itself is its own RLP encoding
     * 2. For a string 0-55 bytes long, the RLP encoding is: [0x80 + length] + string
     * 3. For a string >55 bytes long, the RLP encoding is: [0xb7 + length of length] + [length] + string
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
     * @dev Encodes a list of byte arrays into RLP format
     * @param _input The array of byte arrays to encode
     * @return output_ The RLP encoded list
     *
     * RLP encoding for lists follows these rules:
     * 1. For a list with total payload length 0-55 bytes, the RLP encoding is: [0xc0 + length] + concatenated RLP encodings
     * 2. For a list with total payload length >55 bytes, the RLP encoding is: [0xf7 + length of length] + [length] + concatenated RLP encodings
     */
    function writeList(bytes[] memory _input) internal pure returns (bytes memory output_) {
        // First encode each item in the list
        bytes[] memory payload = new bytes[](_input.length);

        for (uint256 i = 0; i < _input.length; i++) {
            payload[i] = writeBytes(_input[i]);
        }

        // Flatten the array of encoded items
        bytes memory flattenedPayload = RLPHelpers.flattenArray(payload);

        // Case 1: Empty list - encode as 0xc0
        if (payload.length == 0) {
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
