// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { RLPReader } from "src/RLPReader.sol";
import { RLPHelpers } from "src/utils/RLPHelpers.sol";

/**
 * @title RLP Reader Byte Decoding Tests
 * @notice Test suite for verifying correct decoding of RLP encoded bytes
 * @dev Tests RLP decoding of byte strings with the following cases:
 * 1. Single byte (0x00-0x7f) - decoded as itself
 * 2. Short string (0-55 bytes) - remove 0x80 + length prefix
 * 3. Long string (>55 bytes) - remove 0xb7 + length of length prefix
 */
contract RLPReader_readBytes_Test is Test {
    /**
     * @notice Tests RLP decoding of single bytes in range [0x00, 0x7f]
     * @dev Test case:
     * - Input: bytes in range [0x00, 0x7f]
     * - Expected: same byte value (no encoding/decoding needed)
     */
    function test_readBytes_00to7f_succeeds() external pure {
        // Test all values between 0x00 and 0x7f
        for (uint8 i = 0x00; i < 0x80; i++) {
            bytes memory encodedInput = abi.encodePacked(bytes1(i));
            assertEq(RLPReader.readBytes(encodedInput), encodedInput);
        }
    }

    /**
     * @notice Fuzz test for RLP decoding of byte strings between 1 and 55 bytes
     * @dev Test case:
     * - Input: random bytes of length 1-55
     * - Expected: remove 0x80 + length prefix to get original string
     * - Constraints:
     *   1. Length <= 55 bytes
     *   2. Not empty array
     *   3. Not single byte < 128
     * @param _input Random bytes input for fuzzing
     */
    function testFuzz_readBytes_1to55bytes_succeeds(bytes memory _input) external pure {
        // Ensure input meets test case constraints
        if (_input.length > 55) {
            // Truncate to 55 bytes for this test case
            assembly {
                mstore(_input, 55)
            }
        }

        // Zero value is already covered separately
        if (_input.length == 0) {
            _input = hex"deadbeef";
        }

        // 00-7f values are already covered separately
        if (_input.length == 1 && uint8(_input[0]) < 128) {
            _input = hex"cafebeef";
        }

        // Spec says that for values between 0 and 55 bytes long, the encoding is:
        // 0x80 + len(value), value
        bytes memory lengthByte = abi.encodePacked(bytes1(uint8(0x80 + _input.length)));
        bytes memory encodedInput = bytes.concat(lengthByte, _input);

        // Assert that reading the encoded input gives us our input
        assertEq(RLPReader.readBytes(encodedInput), _input);
    }

    /**
     * @notice Tests RLP decoding of byte arrays with length > 55 bytes
     * @dev For arrays > 55 bytes, RLP encoding is: 0xb7+length of length bytes, followed by length bytes, followed by
     * data
     * @param _input Random bytes input to test decoding against
     */
    function testFuzz_readBytes_morethan55bytes_succeeds(bytes memory _input) external pure {
        // We ensure that any input with length less than 55 becomes a 2-bytes input
        if (_input.length <= 55) {
            _input = abi.encodePacked(keccak256(_input), keccak256(_input));
        }

        // Get bytes representation of the length
        (uint8 lengthLength, bytes memory lengthBytes) = RLPHelpers.getLengthBytes(_input);

        // Spec says that for values longer than 55 bytes, the encoding is:
        // 0xb7 + len(len(value)), len(value), value
        bytes memory lengthLengthBytes = abi.encodePacked(bytes1(uint8(0xb7 + lengthLength)));
        bytes memory encodedInput = bytes.concat(lengthLengthBytes, lengthBytes, _input);

        // Assert that reading the encoded input gives us our input
        assertEq(RLPReader.readBytes(encodedInput), _input);
    }
}

/**
 * @title RLP Reader Standard Test Vectors for Bytes
 * @notice Test suite for verifying RLP decoding against standard test vectors
 * @dev Tests RLP decoding against official Ethereum test vectors:
 * 1. Single bytes (0x00, 0x01, 0x7f) - decoded as is
 * 2. Short strings ("dog", 55 bytes) - remove 0x80 + length prefix
 * 3. Long strings (>55 bytes) - remove 0xb7 + length of length prefix
 */
