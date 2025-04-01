// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title RLPHelpers
 * @notice Utility library providing helper functions for RLP implementations
 * @dev Helper functions for RLP encoding and decoding operations:
 * - Length calculation for RLP encoding
 * - Byte array manipulation and validation
 * - Array flattening for list operations
 * - Validation of RLP-encoded items
 */
library RLPHelpers {
    /**
     * @notice Extracts minimal bytes needed to represent a length value for RLP encoding
     * @dev Used for encoding lengths in two scenarios:
     * 1. Long strings (>55 bytes) - prefix 0xb7 + length of length
     * 2. Long lists (>55 bytes) - prefix 0xf7 + length of length
     * Process:
     * - Converts length to bytes32
     * - Finds first significant byte
     * - Returns minimal byte representation
     * @param bytesInput Input byte array whose length needs to be encoded
     * @return lengthLength Number of bytes needed (for calculating prefix offset)
     * @return lengthBytes Minimal bytes representing the length
     */
    function getLengthBytes(bytes memory bytesInput) internal pure returns (uint8, bytes memory) {
        // Convert length to bytes32 for efficient byte operations
        bytes32 inputLengthBytes = bytes32(bytesInput.length);

        // Find first significant byte to determine minimal byte count
        uint8 lengthLength = 0;
        for (uint8 i = 0; i < 32; i++) {
            // If byte is not zero, we've found the first significant byte
            if (inputLengthBytes[i] > 0) {
                lengthLength = 32 - i;
                break;
            }
        }

        // Allocate array for significant bytes only
        bytes memory lengthBytes = new bytes(lengthLength);

        // Assembly: shift and store only significant bytes
        assembly {
            // Skip 32-byte length prefix in memory layout
            // Shift left to remove leading zeros, moving only significant bytes
            // Shift amount: (32-lengthLength) * 8 bits positions the bytes correctly
            mstore(add(lengthBytes, 32), shl(mul(sub(32, lengthLength), 8), inputLengthBytes))
        }

        return (lengthLength, lengthBytes);
    }

    /**
     * @notice Concatenates an array of RLP-encoded items into a single payload
     * @dev Combines pre-encoded items for list encoding:
     * 1. Takes an array of valid RLP-encoded items
     * 2. Concatenates them in sequence
     * 3. Returns combined payload ready for list prefix
     * @param array Array of RLP-encoded items to concatenate
     * @return flattenedArray Combined payload of all items in sequence
     */
    function getFlattenedArray(bytes[] memory array) internal pure returns (bytes memory) {
        // Initialize empty bytes for concatenation
        bytes memory flattenedArray;

        // Concatenate each RLP-encoded item in sequence
        for (uint256 i = 0; i < array.length; i++) {
            flattenedArray = abi.encodePacked(flattenedArray, array[i]);
        }

        return flattenedArray;
    }

    /**
     * @notice Validates that a byte array follows RLP encoding rules
     * @dev Validates RLP-encoded items according to the following rules:
     * 1. Single bytes (0x00-0x7f) - encoded as is
     * 2. Short strings (0-55 bytes) - prefix 0x80 + length
     * 3. Long strings (>55 bytes) - prefix 0xb7 + length of length
     * 4. Short lists (0-55 bytes) - prefix 0xc0 + length
     * 5. Long lists (>55 bytes) - prefix 0xf7 + length of length
     * @param item RLP-encoded byte array to validate
     * @return bool True if valid, reverts with specific reason if invalid
     */
    function validateRLPItem(bytes memory item) internal pure returns (bool) {
        // Validate: empty arrays must be encoded as 0x80
        if (item.length == 0) {
            revert("Invalid RLP item: empty byte array should be encoded as 0x80");
        }

        // Extract prefix byte to determine type and length
        uint8 firstByte = uint8(item[0]);

        // Case: Single byte (0x00-0x7f)
        if (item.length == 1 && firstByte < 0x80) {
            return true;
        }

        // Case: Short string (0-55 bytes)
        if (firstByte >= 0x80 && firstByte <= 0xb7) {
            uint256 length = firstByte - 0x80;
            // Validate: empty string must be exactly 0x80
            if (length == 0) {
                if (item.length > 1) {
                    revert("Invalid RLP item: incorrect length for short string");
                }
            }
            // Validate: content length must match prefix-encoded length
            else if (item.length != length + 1) {
                revert("Invalid RLP item: incorrect length for short string");
            }
            return true;
        }

        // Case: Long string (>55 bytes)
        if (firstByte >= 0xb8 && firstByte <= 0xbf) {
            uint256 lengthOfLength = firstByte - 0xb7;
            // Validate: must have enough bytes for length value
            if (item.length < lengthOfLength + 1) {
                revert("Invalid RLP item: insufficient bytes");
            }

            // Calculate actual string length from length bytes
            uint256 length = 0;
            for (uint256 i = 1; i <= lengthOfLength; i++) {
                length = length * 256 + uint8(item[i]);
            }

            // Validate: total length must match (prefix + length bytes + content)
            if (item.length != lengthOfLength + length + 1) {
                revert("Invalid RLP item: incorrect length for long string");
            }

            return true;
        }

        // Case: Lists (short: 0xc0-0xf7, long: 0xf8-0xff)
        if (firstByte >= 0xc0 && firstByte <= 0xff) {
            // Case: Short list (0-55 bytes)
            if (firstByte <= 0xf7) {
                uint256 listLength = firstByte - 0xc0;
                // Validate: empty list must be exactly 0xc0
                if (firstByte == 0xc0 && item.length > 1) {
                    revert("Invalid RLP: empty list should be encoded as 0xc0 only");
                }
                // Validate: content length must match prefix-encoded length
                else if (firstByte != 0xc0 && item.length != listLength + 1) {
                    revert("Invalid RLP: incorrect length for short list");
                }
            }
            // Case: Long list (>55 bytes)
            else {
                uint256 lengthOfLength = firstByte - 0xf7;
                // Validate: must have enough bytes for length value
                if (item.length < lengthOfLength + 1) {
                    revert("Invalid RLP: insufficient bytes for long list length");
                }

                // Calculate actual list length from length bytes
                uint256 listLength = 0;
                for (uint256 i = 1; i <= lengthOfLength; i++) {
                    listLength = listLength * 256 + uint8(item[i]);
                }

                // Validate: total length must match (prefix + length bytes + content)
                if (item.length != 1 + lengthOfLength + listLength) {
                    revert("Invalid RLP: incorrect length for long list");
                }
            }
            return true;
        }

        return false;
    }
}
