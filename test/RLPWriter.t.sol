// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { RLPWriter } from "src/RLPWriter.sol";
import { RLPReader } from "src/RLPReader.sol";
import "../src/utils/RLPHelpers.sol";
import "forge-std/StdJson.sol";

/**
 * @title RLPWriter_writeBytes_Test
 * @notice Test contract for RLPWriter's writeBytes function
 * @dev Tests the RLP encoding of byte strings according to Ethereum's RLP specification:
 *      - For a single byte in [0x00, 0x7f], the byte is its own RLP encoding
 *      - For a 0-55 byte long string, the RLP encoding is 0x80+length followed by the string
 *      - For a string longer than 55 bytes, the RLP encoding is 0xb7+length of the length
 *        followed by the length, followed by the string
 */
contract RLPWriter_writeBytes_Test is Test {
    /**
     * @notice Tests RLP encoding of an empty byte string
     * @dev Empty strings should be encoded as 0x80
     */
    function test_writeBytes_empty_succeeds() external pure {
        assertEq(RLPWriter.writeBytes(hex""), hex"80");
    }

    /**
     * @notice Tests RLP encoding of single bytes from 0x00 to 0x7f
     * @dev For bytes in range [0x00, 0x7f], the byte itself is its own RLP encoding
     */
    function test_writeBytes_00to7f_succeeds() external pure {
        for (uint8 i = 0; i < 128; i++) {
            bytes memory encodedInput = abi.encodePacked(bytes1(i));
            assertEq(RLPWriter.writeBytes(encodedInput), encodedInput);
        }
    }

    /**
     * @notice Fuzz test for RLP encoding of byte strings between 1 and 55 bytes
     * @dev For strings of length 1-55 bytes, the RLP encoding is:
     *      0x80+length followed by the string
     * @param _input Random bytes input for fuzzing
     */
    function testFuzz_writeBytes_1to55bytes_succeeds(bytes memory _input) external view {
        // Ensure input is within the 1-55 bytes range for this specific test case
        if (_input.length > 55) {
            _input = vm.randomBytes(55);
        }
        // Avoid empty byte arrays as they're handled by a different test case
        if (_input.length == 0) {
            _input = vm.randomBytes(1);
        }
        // Avoid single bytes < 128 as they're handled by a different test case (direct encoding)
        if (_input.length == 1 && uint8(_input[0]) < 128) {
            _input = vm.randomBytes(2);
        }

        // Create the length byte for the RLP encoding
        bytes memory lengthByte = abi.encodePacked(bytes1(uint8(0x80 + _input.length)));
        // Concatenate the length byte with the input bytes
        bytes memory encodedInput = bytes.concat(lengthByte, _input);

        // Verify that the manual RLP encoding matches the library's output
        assertEq(RLPWriter.writeBytes(_input), encodedInput);
    }

    /**
     * @notice Fuzz test for RLP encoding of byte strings longer than 55 bytes
     * @dev For strings longer than 55 bytes, the RLP encoding is:
     *      0xb7+length of the length, followed by the length, followed by the string
     * @param _input Random bytes input for fuzzing
     */
    function testFuzz_writeBytes_morethan55bytes_succeeds(bytes memory _input) external view {
        // Ensure input is longer than 55 bytes for this specific test case
        // as we're testing the encoding for long strings
        if (_input.length <= 55) {
            _input = vm.randomBytes(56);
        }

        // Convert input length to its byte representation for RLP encoding
        (uint8 lengthLength, bytes memory lengthBytes) = RLPHelpers.getLengthBytes(_input);

        // Spec says that for values longer than 55 bytes, the encoding is:
        // 0xb7 + len(len(value)), len(value), value
        bytes memory lengthLengthBytes = abi.encodePacked(bytes1(uint8(0xb7 + lengthLength))); // correct!
        bytes memory encodedInput = bytes.concat(lengthLengthBytes, lengthBytes, _input);

        // Verify that the manual RLP encoding matches the library's output
        assertEq(RLPWriter.writeBytes(_input), encodedInput);
    }
}

/**
 * @title RLPWriter_writeBytes_standard_Test
 * @notice Test contract for RLPWriter's writeBytes function using standard test vectors
 * @dev Tests RLP encoding against official Ethereum RLP test vectors
 */