contract RLPReader_readBytes_standard_Test is Test {
    /**
     * @notice Tests RLP decoding of an empty byte array
     * @dev Test case:
     * - Input: 0x80 (RLP encoding of empty array)
     * - Expected: empty bytes array
     */
    function test_readBytes_standard_empty_succeeds() external pure {
        assertEq(RLPReader.readBytes(hex"80"), hex"");
    }

    /**
     * @notice Tests RLP decoding of a byte string containing 0x00
     * @dev Test case:
     * - Input: 0x00 (single byte)
     * - Expected: 0x00 (byte value < 0x80, decoded as itself)
     */
    function test_readBytes_standard_bytestring00_succeeds() external pure {
        assertEq(RLPReader.readBytes(hex"00"), hex"00");
    }

    /**
     * @notice Tests RLP decoding of a byte string containing 0x01
     * @dev Test case:
     * - Input: 0x01 (single byte)
     * - Expected: 0x01 (byte value < 0x80, decoded as itself)
     */
    function test_readBytes_standard_bytestring01_succeeds() external pure {
        assertEq(RLPReader.readBytes(hex"01"), hex"01");
    }

    /**
     * @notice Tests RLP decoding of a byte string containing 0x7F
     * @dev Test case:
     * - Input: 0x7f (single byte)
     * - Expected: 0x7f (byte value < 0x80, decoded as itself)
     */
    function test_readBytes_standard_bytestring7F_succeeds() external pure {
        assertEq(RLPReader.readBytes(hex"7f"), hex"7f");
    }

    /**
     * @notice Tests RLP decoding of a short string "dog"
     * @dev Test case:
     * - Input: 0x83646f67 (0x80 + length = 0x83, followed by "dog")
     * - Expected: "dog" (3-byte string)
     */
    function test_readBytes_standard_shortstring_succeeds() external pure {
        assertEq(RLPReader.readBytes(hex"83646f67"), "dog");
    }

    /**
     * @notice Tests RLP decoding of a 55-byte string
     * @dev Test case:
     * - Input: 0xb7 + 55-byte string (last case before long string encoding)
     * - Expected: "Lorem ipsum dolor sit amet, consectetur adipisicing eli"
     */
    function test_readBytes_standard_shortstring2_succeeds() external pure {
        assertEq(
            RLPReader.readBytes(
                hex"b74c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e7365637465747572206164697069736963696e6720656c69"
            ),
            "Lorem ipsum dolor sit amet, consectetur adipisicing eli"
        );
    }

    /**
     * @notice Tests RLP decoding of a 56-byte string
     * @dev Test case:
     * - Input: 0xb838 + 56-byte string (first case of long string encoding)
     * - Expected: "Lorem ipsum dolor sit amet, consectetur adipisicing elit"
     */
    function test_readBytes_standard_longstring_succeeds() external pure {
        assertEq(
            RLPReader.readBytes(
                hex"b8384c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e7365637465747572206164697069736963696e6720656c6974"
            ),
            "Lorem ipsum dolor sit amet, consectetur adipisicing elit"
        );
    }
}

/**
 * @title RLP Reader List Decoding Tests
 * @notice Test suite for verifying correct decoding of RLP encoded lists
 * @dev Tests RLP decoding of lists with the following cases:
 * 1. Empty list - remove 0xc0 prefix
 * 2. Short list (0-55 bytes) - remove 0xc0 + length prefix
 * 3. Long list (>55 bytes) - remove 0xf7 + length of length prefix
 */
