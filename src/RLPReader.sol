// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title RLPReader
 * @notice A library for decoding Recursive Length Prefix (RLP) encoded data
 * @dev Implementation of RLP decoding following the Ethereum Yellow Paper specification:
 * - Handles single bytes, strings, and nested lists
 * - Supports both short and long format decoding
 * - Includes validation of encoded data
 */
library RLPReader {
    /**
     * RLP Decoding Rules:
     * 1. Single byte (0x00-0x7f) - decoded as itself
     * 2. Short string (0x80-0xb7) - first byte - 0x80 gives length
     * 3. Long string (0xb8-0xbf) - first byte - 0xb7 gives length of length
     * 4. Short list (0xc0-0xf7) - first byte - 0xc0 gives total length
     * 5. Long list (0xf8-0xff) - first byte - 0xf7 gives length of length
     */

    /**
     * @notice Decodes a single byte value
     * @dev Handles single byte decoding (0x00-0x7f):
     * 1. Validates input byte is within valid range
     * 2. Returns byte as a single-element bytes array
     * @param _byte The byte to decode (must be <= 0x7f)
     * @return Decoded byte as a bytes array
     */
    function _decodeSingleByte(bytes1 _byte) internal pure returns (bytes memory) {
        return abi.encodePacked(_byte);
    }

    /**
     * @notice Calculates length from encoded length bytes
     * @dev Process for length calculation:
     * 1. Iterates through length bytes
     * 2. Accumulates value using big-endian encoding
     * 3. Returns final calculated length
     * @param _input The input bytes containing the length bytes
     * @param _startIndex The index where length bytes start
     * @param _lengthBytes Number of bytes used to encode the length
     * @return The calculated length value
     */
    function _calculateLength(bytes memory _input, uint256 _startIndex, uint256 _lengthBytes) internal pure returns (uint256) {
        uint256 length = 0;
        for (uint256 i = 0; i < _lengthBytes; i++) {
            length = length + (uint8(_input[_startIndex + i]) * 256 ** (_lengthBytes - 1 - i));
        }
        return length;
    }

    /**
     * @notice Creates a new bytes array with copied content
     * @dev Copy process:
     * 1. Allocates new bytes array of specified length
     * 2. Copies bytes from source to new array
     * 3. Returns the new array
     * @param _input Source bytes array
     * @param _startIndex Starting index in source array
     * @param _length Number of bytes to copy
     * @return New bytes array with copied content
     */
    function _copyBytes(bytes memory _input, uint256 _startIndex, uint256 _length) internal pure returns (bytes memory) {
        bytes memory output = new bytes(_length);
        for (uint256 i = 0; i < _length; i++) {
            output[i] = _input[_startIndex + i];
        }
        return output;
    }

    /**
     * @notice Decodes an RLP encoded string within a list
     * @dev Handles two string encoding formats:
     * 1. Short string (length < 56 bytes)
     *    - Length derived from prefix (0x80 + length)
     *    - Data follows immediately
     * 2. Long string (length >= 56 bytes)
     *    - Length of length derived from prefix (0xb7 + length of length)
     *    - Length follows prefix
     *    - Data follows length
     * @param _input The RLP encoded input
     * @param _payloadIndex Current position in the input
     * @param _prefix The RLP prefix byte
     * @param _isShortList Whether this string is part of a short list
     * @return item The decoded string
     * @return newIndex The next position to read from
     */
    function _decodeString(
        bytes memory _input,
        uint256 _payloadIndex,
        uint8 _prefix,
        bool _isShortList
    ) internal pure returns (bytes memory item, uint256 newIndex) {
        // Validate: long strings (>55 bytes) cannot be in short lists
        if (_isShortList && _prefix > 0xb7) {
            revert("Invalid RLP: short list cannot contain long string");
        }
        
        if (_prefix <= 0xb7) {
            // Case: Short string (0-55 bytes)
            uint256 strLength = _prefix - 0x80; // Calculate length from prefix
            item = _copyBytes(_input, _payloadIndex + 1, strLength); // Copy string content
            newIndex = _payloadIndex + 1 + strLength; // Move index past this string
        } 
        else {
            // Case: Long string (>55 bytes)
            uint256 lengthBytesCount = _prefix - 0xb7; // Get number of bytes used to encode length
            uint256 strLength = _calculateLength(_input, _payloadIndex + 1, lengthBytesCount); // Calculate actual length
            item = _copyBytes(_input, _payloadIndex + 1 + lengthBytesCount, strLength); // Copy string content
            newIndex = _payloadIndex + 1 + lengthBytesCount + strLength; // Move index past this string
        }
    }

    /**
     * @notice Decodes a nested RLP encoded list
     * @dev Handles two list encoding formats:
     * 1. Short list (total payload < 56 bytes)
     *    - Total length derived from prefix (0xc0 + length)
     *    - Items follow immediately
     * 2. Long list (total payload >= 56 bytes)
     *    - Length of length derived from prefix (0xf7 + length of length)
     *    - Total length follows prefix
     *    - Items follow length
     * @param _input The RLP encoded input
     * @param _payloadIndex Current position in the input
     * @param _prefix The RLP prefix byte
     * @param _isShortList Whether this list is part of a short list
     * @return item The decoded nested list payload
     * @return newIndex The next position to read from
     */
    function _decodeNestedList(
        bytes memory _input,
        uint256 _payloadIndex,
        uint8 _prefix,
        bool _isShortList
    ) internal pure returns (bytes memory item, uint256 newIndex) {
        // Validate: long lists (>55 bytes) cannot be in short lists
        if (_isShortList && _prefix > 0xf7) {
            revert("Invalid RLP: short list cannot contain long list");
        }

        uint256 nestedLength;
        uint256 prefixLength;

        if (_prefix <= 0xf7) {
            // Case: Short list (0-55 bytes)
            nestedLength = _prefix - 0xc0;  // Calculate payload length from prefix
            prefixLength = 1;  // Short list has 1-byte prefix
        } 
        else {
            // Case: Long list (>55 bytes)
            uint256 lengthBytesCount = _prefix - 0xf7;  // Get number of bytes used to encode length
            prefixLength = 1 + lengthBytesCount;  // Prefix + length bytes
            nestedLength = _calculateLength(_input, _payloadIndex + 1, lengthBytesCount);  // Calculate actual length
        }

        // Extract the nested list payload (without its prefix)
        item = _copyBytes(_input, _payloadIndex + prefixLength, nestedLength);
        // Move index past this list (prefix + length bytes + payload)
        newIndex = _payloadIndex + nestedLength + prefixLength;
    }

    /**
     * @notice Decodes RLP encoded bytes
     * @dev Handles the following encoding cases:
     * 1. Single byte (0x00-0x7f) - returned as is
     * 2. Empty byte sequence (0x80) - returns empty bytes
     * 3. Short string (0x81-0xb7) - string with length < 56 bytes
     * 4. Long string (0xb8-0xbf) - string with length >= 56 bytes
     * @param _input The RLP encoded bytes
     * @return output_ The decoded bytes
     */
    function readBytes(bytes memory _input) internal pure returns (bytes memory output_) {
        // Case 1: Single byte
        if (_input.length == 1 && _input[0] <= 0x7f) {
            output_ = _decodeSingleByte(_input[0]);
        }
        // Case 2: Empty byte sequence
        else if (_input.length == 1 && _input[0] == 0x80) {
            output_ = abi.encodePacked();
        }
        // Case 3: Short string
        else if (_input.length > 1 && _input[0] >= 0x81 && _input[0] <= 0xb7) {
            uint256 bytesLength = uint8(_input[0]) - 0x80;
            output_ = _copyBytes(_input, 1, bytesLength);
        }
        // Case 4: Long string
        else if (_input.length > 1 && _input[0] >= 0xb8 && _input[0] <= 0xbf) {
            uint256 lengthBytesCount = uint8(_input[0]) - 0xb7;
            uint256 bytesLength = _calculateLength(_input, 1, lengthBytesCount);
            output_ = _copyBytes(_input, lengthBytesCount + 1, bytesLength);
        }
    }

    /**
     * @notice Decodes RLP encoded list
     * @dev Handles two list encoding formats:
     * 1. Short list (0xc0-0xf7)
     *    - Total payload < 56 bytes
     *    - Two-pass decoding: count items, then decode each
     * 2. Long list (0xf8-0xff)
     *    - Total payload >= 56 bytes
     *    - Two-pass decoding with length prefix handling
     * @param _input The RLP encoded list
     * @return output_ Array of decoded bytes from the list
     */
    function readList(bytes memory _input) internal pure returns (bytes[] memory output_) {
        // Case 1: Short list
        if (_input.length > 1 && _input[0] >= 0xc0 && _input[0] <= 0xf7) {
            uint256 payloadLength = uint8(_input[0]) - 0xc0;
            uint256 itemCount = 0;
            uint256 payloadIndex = 1;

            // First pass: Count items by traversing the payload
            while (payloadIndex < payloadLength + 1) {
                uint8 prefix = uint8(bytes1(_input[payloadIndex]));
                
                // Handle single bytes (0x00-0x7f)
                if (prefix <= 0x7f) {
                    itemCount++;
                    payloadIndex += 1;
                } 
                // Handle strings (0x80-0xbf)
                else if (prefix >= 0x80 && prefix <= 0xbf) {
                    (,payloadIndex) = _decodeString(_input, payloadIndex, prefix, true);
                    itemCount++;
                }
                // Handle nested lists (0xc0-0xff)
                else if (prefix >= 0xc0) {
                    (,payloadIndex) = _decodeNestedList(_input, payloadIndex, prefix, true);
                    itemCount++;
                }
            }

            // Allocate array for decoded items
            output_ = new bytes[](itemCount);
            payloadIndex = 1;

            // Second pass: Decode each item
            for (uint256 i = 0; i < itemCount; i++) {
                uint8 prefix = uint8(bytes1(_input[payloadIndex]));
                
                // Decode based on prefix type
                if (prefix <= 0x7f) {
                    // Case: Single byte (0x00-0x7f) - used as is
                    output_[i] = _decodeSingleByte(_input[payloadIndex]);
                    payloadIndex += 1; // Move past this single byte
                }
                else if (prefix >= 0x80 && prefix <= 0xbf) {
                    // Case: String (0x80-0xbf) - short or long string format
                    (output_[i], payloadIndex) = _decodeString(_input, payloadIndex, prefix, true);
                }
                else if (prefix >= 0xc0) {
                    // Case: Nested list (0xc0-0xff) - short or long list format
                    (output_[i], payloadIndex) = _decodeNestedList(_input, payloadIndex, prefix, true);
                }
            }
        }
        // Case 2: Long list
        else if (_input.length > 1 && _input[0] >= 0xf8 && _input[0] <= 0xff) {
            // Calculate payload details for long list
            uint256 listLengthLength = uint8(_input[0]) - 0xf7;
            uint256 payloadLength = _calculateLength(_input, 1, listLengthLength);
            uint256 payloadStartIndex = listLengthLength + 1;
            
            uint256 itemCount = 0;
            uint256 payloadIndex = payloadStartIndex;

            // First pass: Count items in long list
            while (payloadIndex < payloadStartIndex + payloadLength) {
                uint8 prefix = uint8(bytes1(_input[payloadIndex]));
                
                if (prefix <= 0x7f) {
                    // Case: Single byte (0x00-0x7f) - count and advance by 1
                    itemCount++;
                    payloadIndex += 1;
                }
                else if (prefix >= 0x80 && prefix <= 0xbf) {
                    // Case: String (0x80-0xbf) - decode and update position
                    (,payloadIndex) = _decodeString(_input, payloadIndex, prefix, false);
                    itemCount++;
                }
                else if (prefix >= 0xc0) {
                    // Case: Nested list (0xc0-0xff) - decode and update position
                    (,payloadIndex) = _decodeNestedList(_input, payloadIndex, prefix, false);
                    itemCount++;
                }
            }

            // Allocate array for decoded items
            output_ = new bytes[](itemCount);
            payloadIndex = payloadStartIndex;

            // Second pass: Decode items in long list
            for (uint256 i = 0; i < itemCount; i++) {
                uint8 prefix = uint8(bytes1(_input[payloadIndex])); // Extract prefix byte
                
                if (prefix <= 0x7f) {
                    // Case: Single byte (0x00-0x7f) - decode directly
                    output_[i] = _decodeSingleByte(_input[payloadIndex]);
                    payloadIndex += 1;
                }
                else if (prefix >= 0x80 && prefix <= 0xbf) {
                    // Case: String (0x80-0xbf) - decode string and update position
                    (output_[i], payloadIndex) = _decodeString(_input, payloadIndex, prefix, false);
                }
                else if (prefix >= 0xc0) {
                    // Case: Nested list (0xc0-0xff) - decode nested list and update position
                    (output_[i], payloadIndex) = _decodeNestedList(_input, payloadIndex, prefix, false);
                }
            }
        }
    }
}
