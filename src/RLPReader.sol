// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title RLPReader
 * @notice A library for decoding Recursive Length Prefix (RLP) encoded data
 * @dev RLP is the main encoding method used to serialize objects in Ethereum.
 *      This library provides functions to decode RLP encoded bytes and lists.
 *      Implementation follows the RLP specification as defined in the Ethereum Yellow Paper.
 */
library RLPReader {
    /**
     * @notice Decodes RLP encoded bytes
     * @dev Handles four different RLP encoding cases:
     *      1. Single byte (0x00-0x7f) - returned as is
     *      2. Empty byte sequence (0x80) - returns empty bytes
     *      3. Short string (0x81-0xb7) - string with length < 56 bytes
     *      4. Long string (0xb8-0xbf) - string with length >= 56 bytes
     * @param _input The RLP encoded bytes
     * @return output_ The decoded bytes
     */
    function readBytes(bytes memory _input) internal pure returns (bytes memory output_) {
        // Case 1: Prefix between 0x00 and 0x7f - return the byte as is
        if (_input.length == 1 && _input[0] <= 0x7f) {
            output_ = abi.encodePacked(bytes1(_input[0]));
        }

        // Case 2: Prefix is 0x80 - return empty bytes
        else if (_input.length == 1 && _input[0] == 0x80) {
            output_ = abi.encodePacked();
        }
        
        // Case 3: Prefix is between 0x81 and 0xb7 - short string (length < 56 bytes, prefix encodes length)
        else if (_input.length > 1 && _input[0] >= 0x81 && _input[0] <= 0xb7) {
            // Get the length of the string
            uint256 bytesLength = uint8(_input[0]) - 0x80;

            // Create a new bytes array with the length of the bytes
            output_ = new bytes(bytesLength);

            // Copy the bytes after the prefix to the new array
            for (uint256 i = 1; i <= bytesLength ; i++) {
                output_[i - 1] = _input[i];
            }
            return output_;
        }

        // Case 4: Prefix is between 0xb8 and 0xbf - long string (length >= 56 bytes, prefix followed by length bytes)
        else if (_input.length > 1 && _input[0] >= 0xb8 && _input[0] <= 0xbf) {
            // Get the length of the length of the bytes
            uint256 bytesLengthLength = uint8(_input[0]) - 0xb7;

            // Get the length of the bytes
            uint256 bytesLength = 0;
            for (uint256 i = 1; i <= bytesLengthLength; i++) {
                bytesLength = bytesLength + (uint8(_input[i]) * 256 ** (bytesLengthLength - i)); //byte sequence to decimal big endian formula
            }

            // Create a new bytes array with the length of the bytes
            output_ = new bytes(bytesLength);

            // Copy the bytes after the prefix and length bytes to the new array (adjusting indices to skip header)
            for (uint256 i = bytesLengthLength + 1; i < bytesLengthLength + bytesLength + 1; i++) {
                output_[i - bytesLengthLength - 1] = _input[i];
            }
            return output_;
        }
    }

    /**
     * @notice Decodes RLP encoded list
     * @dev Handles two different RLP list encoding cases:
     *      1. Short list (0xc0-0xf7) - list with total payload < 56 bytes
     *      2. Long list (0xf8-0xff) - list with total payload >= 56 bytes
     * @param _input The RLP encoded list
     * @return output_ Array of decoded bytes from the list
     */
    function readList(bytes memory _input) internal pure returns (bytes[] memory output_) {
        // Case 1: Prefix is between 0xc0 and 0xf7 - short list (total payload < 56 bytes, prefix encodes length)
        if (_input.length > 1 && _input[0] >= 0xc0 && _input[0] <= 0xf7) {

            // Get the length of the list
            uint256 listLength = uint8(_input[0]) - 0xc0;

            // Create a new array to temporarily hold each encoded item before decoding
            bytes[] memory encodedList = new bytes[](listLength);

            // Copy the bytes after the prefix to the new array
            for (uint256 i = 1; i < listLength + 1; i++) {
                encodedList[i - 1] = abi.encodePacked(_input[i]);
            }

            // Decode the list
            for (uint256 i = 0; i < listLength; i++) {
                output_[i] = readBytes(encodedList[i]);
            }
            return output_;
        }

        // Case 2: Prefix is between 0xf8 and 0xff - long list (total payload >= 56 bytes, prefix followed by length bytes)
        else if (_input.length > 1 && _input[0] >= 0xf8 && _input[0] <= 0xff) {
            // Get the length of the length of the list
            uint256 listLengthLength = uint8(_input[0]) - 0xf7;

            // Get the length of the list
            uint256 listLength = 0;
            for (uint256 i = 1; i <= listLengthLength; i++) {
                listLength = listLength + (uint8(_input[i]) * 256 ** (listLengthLength - i)); // byte sequence to decimal big endian formula
            }

            // Create a new array to temporarily hold each encoded item before decoding
            bytes[] memory encodedList = new bytes[](listLength);

            // Copy the bytes after the prefix to the new array
            for (uint256 i = listLengthLength + 1; i < listLengthLength + listLength + 1; i++) {
                encodedList[i - listLengthLength - 1] = abi.encodePacked(_input[i]);
            }

            // Decode the list
            for (uint256 i = 0; i < listLength; i++) {
                output_[i] = readBytes(encodedList[i]);
            }
            return output_;
        }
    }
}