contract RLPReader_readList_Test is Test {
    /**
     * @notice Fuzz test for RLP decoding of lists with payload 1-55 bytes
     * @dev Test case:
     * - Input: random list with total payload 1-55 bytes
     * - Expected: remove 0xc0 + length prefix to get original list items
     * - Constraints:
     *   1. Total payload length <= 55 bytes
     *   2. Each item is RLP encoded
     * @param _length Random length parameter for fuzzing
     */
    function testFuzz_readList_payload1to55bytes_succeeds(uint8 _length) external {
        // Create an array to hold RLP-encoded items (maximum 55 elements)
        bytes[] memory payload = new bytes[](55);
        uint8 index = 0;

        // Bound total available bytes between 1 and 54 to ensure short list encoding
        uint256 total_available_bytes = bound(_length, 1, 54);

        // Generate random RLP-encoded items until we've used up all available bytes
        while (total_available_bytes > 0) {
            // Generate a random number of bytes to use
            uint256 randomNumber = vm.randomUint(0, total_available_bytes);

            // Generate random bytes of that length
            bytes memory randomBytes = vm.randomBytes(randomNumber);

            // RLP encode the random bytes following encoding rules
            bytes memory encodedBytesInput;
            if (randomBytes.length == 0) {
                // Case 1: Empty byte array - encode as 0x80
                encodedBytesInput = hex"80";
            } else if (randomBytes.length == 1 && uint8(randomBytes[0]) < 128) {
                // Case 2: Single byte < 0x80 - use byte as is
                encodedBytesInput = abi.encodePacked(randomBytes[0]);
            } else {
                // Case 3: Short string - prefix with 0x80 + length
                bytes memory lengthBytes = abi.encodePacked(bytes1(uint8(0x80 + randomBytes.length)));
                encodedBytesInput = bytes.concat(lengthBytes, randomBytes);
            }

            // Add encoded item if it fits within remaining bytes
            if (encodedBytesInput.length <= total_available_bytes) {
                payload[index] = encodedBytesInput;
                total_available_bytes -= encodedBytesInput.length;
                index++;
            }
        }

        // Build the decoded list and byte payload for verification
        bytes[] memory decodedList = new bytes[](index);
        bytes memory bytesPayload;

        for (uint8 i = 0; i < index; i++) {
            decodedList[i] = RLPReader.readBytes(payload[i]);
            bytesPayload = bytes.concat(bytesPayload, payload[i]);
        }

        // Create the final RLP encoded list:
        // 0xc0 + len(payload), payload
        bytes memory lengthByte = abi.encodePacked(bytes1(uint8(0xc0 + bytesPayload.length)));
        bytes memory encodedInput = bytes.concat(lengthByte, bytesPayload);

        // Verify decoding matches our expected output
        assertEq(RLPReader.readList(encodedInput), decodedList);
    }

    /**
     * @notice Tests RLP decoding of lists with payload > 55 bytes
     * @dev For lists with payload > 55 bytes, encoding is: 0xf7+length of length, length bytes, payload
     * @param _input Random bytes array input to test decoding against
     */
    function testFuzz_readList_payloadMoreThan55bytes_succeeds(bytes[] memory _input) external {
        // If empty, force it not to be.
        if (_input.length == 0) {
            _input = new bytes[](1);
        }

        // Make sure that the list payload will always be more than 55 bytes long
        _input[vm.randomUint(0, _input.length - 1)] = vm.randomBytes(55);

        // Init array to build the payload
        bytes[] memory payload = new bytes[](_input.length);

        // Encode each element in the input array according to RLP rules
        for (uint8 i = 0; i < _input.length; i++) {
            if (_input[i].length <= 55) {
                // For bytes arrays 1-55 bytes long
                bytes memory lengthByte = abi.encodePacked(bytes1(uint8(0x80 + _input[i].length)));
                bytes memory encodedInputElement = bytes.concat(lengthByte, _input[i]);
                payload[i] = encodedInputElement;
            } else {
                // For bytes arrays > 55 bytes long
                (uint8 lengthLength, bytes memory lengthBytes) = RLPHelpers.getLengthBytes(_input[i]);
                bytes memory lenghtLenghtBytes = abi.encodePacked(bytes1(uint8(0xb7 + lengthLength)));
                bytes memory encodedInputElement = bytes.concat(lenghtLenghtBytes, lengthBytes, _input[i]);
                payload[i] = encodedInputElement;
            }
        }

        // Converting bytes[] to bytes to concatenate later
        bytes memory bytesPayload;

        // Building bytes payload array
        for (uint8 i = 0; i < payload.length; i++) {
            bytesPayload = abi.encodePacked(bytesPayload, payload[i]);
        }

        // Get bytes representation of the payload length
        (uint8 payloadLengthLength, bytes memory payloadLengthBytes) = RLPHelpers.getLengthBytes(bytesPayload);

        // Encode the final list according to RLP spec: 0xf7 + len(len(value)), len(value), value
        bytes memory payloadLengthLengthBytes = abi.encodePacked(bytes1(uint8(0xf7 + payloadLengthLength)));
        bytes memory encodedInput = bytes.concat(payloadLengthLengthBytes, payloadLengthBytes, bytesPayload);

        // Verify decoding matches our expected output
        assertEq(RLPReader.readList(encodedInput), _input);
    }
}

