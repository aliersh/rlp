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
            // Calculate the total payload length by subtracting the list prefix offset
            uint256 payloadLength = uint8(_input[0]) - 0xc0;

            // Count the number of items in the list using a first pass
            uint256 itemCount = 0;
            uint256 payloadIndex = 1;

            // First pass: count items by traversing the payload once
            while (payloadIndex < payloadLength + 1) {
                uint8 prefix = uint8(bytes1(_input[payloadIndex]));
                
                // Handle single byte case (0x00-0x7f) - byte is its own RLP encoding
                if (prefix <= 0x7f) {
                    itemCount++;
                    payloadIndex += 1; // Move past this single byte
                } 
                // Handle string case (0x80-0xbf) - length is encoded in the prefix
                else if (prefix >= 0x80 && prefix <= 0xbf) {
                    uint256 itemLength = prefix - 0x80;
                    itemCount++;
                    payloadIndex += 1 + itemLength; // Skip prefix byte + content bytes
                }
                // Missing support for nested lists
                else {
                    revert("Unsupported item type in list");
                }
            }

            // Allocate memory for the output array
            output_ = new bytes[](itemCount);
            
            // Reset index for second pass to decode actual items
            payloadIndex = 1;

            // Second pass: decode each item and store in output array
            for (uint256 i = 0; i < itemCount; i++) {
                uint8 prefix = uint8(bytes1(_input[payloadIndex]));
                
                // Handle single byte case (0x00-0x7f) - byte is its own RLP encoding
                if (prefix <= 0x7f) {
                    output_[i] = new bytes(1);
                    output_[i][0] = _input[payloadIndex];
                    payloadIndex += 1;
                }
                // Handle string case (0x80-0xbf) - extract content bytes
                else if (prefix >= 0x80 && prefix <= 0xbf) {
                    uint256 itemLength = prefix - 0x80;
                    bytes memory packedItem = new bytes(itemLength);
                    for (uint256 j = 0; j < itemLength; j++) {
                        packedItem[j] = _input[payloadIndex + 1 + j];
                    }
                    output_[i] = packedItem;
                    payloadIndex += 1 + itemLength; // Skip prefix byte + content bytes
                }
                // Missing support for nested lists (consistency with first pass)
                else {
                    revert("Unsupported item type in list");
                }
            }

            return output_;
        }

        // Case 2: Prefix is between 0xf8 and 0xff - long list (total payload >= 56 bytes, prefix followed by length bytes)
        else if (_input.length > 1 && _input[0] >= 0xf8 && _input[0] <= 0xff) {
            // Get the length of the length of the list
            uint256 listLengthLength = uint8(_input[0]) - 0xf7;

            // Get the length of the list payload
            uint256 payloadLength = 0;
            for (uint256 i = 1; i <= listLengthLength; i++) {
                payloadLength = payloadLength + (uint8(_input[i]) * 256 ** (listLengthLength - i)); // byte sequence to decimal big endian formula
            }

            // Determine starting index for the payload (after prefix and length bytes)
            uint256 payloadStartIndex = listLengthLength + 1;
            
            // Count the number of items in the list using a first pass
            uint256 itemCount = 0;
            uint256 payloadIndex = payloadStartIndex;

            // First pass: count items by traversing the payload once
            while (payloadIndex < payloadStartIndex + payloadLength) {
                uint8 prefix = uint8(bytes1(_input[payloadIndex]));
                
                // Handle single byte case (0x00-0x7f) - byte is its own RLP encoding
                if (prefix <= 0x7f) {
                    itemCount++;
                    payloadIndex += 1; // Move past this single byte
                } 
                // Handle string case (0x80-0xbf) - length is encoded in the prefix
                else if (prefix >= 0x80 && prefix <= 0xbf) {
                    if (prefix <= 0xb7) {
                        uint256 strLength = prefix - 0x80;
                        itemCount++;
                        payloadIndex += 1 + strLength; // Skip prefix byte + content bytes
                    } else {
                        uint256 lengthBytesCount = prefix - 0xb7;
                        uint256 strLength = 0;
                        for (uint256 i = 1; i <= lengthBytesCount; i++) {
                            strLength = strLength + (uint8(_input[payloadIndex + i]) * 256 ** (lengthBytesCount - i));
                        }
                        itemCount++;
                        payloadIndex += 1 + lengthBytesCount + strLength;
                    }
                }
                // Missing support for nested lists
                else {
                    revert("Unsupported item type in list");
                }
            }

            // Allocate memory for the output array
            output_ = new bytes[](itemCount);
            
            // Reset index for second pass to decode actual items
            payloadIndex = payloadStartIndex;

            // Second pass: decode each item and store in output array
            for (uint256 i = 0; i < itemCount; i++) {
                uint8 prefix = uint8(bytes1(_input[payloadIndex]));
                
                // Handle single byte case (0x00-0x7f) - byte is its own RLP encoding
                if (prefix <= 0x7f) {
                    output_[i] = new bytes(1);
                    output_[i][0] = _input[payloadIndex];
                    payloadIndex += 1;
                }
                // Handle string case (0x80-0xbf) - extract content bytes
                else if (prefix >= 0x80 && prefix <= 0xbf) {
                    if (prefix <= 0xb7) {
                        uint256 strLength = prefix - 0x80;
                        bytes memory packedItem = new bytes(strLength);
                        for (uint256 j = 0; j < strLength; j++) {
                            packedItem[j] = _input[payloadIndex + 1 + j];
                        }
                        output_[i] = packedItem;
                        payloadIndex += 1 + strLength;
                    } else {
                        uint256 lengthBytesCount = prefix - 0xb7;
                        uint256 strLength = 0;
                        for (uint256 j = 1; j <= lengthBytesCount; j++) {
                            strLength = strLength + (uint8(_input[payloadIndex + j]) * 256 ** (lengthBytesCount - j));
                        }
                        bytes memory packedItem = new bytes(strLength);
                        for (uint256 j = 0; j < strLength; j++) {
                            packedItem[j] = _input[payloadIndex + 1 + lengthBytesCount + j];
                        }
                        output_[i] = packedItem;
                        payloadIndex += 1 + lengthBytesCount + strLength;
                    }
                }
                // Missing support for nested lists (consistency with first pass)
                else {
                    revert("Unsupported item type in list");
                }
            }

            return output_;
        }
    }
}
