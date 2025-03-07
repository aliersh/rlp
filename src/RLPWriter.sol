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
}