contract RLPWriter_writeBytes_standard_Test is Test {
    /**
     * @notice Tests RLP encoding of a byte string containing 0x00
     * @dev Single bytes < 0x80 are encoded as themselves
     */
    function test_writeBytes_standard_bytestring00_succeeds() external pure {
        assertEq(RLPWriter.writeBytes(hex"00"), hex"00");
    }

    /**
     * @notice Tests RLP encoding of a byte string containing 0x01
     * @dev Single bytes < 0x80 are encoded as themselves
     */
    function test_writeBytes_standard_bytestring01_succeeds() external pure {
        assertEq(RLPWriter.writeBytes(hex"01"), hex"01");
    }

    /**
     * @notice Tests RLP encoding of a byte string containing 0x7F
     * @dev Single bytes < 0x80 are encoded as themselves
     */
    function test_writeBytes_standard_bytestring7F_succeeds() external pure {
        assertEq(RLPWriter.writeBytes(hex"7f"), hex"7f");
    }

    /**
     * @notice Tests RLP encoding of a short string "dog"
     * @dev Short strings (0-55 bytes) are encoded as 0x80+length followed by the string
     */
    function test_writeBytes_standard_shortstring_succeeds() external pure {
        assertEq(RLPWriter.writeBytes("dog"), hex"83646f67");
    }

    /**
     * @notice Tests RLP encoding of a longer string
     * @dev Tests encoding of a 55-byte string
     */
    function test_writeBytes_standard_shortstring2_succeeds() external pure {
        assertEq(
            RLPWriter.writeBytes("Lorem ipsum dolor sit amet, consectetur adipisicing eli"),
            hex"b74c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e7365637465747572206164697069736963696e6720656c69"
        );
    }

    /**
     * @notice Tests RLP encoding of a long string
     * @dev Tests encoding of a 56-byte string
     */
    function test_writeBytes_standard_longstring_succeeds() external pure {
        assertEq(
            RLPWriter.writeBytes("Lorem ipsum dolor sit amet, consectetur adipisicing elit"),
            hex"b8384c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e7365637465747572206164697069736963696e6720656c6974"
        );
    }

    /**
     * @notice Tests RLP encoding of a very long string
     * @dev Tests encoding of a string longer than 255 bytes
     */
    function test_writeBytes_standard_longstring2_succeeds() external pure {
        assertEq(
            RLPWriter.writeBytes("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur mauris magna, suscipit sed vehicula non, iaculis faucibus tortor. Proin suscipit ultricies malesuada. Duis tortor elit, dictum quis tristique eu, ultrices at risus. Morbi a est imperdiet mi ullamcorper aliquet suscipit nec lorem. Aenean quis leo mollis, vulputate elit varius, consequat enim. Nulla ultrices turpis justo, et posuere urna consectetur nec. Proin non convallis metus. Donec tempor ipsum in mauris congue sollicitudin. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Suspendisse convallis sem vel massa faucibus, eget lacinia lacus tempor. Nulla quis ultricies purus. Proin auctor rhoncus nibh condimentum mollis. Aliquam consequat enim at metus luctus, a eleifend purus egestas. Curabitur at nibh metus. Nam bibendum, neque at auctor tristique, lorem libero aliquet arcu, non interdum tellus lectus sit amet eros. Cras rhoncus, metus ac ornare cursus, dolor justo ultrices metus, at ullamcorper volutpat"),
            hex"b904004c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e73656374657475722061646970697363696e6720656c69742e20437572616269747572206d6175726973206d61676e612c20737573636970697420736564207665686963756c61206e6f6e2c20696163756c697320666175636962757320746f72746f722e2050726f696e20737573636970697420756c74726963696573206d616c6573756164612e204475697320746f72746f7220656c69742c2064696374756d2071756973207472697374697175652065752c20756c7472696365732061742072697375732e204d6f72626920612065737420696d70657264696574206d6920756c6c616d636f7270657220616c6971756574207375736369706974206e6563206c6f72656d2e2041656e65616e2071756973206c656f206d6f6c6c69732c2076756c70757461746520656c6974207661726975732c20636f6e73657175617420656e696d2e204e756c6c6120756c74726963657320747572706973206a7573746f2c20657420706f73756572652075726e6120636f6e7365637465747572206e65632e2050726f696e206e6f6e20636f6e76616c6c6973206d657475732e20446f6e65632074656d706f7220697073756d20696e206d617572697320636f6e67756520736f6c6c696369747564696e2e20566573746962756c756d20616e746520697073756d207072696d697320696e206661756369627573206f726369206c756374757320657420756c74726963657320706f737565726520637562696c69612043757261653b2053757370656e646973736520636f6e76616c6c69732073656d2076656c206d617373612066617563696275732c2065676574206c6163696e6961206c616375732074656d706f722e204e756c6c61207175697320756c747269636965732070757275732e2050726f696e20617563746f722072686f6e637573206e69626820636f6e64696d656e74756d206d6f6c6c69732e20416c697175616d20636f6e73657175617420656e696d206174206d65747573206c75637475732c206120656c656966656e6420707572757320656765737461732e20437572616269747572206174206e696268206d657475732e204e616d20626962656e64756d2c206e6571756520617420617563746f72207472697374697175652c206c6f72656d206c696265726f20616c697175657420617263752c206e6f6e20696e74657264756d2074656c6c7573206c65637475732073697420616d65742065726f732e20437261732072686f6e6375732c206d65747573206163206f726e617265206375727375732c20646f6c6f72206a7573746f20756c747269636573206d657475732c20617420756c6c616d636f7270657220766f6c7574706174"
        );
    }
}

