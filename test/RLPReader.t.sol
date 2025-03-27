// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { RLPReader } from "src/RLPReader.sol";
import { RLPWriter } from "src/RLPWriter.sol";
import { RLPHelpers } from "src/utils/RLPHelpers.sol";
import "forge-std/StdJson.sol";

/**
 * @title RLP Reader Byte Decoding Tests
 * @author Your Name
 * @notice Test suite for verifying correct decoding of RLP encoded single bytes
 * @dev Tests single byte encodings in RLP format according to Ethereum Yellow Paper
 */
contract RLPReader_readBytes_Test is Test {
    /**
     * @notice Tests RLP decoding of single bytes in range [0x00, 0x7f]
     * @dev According to RLP spec, bytes in range [0x00, 0x7f] are encoded as themselves
     */
    function test_readBytes_00to7f_succeeds() external pure {
        // Check if all values between 0x00 and 0x7f decodes as the same byte
        for (uint8 i = 0x00; i < 0x80; i++) {
            bytes memory encodedInput = abi.encodePacked(bytes1(i));
            assertEq(RLPReader.readBytes(encodedInput), encodedInput);
        }
    }

    /**
     * @notice Tests RLP decoding of an empty byte array
     * @dev According to RLP spec, an empty array is encoded as 0x80
     */
    function test_readBytes_empty_succeeds() external pure {
        // Check if 0x80 decodes as an empty bytes array
        assertEq(RLPReader.readBytes(hex"80"), hex""); // 0x80 represents an empty byte array in RLP encoding
    }

    /**
     * @notice Tests RLP decoding of byte arrays with length 1-55 bytes
     * @dev For arrays 1-55 bytes long, RLP encoding is: 0x80+length followed by data
     * @param _input Random bytes input to test decoding against
     */
    function testFuzz_readBytes_1to55bytes_succeeds(bytes memory _input) external pure {
        // We don't care about values longer than 55 bytes, we can safely clobber the memory here.
        if (_input.length > 55) {
            // Truncate to 55 bytes for this test case
            assembly {
                mstore(_input, 55)
            }
        }

        // Zero value is already covered separately.
        if (_input.length == 0) {
            _input = hex"deadbeef";
        }

        // 00-7f values are already covered separately.
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
     * @dev For arrays > 55 bytes, RLP encoding is: 0xb7+length of length bytes, followed by length bytes, followed by data
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
 * @dev Tests RLP decoding against official Ethereum RLP test vectors without relying on JSON files
 */
contract RLPReader_readBytes_standard_Test is Test {
    /**
     * @notice Tests RLP decoding of an empty string
     * @dev Empty strings are encoded as 0x80
     */
    function test_readBytes_standard_emptystring_succeeds() external pure {
        assertEq(RLPReader.readBytes(hex"80"), hex"");
    }

    /**
     * @notice Tests RLP decoding of a byte string containing 0x00
     * @dev Single bytes < 0x80 are encoded as themselves
     */
    function test_readBytes_standard_bytestring00_succeeds() external pure {
        assertEq(RLPReader.readBytes(hex"00"), hex"00");
    }

    /**
     * @notice Tests RLP decoding of a byte string containing 0x01
     * @dev Single bytes < 0x80 are encoded as themselves
     */
    function test_readBytes_standard_bytestring01_succeeds() external pure {
        assertEq(RLPReader.readBytes(hex"01"), hex"01");
    }

    /**
     * @notice Tests RLP decoding of a byte string containing 0x7F
     * @dev Single bytes < 0x80 are encoded as themselves
     */
    function test_readBytes_standard_bytestring7F_succeeds() external pure {
        assertEq(RLPReader.readBytes(hex"7f"), hex"7f");
    }

    /**
     * @notice Tests RLP decoding of a short string "dog"
     * @dev Short strings (0-55 bytes) are encoded as 0x80+length followed by the string
     */
    function test_readBytes_standard_shortstring_succeeds() external pure {
        assertEq(RLPReader.readBytes(hex"83646f67"), "dog");
    }

    /**
     * @notice Tests RLP decoding of a longer string
     * @dev Tests decoding of a 55-byte string
     */
    function test_readBytes_standard_shortstring2_succeeds() external pure {
        assertEq(
            RLPReader.readBytes(hex"b74c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e7365637465747572206164697069736963696e6720656c69"),
            "Lorem ipsum dolor sit amet, consectetur adipisicing eli"
        );
    }

    /**
     * @notice Tests RLP decoding of a long string
     * @dev Tests decoding of a 56-byte string
     */
    function test_readBytes_standard_longstring_succeeds() external pure {
        assertEq(
            RLPReader.readBytes(hex"b8384c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e7365637465747572206164697069736963696e6720656c6974"),
            "Lorem ipsum dolor sit amet, consectetur adipisicing elit"
        );
    }

    /**
     * @notice Tests RLP decoding of a very long string
     * @dev Tests decoding of a string longer than 255 bytes
     */
    function test_readBytes_standard_longstring2_succeeds() external pure {
        assertEq(
            RLPReader.readBytes(hex"b904004c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e73656374657475722061646970697363696e6720656c69742e20437572616269747572206d6175726973206d61676e612c20737573636970697420736564207665686963756c61206e6f6e2c20696163756c697320666175636962757320746f72746f722e2050726f696e20737573636970697420756c74726963696573206d616c6573756164612e204475697320746f72746f7220656c69742c2064696374756d2071756973207472697374697175652065752c20756c7472696365732061742072697375732e204d6f72626920612065737420696d70657264696574206d6920756c6c616d636f7270657220616c6971756574207375736369706974206e6563206c6f72656d2e2041656e65616e2071756973206c656f206d6f6c6c69732c2076756c70757461746520656c6974207661726975732c20636f6e73657175617420656e696d2e204e756c6c6120756c74726963657320747572706973206a7573746f2c20657420706f73756572652075726e6120636f6e7365637465747572206e65632e2050726f696e206e6f6e20636f6e76616c6c6973206d657475732e20446f6e65632074656d706f7220697073756d20696e206d617572697320636f6e67756520736f6c6c696369747564696e2e20566573746962756c756d20616e746520697073756d207072696d697320696e206661756369627573206f726369206c756374757320657420756c74726963657320706f737565726520637562696c69612043757261653b2053757370656e646973736520636f6e76616c6c69732073656d2076656c206d617373612066617563696275732c2065676574206c6163696e6961206c616375732074656d706f722e204e756c6c61207175697320756c747269636965732070757275732e2050726f696e20617563746f722072686f6e637573206e69626820636f6e64696d656e74756d206d6f6c6c69732e20416c697175616d20636f6e73657175617420656e696d206174206d65747573206c75637475732c206120656c656966656e6420707572757320656765737461732e20437572616269747572206174206e696268206d657475732e204e616d20626962656e64756d2c206e6571756520617420617563746f72207472697374697175652c206c6f72656d206c696265726f20616c697175657420617263752c206e6f6e20696e74657264756d2074656c6c7573206c65637475732073697420616d65742065726f732e20437261732072686f6e6375732c206d65747573206163206f726e617265206375727375732c20646f6c6f72206a7573746f20756c747269636573206d657475732c20617420756c6c616d636f7270657220766f6c7574706174"),
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur mauris magna, suscipit sed vehicula non, iaculis faucibus tortor. Proin suscipit ultricies malesuada. Duis tortor elit, dictum quis tristique eu, ultrices at risus. Morbi a est imperdiet mi ullamcorper aliquet suscipit nec lorem. Aenean quis leo mollis, vulputate elit varius, consequat enim. Nulla ultrices turpis justo, et posuere urna consectetur nec. Proin non convallis metus. Donec tempor ipsum in mauris congue sollicitudin. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Suspendisse convallis sem vel massa faucibus, eget lacinia lacus tempor. Nulla quis ultricies purus. Proin auctor rhoncus nibh condimentum mollis. Aliquam consequat enim at metus luctus, a eleifend purus egestas. Curabitur at nibh metus. Nam bibendum, neque at auctor tristique, lorem libero aliquet arcu, non interdum tellus lectus sit amet eros. Cras rhoncus, metus ac ornare cursus, dolor justo ultrices metus, at ullamcorper volutpat"
        );
    }
}

/**
 * @title RLP Reader List Decoding Tests
 * @notice Test suite for verifying correct decoding of RLP encoded lists
 * @dev Tests different list encodings according to the RLP specification
 */
contract RLPReader_readList_Test is Test {
    /**
     * @notice Tests RLP decoding of an empty list
     * @dev According to RLP spec, an empty list is encoded as 0xc0
     */
    function testFuzz_readList_empty_succeeds() external pure {
        assertEq(RLPReader.readList(hex"c0"), new bytes[](0));
    }

    /**
     * @notice Tests RLP decoding of lists with payload 1-55 bytes
     * @dev For lists with payload < 55 bytes, RLP encoding is: 0xc0+length, followed by payload
     * @param _length Random length parameter for test
     */
    function testFuzz_readList_payload1to55bytes_succeeds(uint8 _length) external {
        // Allocate an array of bytes, 55 elements long (bytes[])
        bytes[] memory payload = new bytes[](55);
        uint8 index = 0;

        // Bound the total available bytes between 1 and 54
        uint256 total_available_bytes = bound(_length, 1, 54);

        // Fill the payload array with randomly generated bytes
        while (total_available_bytes > 0) {
            // Generate a random number not exceeding our remaining bytes
            uint256 randomNumber = vm.randomUint(0, total_available_bytes);

            // Generate random bytes of that length
            bytes memory randomBytes = vm.randomBytes(randomNumber);

            // RLP encode that random bytes following the RLP spec
            bytes memory encodedBytesInput;
            if (randomBytes.length == 0) {
                // Empty bytes encode as 0x80
                encodedBytesInput = hex"80";
            } else if (randomBytes.length == 1 && uint8(randomBytes[0]) < 128) {
                // Single bytes < 0x80 encode as themselves
                encodedBytesInput = abi.encodePacked(randomBytes[0]);
            } else {
                // Bytes array encodes as 0x80+length followed by data
                bytes memory lengthBytes = abi.encodePacked(bytes1(uint8(0x80 + randomBytes.length)));
                encodedBytesInput = bytes.concat(lengthBytes, randomBytes);
            }

            // Add to our payload if we have space
            payload[index] = encodedBytesInput;

            // Update our tracking variables
            if (encodedBytesInput.length <= total_available_bytes) {
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

        // Verify our test setup is valid
        if (bytesPayload.length > 55) {
            revert("Bytes payload is greater than 55 bytes");
        }

        // Create the final RLP encoded list: 0xc0 + len(payload), payload
        bytes memory lengthByte = abi.encodePacked(bytes1(uint8(0xc0 + bytesPayload.length)));
        bytes memory encodedInput = bytes.concat(lengthByte, bytesPayload);

        // Assert that decoding the encoded input gives us our expected list
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
 * @dev Tests RLP list decoding against official Ethereum RLP test vectors without relying on JSON files
 */
contract RLPReader_readList_standard_Test is Test {
    /**
     * @notice Tests RLP decoding of an empty list
     * @dev Empty lists are encoded as 0xc0
     */
    function test_readList_standard_emptyList_succeeds() external pure {
        assertEq(RLPReader.readList(hex"c0"), new bytes[](0));
    }

    /**
     * @notice Tests RLP decoding of a list of strings ["dog", "god", "cat"]
     * @dev Tests decoding of a list containing multiple strings
     */
    function test_readList_standard_stringList_succeeds() external pure {
        bytes[] memory expected = new bytes[](3);
        expected[0] = "dog";
        expected[1] = "god";
        expected[2] = "cat";
        
        assertEq(RLPReader.readList(hex"cc83646f6783676f6483636174"), expected);
    }

    /**
     * @notice Tests RLP decoding of a mixed list ["zw", [4], 1]
     * @dev Tests decoding of a list containing different types of elements
     */
    function test_readList_standard_mixedList_succeeds() external pure {
        bytes[] memory expected = new bytes[](3);
        expected[0] = "zw";
        expected[1] = hex"04";  // Now just contains the payload without the c1 prefix
        expected[2] = hex"01";  // This represents 1 as a single byte
        
        assertEq(RLPReader.readList(hex"c6827a77c10401"), expected);
    }

    /**
     * @notice Tests RLP decoding of a list with 11 elements
     * @dev Tests decoding of a list at the boundary of short/long list encoding
     */
    function test_readList_standard_shortListMax_succeeds() external pure {
        bytes[] memory expected = new bytes[](11);
        expected[0] = "asdf";
        expected[1] = "qwer";
        expected[2] = "zxcv";
        expected[3] = "asdf";
        expected[4] = "qwer";
        expected[5] = "zxcv";
        expected[6] = "asdf";
        expected[7] = "qwer";
        expected[8] = "zxcv";
        expected[9] = "asdf";
        expected[10] = "qwer";
        
        assertEq(
            RLPReader.readList(hex"f784617364668471776572847a78637684617364668471776572847a78637684617364668471776572847a78637684617364668471776572"),
            expected
        );
    }

    /**
     * @notice Tests RLP decoding of nested lists
     * @dev Tests decoding of a list containing multiple identical nested lists
     *      The input is a list containing 4 identical nested lists, each containing ["asdf", "qwer", "zxcv"]
     */
    function test_readList_standard_listOfLists_succeeds() external pure {
        // The inner list ["asdf", "qwer", "zxcv"] payload is:
        // 846173 6484 - "asdf"
        // 717765 847a - "qwer"
        // 7863 - "zxcv"
        bytes memory innerListPayload = hex"8461736484717765847a7863";

        // Create the expected list with 4 identical inner lists
        bytes[] memory expected = new bytes[](4);
        for (uint i = 0; i < 4; i++) {
            expected[i] = innerListPayload;
        }
        
        assertEq(
            RLPReader.readList(hex"f4cc8461736484717765847a7863cc8461736484717765847a7863cc8461736484717765847a7863cc8461736484717765847a7863cc8461736484717765847a7863"),
            expected
        );
    }

    /**
     * @notice Tests RLP decoding of empty nested lists
     * @dev Tests decoding of a list containing empty lists: [[[], []], []]
     */
    function test_readList_standard_nestedEmptyLists_succeeds() external pure {
        bytes[] memory expected = new bytes[](2);
        
        // First element is [[], []] - should contain just the payload without the c2 prefix
        bytes[] memory innerList = new bytes[](2);
        innerList[0] = hex""; // Empty list payload
        innerList[1] = hex""; // Empty list payload
        expected[0] = hex"c0c0"; // Just the concatenated empty list encodings
        
        // Second element is []
        expected[1] = hex""; // Empty list payload
        
        assertEq(RLPReader.readList(hex"c4c2c0c0c0"), expected);
    }

    /**
     * @notice Tests RLP decoding of complex nested lists
     * @dev Tests decoding of a list with multiple levels of nesting: [[], [[]], [[], [[]]]]
     */
    function test_readList_standard_complexNestedLists_succeeds() external pure {
        bytes[] memory expected = new bytes[](3);
        
        // First element: [] - empty payload
        expected[0] = hex"";
        
        // Second element: [[]] - payload is just c0
        expected[1] = hex"c0";
        
        // Third element: [[], [[]]] - payload is c0c1c0
        expected[2] = hex"c0c1c0";
        
        assertEq(RLPReader.readList(hex"c7c0c1c0c3c0c1c0"), expected);
    }

    /**
     * @notice Tests RLP decoding of key-value pairs
     * @dev Tests decoding of a list containing multiple key-value pair lists
     *      Each inner list is ["key", "val"]
     */
    function test_readList_standard_keyValuePairs_succeeds() external pure {
        // The inner list ["key", "val"] payload is:
        // 846b6579 - "key"
        // 8476616c - "val"
        bytes memory kvPairPayload = hex"846b65798476616c";
        
        // Create the expected list with 4 identical key-value pair lists
        bytes[] memory expected = new bytes[](4);
        for (uint i = 0; i < 4; i++) {
            expected[i] = kvPairPayload;
        }
        
        assertEq(
            RLPReader.readList(hex"e4c8846b65798476616cc8846b65798476616cc8846b65798476616cc8846b65798476616c"),
            expected
        );
    }
}