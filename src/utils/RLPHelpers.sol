// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title RLPHelpers
 * @notice Library for working with Ethereum's Recursive Length Prefix (RLP) encoding
 * @dev RLP is the main encoding method used to serialize objects in Ethereum.
 * This library provides helper functions for RLP encoding and decoding operations.
 */
library RLPHelpers {
    /**
     * @notice Extracts the length bytes from an input byte array
     * @dev This function is used in RLP encoding to determine how many bytes are needed to represent the length of the input data, and to extract those bytes.
     * In RLP, different prefixes are used based on the length of the data.
     * @param bytesInput The input byte array to process
     * @return lengthLength The number of bytes needed to represent the length
     * @return lengthBytes The bytes representing the length
     */
    function getLengthBytes(bytes memory bytesInput) internal pure returns (uint8, bytes memory) {
        // Convert the uint hex value of bytesInput.length to bytes32 for easier byte-by-byte access
        bytes32 inputLengthBytes = bytes32(bytesInput.length);

        // Iterate from left to right until we find the first non-zero byte
        // This determines how many bytes are actually needed to represent the length
        uint8 lengthLength = 0;
        for (uint8 i = 0; i < 32; i++) {
            if (inputLengthBytes[i] > 0) {
                lengthLength = 32 - i;
                break;
            }
        }

        // Create a new byte array with exactly the number of bytes needed to represent the length
        bytes memory lengthBytes = new bytes(lengthLength);
        
        // Use assembly to efficiently copy only the necessary bytes from inputLengthBytes to lengthBytes
        // This avoids having to loop through each byte individually
        assembly {
            // Shift the bytes left to align them properly and store in the new array
            // This is equivalent to taking just the significant bytes from inputLengthBytes
            mstore(add(lengthBytes, 32), shl(mul(sub(32, lengthLength), 8), inputLengthBytes))
        }

        return (lengthLength, lengthBytes);
    }

    /**
     * @notice Concatenates an array of byte arrays into a single byte array
     * @dev This function is useful in RLP encoding when multiple encoded items need to be combined into a single byte array, such as when encoding a list of items.
     * @param array The array of byte arrays to flatten
     * @return flattenedArray A single byte array containing all elements concatenated in order
     */
    function getFlattenedArray(bytes[] memory array) internal pure returns (bytes memory) {
        bytes memory flattenedArray;
        for (uint256 i = 0; i < array.length; i++) {
            flattenedArray = abi.encodePacked(flattenedArray, array[i]);
        }
        return flattenedArray;
    }

    /**
     * @notice Validates that a byte array follows RLP encoding rules
     * @dev Checks if the provided byte array is a valid RLP encoded item by verifying:
     *      1. Single bytes (0x00-0x7f) are encoded as themselves
     *      2. Short strings (0-55 bytes) start with 0x80 + length
     *      3. Long strings (>55 bytes) start with 0xb7 + length of length
     *      4. Short lists (0-55 bytes) start with 0xc0 + length
     *      5. Long lists (>55 bytes) start with 0xf7 + length of length
     * @param item The RLP encoded byte array to validate
     * @return bool Returns true if the item is valid RLP, reverts otherwise
     */
    function validateRLPItem(bytes memory item) internal pure returns (bool) {
        // Empty byte arrays should be encoded as 0x80
        if (item.length == 0) {
            revert("Invalid RLP item: empty byte array should be encoded as 0x80");
        }

        // Get the first byte which determines the type and length of the item
        uint8 firstByte = uint8(item[0]);

        // Case 1: Single byte < 0x80 is encoded as itself
        if (item.length == 1 && firstByte < 0x80) {
            return true;
        }

        // Case 2: Short string (0-55 bytes)
        // Prefix: 0x80 + length of the string
        if (firstByte >= 0x80 && firstByte <= 0xb7) {
            uint256 length = firstByte - 0x80;
            // Special case: empty string should be encoded as 0x80 only
            if (length == 0) {
                if (item.length > 1) {
                    revert("Invalid RLP item: incorrect length for short string");
                }
            } 
            // Regular case: verify total length matches prefix
            else if (item.length != length + 1) {
                revert("Invalid RLP item: incorrect length for short string");
            }
            return true;
        }

        // Case 3: Long string (>55 bytes)
        // Prefix: 0xb7 + length of the length
        if (firstByte >= 0xb8 && firstByte <= 0xbf) {
            uint256 lengthOfLength = firstByte - 0xb7;
            // Check if we have enough bytes to read the length
            if (item.length < lengthOfLength + 1) {
                revert("Invalid RLP item: insufficient bytes");
            }

            // Calculate the actual length from the length bytes
            uint256 length = 0;
            for (uint256 i = 1; i <= lengthOfLength; i++) {
                length = length * 256 + uint8(item[i]);
            }

            // Verify total length matches: prefix byte + length bytes + content
            if (item.length != lengthOfLength + length + 1) {
                revert("Invalid RLP item: incorrect length for long string");
            }
            
            return true;
        }
        
        // Case 4 & 5: Lists (short: 0xc0-0xf7, long: 0xf8-0xff)
        if (firstByte >= 0xc0 && firstByte <= 0xff) {
            // Case 4: Short list (total payload 0-55 bytes)
            if (firstByte <= 0xf7) {
                uint256 listLength = firstByte - 0xc0;
                // Special case: empty list should be encoded as 0xc0 only
                if (firstByte == 0xc0 && item.length > 1) {
                    revert("Invalid RLP: empty list should be encoded as 0xc0 only");
                } 
                // Regular case: verify total length matches prefix
                else if (firstByte != 0xc0 && item.length != listLength + 1) {
                    revert("Invalid RLP: incorrect length for short list");
                }
            }
            // Case 5: Long list (total payload >55 bytes)
            else {
                uint256 lengthOfLength = firstByte - 0xf7;
                // Check if we have enough bytes to read the length
                if (item.length < lengthOfLength + 1) {
                    revert("Invalid RLP: insufficient bytes for long list length");
                }
                
                // Calculate the actual length from the length bytes
                uint256 listLength = 0;
                for (uint256 i = 1; i <= lengthOfLength; i++) {
                    listLength = listLength * 256 + uint8(item[i]);
                }
                
                // Verify total length matches: prefix byte + length bytes + content
                if (item.length != 1 + lengthOfLength + listLength) {
                    revert("Invalid RLP: incorrect length for long list");
                }
            }
            return true;
        }
        // This return is never reached as all byte values are covered above
        return false;
    }
}