/**
 * @title RLPWriter_writeList_Test
 * @notice Test contract for RLPWriter's writeList function
 * @dev Tests the RLP encoding of lists according to Ethereum's RLP specification:
 *      - For a list with total payload length 0-55 bytes, the RLP encoding is
 *        0xc0+length followed by the concatenation of the RLP encodings of the items
 *      - For a list with total payload length > 55 bytes, the RLP encoding is
 *        0xf7+length of the length, followed by the length, followed by the
 *        concatenation of the RLP encodings of the items
 */
contract RLPWriter_writeList_Test is Test {
    /**
     * @notice Tests RLP encoding of an empty list
     * @dev Empty lists should be encoded as 0xc0
     */
    function testFuzz_writeList_empty_succeeds() external pure {
        bytes[] memory _input = new bytes[](0);
        assertEq(RLPWriter.writeList(_input), hex"c0");
    }

    /**
     * @notice Fuzz test for RLP encoding of lists with payload 1-55 bytes
     * @dev For lists with total payload 1-55 bytes, the RLP encoding is:
     *      0xc0+length followed by the concatenation of the RLP encodings of the items.
     *      This test generates RLP-encoded items directly and passes them to writeList,
     *      as the function expects pre-encoded items.
     * @param _length Random length parameter for fuzzing
     */
    function testFuzz_writeList_payload1to55bytes_succeeds(uint8 _length) external {
        // Create an array to hold RLP-encoded items (maximum 55 elements)
        // These are pre-encoded items that will be passed directly to writeList
        bytes[] memory payload = new bytes[](55);
        
        // Bound the total available bytes between 1 and 54 to ensure we're testing short lists
        // (lists with payload <= 55 bytes)
        uint256 total_available_bytes = bound(_length, 1, 54);
        
        // Track the current index in the payload array
        uint256 index = 0;
        
        // Generate random RLP-encoded items until we've used up all available bytes
        while (total_available_bytes > 0) {
            // Generate a random number of bytes to use (between 0 and remaining bytes)
            uint256 randomNumber = vm.randomUint(0, total_available_bytes);
            
            // Generate random bytes of that length
            bytes memory randomBytes = vm.randomBytes(randomNumber);
            
            // Variable to hold the RLP encoding of the random bytes
            bytes memory encodedBytesInput;
            
            // Apply RLP encoding rules:
            if (randomBytes.length == 0) {
                // Case 1: Empty byte array - encode as 0x80
                encodedBytesInput = hex"80";
            } else if (randomBytes.length == 1 && uint8(randomBytes[0]) < 128) {
                // Case 2: Single byte < 0x80 - use the byte as is
                encodedBytesInput = abi.encodePacked(randomBytes[0]);
            } else {
                // Case 3: Short string - prefix with 0x80 + length
                bytes memory lengthBytes = abi.encodePacked(bytes1(uint8(0x80 + randomBytes.length)));
                encodedBytesInput = bytes.concat(lengthBytes, randomBytes);
            }
            
            // Add the encoded item to our payload array
            payload[index] = encodedBytesInput;
            
            // Only proceed if the encoded item fits within our remaining bytes
            if (encodedBytesInput.length <= total_available_bytes) {
                // Subtract the length of the encoded item from our remaining bytes
                total_available_bytes -= encodedBytesInput.length;
                // Move to the next index in the payload array
                index++;
            }
        }

        // Create a new array with exactly the number of items we generated
        bytes[] memory finalPayload = new bytes[](index);
        for (uint256 i = 0; i < index; i++) {
            finalPayload[i] = payload[i];
        }
        
        // Create a variable to hold the concatenated RLP-encoded items
        bytes memory bytesPayload;

        // For each valid item in our payload array:
        for (uint256 i = 0; i < index; i++) {
            // Concatenate the RLP-encoded item to our payload
            bytesPayload = bytes.concat(bytesPayload, finalPayload[i]);
        }

        // Create the expected RLP encoding for the list:
        // 0xc0 + length of payload, followed by the concatenated payload
        bytes memory expectedOutput = abi.encodePacked(bytes1(uint8(0xc0 + bytesPayload.length)), bytesPayload);

        // Verify that RLPWriter.writeList produces the expected output when given pre-encoded items
        assertEq(RLPWriter.writeList(finalPayload), expectedOutput);
    }

    /**
     * @notice Fuzz test for RLP encoding of lists with payload more than 55 bytes
     * @dev For lists with total payload > 55 bytes, the RLP encoding is:
     *      0xf7+length of the length, followed by the length, followed by the
     *      concatenation of the RLP encodings of the items.
     *      This test encodes each input element into RLP format first, then passes
     *      these pre-encoded items to writeList.
     * @param _input Random bytes array input for fuzzing
     */
    function testFuzz_writeList_payloadmorethan55bytes_succeeds(bytes[] memory _input) external {
        // Ensure we have at least one element in the array to work with
        if (_input.length == 0) {
            _input = new bytes[](1);
        }

        // Ensure our test will have a payload exceeding 55 bytes by adding a large element
        // This forces the test to use the long list encoding format (0xf7 + length of length)
        _input[vm.randomUint(0, _input.length - 1)] = vm.randomBytes(56);

        // Create an array to hold the RLP-encoded version of each input element
        // These pre-encoded items will be passed directly to writeList
        bytes[] memory payload = new bytes[](_input.length);

        // Encode each input element according to RLP encoding rules:
        for (uint8 i = 0; i < _input.length; i++) {
            if (_input[i].length == 0) {
                // Case 1: Empty byte array - encode as 0x80
                payload[i] = abi.encodePacked(bytes1(0x80));
            } 
            else if (_input[i].length == 1 && uint8(_input[i][0]) < 0x80) {
                // Case 2: Single byte < 0x80 - use the byte as is
                payload[i] = abi.encodePacked(bytes1(_input[i][0]));
            }
            else if (_input[i].length <= 55) {
                // Case 3: Short string (0-55 bytes) - prefix with 0x80 + length
                bytes memory lengthByte = abi.encodePacked(bytes1(uint8(0x80 + _input[i].length)));
                bytes memory encodedInputElement = bytes.concat(lengthByte, _input[i]);
                payload[i] = encodedInputElement;
            } else {
                // Case 4: Long string (>55 bytes) - prefix with 0xb7 + length of length, followed by length
                // First get the bytes representation of the length
                (uint8 lengthLength, bytes memory lengthBytes) = RLPHelpers.getLengthBytes(_input[i]);
                // Create the prefix byte: 0xb7 + length of the length bytes
                bytes memory lenghtLenghtBytes = abi.encodePacked(bytes1(uint8(0xb7 + lengthLength)));
                // Concatenate: prefix + length bytes + actual data
                bytes memory encodedInputElement = bytes.concat(lenghtLenghtBytes, lengthBytes, _input[i]);
                payload[i] = encodedInputElement;
            }
        }

        // Initialize an empty byte array to hold the concatenated encoded elements
        bytes memory bytesPayload;

        // Concatenate all encoded elements into a single byte array
        // This forms the payload portion of the RLP list encoding
        for (uint8 i = 0; i < payload.length; i++) {
            bytesPayload = bytes.concat(bytesPayload, payload[i]);
        }

        // For long lists (>55 bytes), we need to encode the length of the payload
        // First, get the byte representation of the payload length
        (uint8 payloadLengthLength, bytes memory payloadLengthBytes) = RLPHelpers.getLengthBytes(bytesPayload);

        // Create the prefix byte for the list: 0xf7 + length of the length bytes
        bytes memory payloadLengthLengthBytes = abi.encodePacked(bytes1(uint8(0xf7 + payloadLengthLength)));
        
        // Construct the complete RLP encoding:
        // prefix + length bytes + concatenated payload
        bytes memory encodedInput = bytes.concat(payloadLengthLengthBytes, payloadLengthBytes, bytesPayload);

        // Verify that RLPWriter.writeList produces the expected output when given pre-encoded items
        assertEq(RLPWriter.writeList(payload), encodedInput);
    }
}

