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
     * @dev Internal helper to decode a single byte
     */
    function _decodeSingleByte(bytes1 _byte) internal pure returns (bytes memory) {
        return abi.encodePacked(_byte);
    }

    /**
     * @dev Internal helper to calculate length from length bytes
     */
    function _calculateLength(bytes memory _input, uint256 _startIndex, uint256 _lengthBytes) internal pure returns (uint256) {
        uint256 length = 0;
        for (uint256 i = 0; i < _lengthBytes; i++) {
            length = length + (uint8(_input[_startIndex + i]) * 256 ** (_lengthBytes - 1 - i));
        }
        return length;
    }

    /**
     * @dev Internal helper to copy bytes to a new array
     */
    function _copyBytes(bytes memory _input, uint256 _startIndex, uint256 _length) internal pure returns (bytes memory) {
        bytes memory output = new bytes(_length);
        for (uint256 i = 0; i < _length; i++) {
            output[i] = _input[_startIndex + i];
        }
        return output;
    }

    /**
     * @dev Internal helper to handle string decoding in lists
     */
    function _decodeString(
        bytes memory _input,
        uint256 _payloadIndex,
        uint8 _prefix,
        bool _isShortList
    ) internal pure returns (bytes memory item, uint256 newIndex) {
        if (_isShortList && _prefix > 0xb7) {
            revert("Invalid RLP: short list cannot contain long string");
        }
        
        if (_prefix <= 0xb7) {
            uint256 strLength = _prefix - 0x80;
            item = _copyBytes(_input, _payloadIndex + 1, strLength);
            newIndex = _payloadIndex + 1 + strLength;
        } else {
            uint256 lengthBytesCount = _prefix - 0xb7;
            uint256 strLength = _calculateLength(_input, _payloadIndex + 1, lengthBytesCount);
            item = _copyBytes(_input, _payloadIndex + 1 + lengthBytesCount, strLength);
            newIndex = _payloadIndex + 1 + lengthBytesCount + strLength;
        }
    }

    /**
     * @dev Internal helper to handle nested list decoding
     */
    function _decodeNestedList(
        bytes memory _input,
        uint256 _payloadIndex,
        uint8 _prefix,
        bool _isShortList
    ) internal pure returns (bytes memory item, uint256 newIndex) {
        if (_isShortList && _prefix > 0xf7) {
            revert("Invalid RLP: short list cannot contain long list");
        }

        uint256 nestedLength;
        uint256 prefixLength;

        if (_prefix <= 0xf7) {
            nestedLength = _prefix - 0xc0;
            prefixLength = 1;
        } else {
            uint256 lengthBytesCount = _prefix - 0xf7;
            prefixLength = 1 + lengthBytesCount;
            nestedLength = _calculateLength(_input, _payloadIndex + 1, lengthBytesCount);
        }

        item = _copyBytes(_input, _payloadIndex + prefixLength, nestedLength);
        newIndex = _payloadIndex + nestedLength + prefixLength;
    }

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
            output_ = _decodeSingleByte(_input[0]);
        }

        // Case 2: Prefix is 0x80 - return empty bytes
        else if (_input.length == 1 && _input[0] == 0x80) {
            output_ = abi.encodePacked();
        }
        
        // Case 3: Prefix is between 0x81 and 0xb7 - short string (length < 56 bytes, prefix encodes length)
        else if (_input.length > 1 && _input[0] >= 0x81 && _input[0] <= 0xb7) {
            uint256 bytesLength = uint8(_input[0]) - 0x80;
            output_ = _copyBytes(_input, 1, bytesLength);
        }

        // Case 4: Prefix is between 0xb8 and 0xbf - long string (length >= 56 bytes, prefix followed by length bytes)
        else if (_input.length > 1 && _input[0] >= 0xb8 && _input[0] <= 0xbf) {
            uint256 lengthBytesCount = uint8(_input[0]) - 0xb7;
            uint256 bytesLength = _calculateLength(_input, 1, lengthBytesCount);
            output_ = _copyBytes(_input, lengthBytesCount + 1, bytesLength);
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
        // Case 1: Short list (0xc0-0xf7)
        if (_input.length > 1 && _input[0] >= 0xc0 && _input[0] <= 0xf7) {
            uint256 payloadLength = uint8(_input[0]) - 0xc0;
            uint256 itemCount = 0;
            uint256 payloadIndex = 1;

            // First pass: count items
            while (payloadIndex < payloadLength + 1) {
                uint8 prefix = uint8(bytes1(_input[payloadIndex]));
                
                if (prefix <= 0x7f) {
                    itemCount++;
                    payloadIndex += 1;
                } 
                else if (prefix >= 0x80 && prefix <= 0xbf) {
                    (,payloadIndex) = _decodeString(_input, payloadIndex, prefix, true);
                    itemCount++;
                }
                else if (prefix >= 0xc0) {
                    (,payloadIndex) = _decodeNestedList(_input, payloadIndex, prefix, true);
                    itemCount++;
                }
            }

            output_ = new bytes[](itemCount);
            payloadIndex = 1;

            // Second pass: decode items
            for (uint256 i = 0; i < itemCount; i++) {
                uint8 prefix = uint8(bytes1(_input[payloadIndex]));
                
                if (prefix <= 0x7f) {
                    output_[i] = _decodeSingleByte(_input[payloadIndex]);
                    payloadIndex += 1;
                }
                else if (prefix >= 0x80 && prefix <= 0xbf) {
                    (output_[i], payloadIndex) = _decodeString(_input, payloadIndex, prefix, true);
                }
                else if (prefix >= 0xc0) {
                    (output_[i], payloadIndex) = _decodeNestedList(_input, payloadIndex, prefix, true);
                }
            }
        }
        // Case 2: Long list (0xf8-0xff)
        else if (_input.length > 1 && _input[0] >= 0xf8 && _input[0] <= 0xff) {
            uint256 listLengthLength = uint8(_input[0]) - 0xf7;
            uint256 payloadLength = _calculateLength(_input, 1, listLengthLength);
            uint256 payloadStartIndex = listLengthLength + 1;
            
            uint256 itemCount = 0;
            uint256 payloadIndex = payloadStartIndex;

            // First pass: count items
            while (payloadIndex < payloadStartIndex + payloadLength) {
                uint8 prefix = uint8(bytes1(_input[payloadIndex]));
                
                if (prefix <= 0x7f) {
                    itemCount++;
                    payloadIndex += 1;
                }
                else if (prefix >= 0x80 && prefix <= 0xbf) {
                    (,payloadIndex) = _decodeString(_input, payloadIndex, prefix, false);
                    itemCount++;
                }
                else if (prefix >= 0xc0) {
                    (,payloadIndex) = _decodeNestedList(_input, payloadIndex, prefix, false);
                    itemCount++;
                }
            }

            output_ = new bytes[](itemCount);
            payloadIndex = payloadStartIndex;

            // Second pass: decode items
            for (uint256 i = 0; i < itemCount; i++) {
                uint8 prefix = uint8(bytes1(_input[payloadIndex]));
                
                if (prefix <= 0x7f) {
                    output_[i] = _decodeSingleByte(_input[payloadIndex]);
                    payloadIndex += 1;
                }
                else if (prefix >= 0x80 && prefix <= 0xbf) {
                    (output_[i], payloadIndex) = _decodeString(_input, payloadIndex, prefix, false);
                }
                else if (prefix >= 0xc0) {
                    (output_[i], payloadIndex) = _decodeNestedList(_input, payloadIndex, prefix, false);
                }
            }
        }
    }
}
