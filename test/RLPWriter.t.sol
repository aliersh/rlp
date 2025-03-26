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
 * @dev Tests RLP encoding against official Ethereum RLP test vectors from rlptest.json
 */
contract RLPWriter_writeBytes_standard_Test is Test {
    /**
     * @notice Import and setup for JSON test data
     * @dev Uses the stdJson library to parse test vectors from rlptest.json
     *      This file contains standard Ethereum RLP test cases with inputs and expected outputs
     *      that will be used to validate our RLP encoding implementation
     */
    using stdJson for string;
    string jsonData = vm.readFile("./test/testdata/rlptest.json");

    /**
     * @notice Helper function to run a test vector from the JSON test data
     * @dev Reads input and expected output from JSON and verifies RLP encoding
     * @param testCase The name of the test case in the JSON file
     */
    function _runVectorTest(string memory testCase) internal view {
        // Read the input string from the JSON file
        string memory inputStr = stdJson.readString(jsonData, string.concat(".", testCase, ".in"));
        // Read the expected output string from the JSON file
        string memory outputStr = stdJson.readString(jsonData, string.concat(".", testCase, ".out"));
        // Convert the input string to bytes
        bytes memory input = bytes(inputStr);
        // Convert the expected output string to bytes
        bytes memory output = vm.parseBytes(outputStr);
        // Verify that the manual RLP encoding matches the library's output
        assertEq(RLPWriter.writeBytes(input), output);
    }

    /**
     * @notice Tests RLP encoding of an empty string using standard test vector
     */
    function test_writeBytes_standard_emptystring_succeeds() external view {
        _runVectorTest("emptystring");
    }

    /**
     * @notice Tests RLP encoding of a byte string containing 0x00
     */
    function test_writeBytes_standard_bytestring00_succeeds() external view {
        _runVectorTest("bytestring00");
    }

    /**
     * @notice Tests RLP encoding of a byte string containing 0x01
     */
    function test_writeBytes_standard_bytestring01_succeeds() external view {
        _runVectorTest("bytestring01");
    }

    /**
     * @notice Tests RLP encoding of a byte string containing 0x7F
     */
    function test_writeBytes_standard_bytestring7F_succeeds() external view {
        _runVectorTest("bytestring7F");
    }

    /**
     * @notice Tests RLP encoding of a short string
     */
    function test_writeBytes_standard_shortstring_succeeds() external view {
        _runVectorTest("shortstring");
    }

    /**
     * @notice Tests RLP encoding of another short string
     */
    function test_writeBytes_standard_shortstring2_succeeds() external view {
        _runVectorTest("shortstring2");
    }

    /**
     * @notice Tests RLP encoding of a long string
     */
    function test_writeBytes_standard_longstring_succeeds() external view {
        _runVectorTest("longstring");
    }

    /**
     * @notice Tests RLP encoding of another long string
     */
    function test_writeBytes_standard_longstring2_succeeds() external view {
        _runVectorTest("longstring2");
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