/**
 * @title RLPWriter_writeList_standard_Test
 * @notice Test contract for RLPWriter's writeList function using standard test vectors
 * @dev Implements standard RLP test cases from Ethereum specifications
 */
contract RLPWriter_writeList_standard_Test is Test {
    /**
     * @notice Tests RLP encoding of a list of strings
     */
    function test_writeList_stringList_succeeds() external pure {
        bytes[] memory input = new bytes[](3);
        input[0] = hex"83646f67"; // RLP("dog")
        input[1] = hex"83676f64"; // RLP("god")
        input[2] = hex"83636174"; // RLP("cat")
        
        assertEq(RLPWriter.writeList(input), hex"cc83646f6783676f6483636174");
    }

    /**
     * @notice Tests RLP encoding of a mixed list
     */
    function test_writeList_mixedList_succeeds() external pure {
        bytes[] memory input = new bytes[](3);
        input[0] = hex"827a77"; // RLP("zw")
        input[1] = hex"c104";   // RLP([4])
        input[2] = hex"01";     // RLP(1)
        
        assertEq(RLPWriter.writeList(input), hex"c6827a77c10401");
    }

    /**
     * @notice Tests RLP encoding of a list with 11 elements
     */
    function test_writeList_shortListMax_succeeds() external pure {
        bytes[] memory input = new bytes[](11);
        
        input[0] = hex"8461736466"; // RLP("asdf")
        input[1] = hex"8471776572"; // RLP("qwer")
        input[2] = hex"847a786376"; // RLP("zxcv")
        input[3] = hex"8461736466"; // RLP("asdf")
        input[4] = hex"8471776572"; // RLP("qwer")
        input[5] = hex"847a786376"; // RLP("zxcv")
        input[6] = hex"8461736466"; // RLP("asdf")
        input[7] = hex"8471776572"; // RLP("qwer")
        input[8] = hex"847a786376"; // RLP("zxcv")
        input[9] = hex"8461736466"; // RLP("asdf")
        input[10] = hex"8471776572"; // RLP("qwer")
        
        assertEq(RLPWriter.writeList(input), hex"f784617364668471776572847a78637684617364668471776572847a78637684617364668471776572847a78637684617364668471776572");
    }

    /**
     * @notice Tests RLP encoding of nested lists
     */
    function test_writeList_listOfLists_succeeds() external pure {
        bytes[] memory input = new bytes[](4);
        
        // Directly use pre-encoded nested list
        bytes memory encodedList = hex"cc8461736484717765847a7863"; // RLP(["asdf","qwer","zxcv"])
        
        // Create a list with 4 identical nested lists
        input[0] = encodedList;
        input[1] = encodedList;
        input[2] = encodedList;
        input[3] = encodedList;
        
        assertEq(RLPWriter.writeList(input), hex"f4cc8461736484717765847a7863cc8461736484717765847a7863cc8461736484717765847a7863cc8461736484717765847a7863");
    }

    /**
     * @notice Tests RLP encoding of empty nested lists
     */
    function test_writeList_nestedEmptyLists_succeeds() external pure {
        bytes[] memory outerList = new bytes[](2);
        
        // Directly use pre-encoded [[], []]
        outerList[0] = hex"c2c0c0"; // RLP([[], []])
        outerList[1] = hex"c0";     // RLP([])
        
        assertEq(RLPWriter.writeList(outerList), hex"c4c2c0c0c0");
    }

    /**
     * @notice Tests RLP encoding of complex nested lists
     */
    function test_writeList_complexNestedLists_succeeds() external pure {
        bytes[] memory finalList = new bytes[](3);
        
        // Use pre-encoded values directly
        finalList[0] = hex"c0";     // RLP([])
        finalList[1] = hex"c1c0";   // RLP([[]])
        finalList[2] = hex"c3c0c1c0"; // RLP([[], [[]]])
        
        assertEq(RLPWriter.writeList(finalList), hex"c7c0c1c0c3c0c1c0");
    }

    /**
     * @notice Tests RLP encoding of key-value pairs
     */
    function test_writeList_keyValuePairs_succeeds() external pure {
        bytes[] memory input = new bytes[](4);
        
        // Use pre-encoded key-value pairs
        bytes memory encodedPair = hex"c8846b65798476616c"; // RLP(["key", "val"])
        
        input[0] = encodedPair;
        input[1] = encodedPair;
        input[2] = encodedPair;
        input[3] = encodedPair;
        
        assertEq(RLPWriter.writeList(input), hex"e4c8846b65798476616cc8846b65798476616cc8846b65798476616cc8846b65798476616c");
    }
}