/**
 * @title RLP Reader Standard Test Vectors for Lists
 * @notice Test suite for verifying RLP list decoding against standard test vectors
 * @dev Tests RLP list decoding against official Ethereum test vectors:
 * 1. Empty list - remove 0xc0 prefix
 * 2. Simple lists (strings, mixed types) - remove 0xc0 + length prefix
 * 3. Nested lists (empty, complex) - recursive decoding
 * 4. Key-value pairs - decoded as lists
 */
contract RLPReader_readList_standard_Test is Test {
    /**
     * @notice Tests RLP decoding of an empty list
     * @dev Test case:
     * - Input: 0xc0 (RLP encoded empty list)
     * - Expected: [] (empty list)
     */
    function test_readList_standard_emptyList_succeeds() external pure {
        assertEq(RLPReader.readList(hex"c0"), new bytes[](0));
    }

    /**
     * @notice Tests RLP decoding of a list of strings
     * @dev Test case:
     * - Input: 0xcc83646f6783676f6483636174 (0xc0 + length = 0xcc, followed by encoded items)
     * - Expected: ["dog", "god", "cat"]
     */
    function test_readList_standard_stringList_succeeds() external pure {
        bytes[] memory expected = new bytes[](3);
        expected[0] = "dog";
        expected[1] = "god";
        expected[2] = "cat";

        assertEq(RLPReader.readList(hex"cc83646f6783676f6483636174"), expected);
    }

    /**
     * @notice Tests RLP decoding of a mixed list
     * @dev Test case:
     * - Input: 0xc6827a77c10401 (0xc0 + length = 0xc6, followed by encoded items)
     * - Expected: ["zw", [4], 1] (string, single-item list, number)
     */
    function test_readList_standard_mixedList_succeeds() external pure {
        bytes[] memory expected = new bytes[](3);
        expected[0] = "zw";
        expected[1] = hex"04"; // Single-item list payload
        expected[2] = hex"01"; // Single byte number

        assertEq(RLPReader.readList(hex"c6827a77c10401"), expected);
    }

    /**
     * @notice Tests RLP decoding of nested empty lists
     * @dev Test case:
     * - Input: 0xc4c2c0c0c0 (0xc0 + length = 0xc4, followed by encoded nested lists)
     * - Expected: [[[], []], []] (two levels of nesting)
     */
    function test_readList_standard_nestedEmptyLists_succeeds() external pure {
        bytes[] memory expected = new bytes[](2);
        expected[0] = hex"c0c0"; // Encoded [[], []]
        expected[1] = hex""; // Empty list payload

        assertEq(RLPReader.readList(hex"c4c2c0c0c0"), expected);
    }

    /**
     * @notice Tests RLP decoding of complex nested lists
     * @dev Test case:
     * - Input: 0xc7c0c1c0c3c0c1c0 (0xc0 + length = 0xc7, followed by encoded nested lists)
     * - Expected: [[], [[]], [[], [[]]]] (three levels of nesting)
     */
    function test_readList_standard_complexNestedLists_succeeds() external pure {
        bytes[] memory expected = new bytes[](3);
        expected[0] = hex""; // Empty list payload
        expected[1] = hex"c0"; // Encoded [[]]
        expected[2] = hex"c0c1c0"; // Encoded [[], [[]]]

        assertEq(RLPReader.readList(hex"c7c0c1c0c3c0c1c0"), expected);
    }

    /**
     * @notice Tests RLP decoding of key-value pairs
     * @dev Test case:
     * - Input: 0xe4... (0xc0 + length = 0xe4, followed by four identical key-value pairs)
     * - Expected: [["key","val"], ["key","val"], ["key","val"], ["key","val"]]
     */
    function test_readList_standard_keyValuePairs_succeeds() external pure {
        bytes[] memory expected = new bytes[](4);
        bytes memory kvPair = hex"846b65798476616c"; // Encoded ["key", "val"]

        for (uint256 i = 0; i < 4; i++) {
            expected[i] = kvPair;
        }

        assertEq(
            RLPReader.readList(hex"e4c8846b65798476616cc8846b65798476616cc8846b65798476616cc8846b65798476616c"),
            expected
        );
    }
}
