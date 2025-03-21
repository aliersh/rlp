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
}
