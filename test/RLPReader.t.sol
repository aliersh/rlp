// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { RLPReader } from "src/RLPReader.sol";
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
 * @dev Uses test vectors from rlptest.json to verify correct decoding behavior
 */
contract RLPReader_readBytes_standard_Test is Test {
    using stdJson for string;
    string jsonData = vm.readFile("./test/testdata/rlptest.json");

    /**
     * @notice Helper function to run a specific test case from the test vectors
     * @param testCase The name of the test case in the JSON file
     */
    function _runVectorTest(string memory testCase) internal view {
        string memory inputStr = stdJson.readString(jsonData, string.concat(".", testCase, ".in"));
        string memory outputStr = stdJson.readString(jsonData, string.concat(".", testCase, ".out"));
        bytes memory input = bytes(inputStr);
        bytes memory output = vm.parseBytes(outputStr);
        assertEq(RLPReader.readBytes(output), input);
    }

    // Standard test cases for various RLP byte encodings
    
    function test_readBytes_standard_emptystring_succeeds() external view {
        _runVectorTest("emptystring");
    }

    function test_readBytes_standard_bytestring00_succeeds() external view {
        _runVectorTest("bytestring00");
    }

    function test_readBytes_standard_bytestring01_succeeds() external view {
        _runVectorTest("bytestring01");
    }

    function test_readBytes_standard_bytestring7F_succeeds() external view {
        _runVectorTest("bytestring7F");
    }

    function test_readBytes_standard_shortstring_succeeds() external view {
        _runVectorTest("shortstring");
    }

    function test_readBytes_standard_shortstring2_succeeds() external view {
        _runVectorTest("shortstring2");
    }

    function test_readBytes_standard_longstring_succeeds() external view {
        _runVectorTest("longstring");
    }

    function test_readBytes_standard_longstring2_succeeds() external view {
        _runVectorTest("longstring2");
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
 * @dev Uses test vectors from rlptest.json to verify correct list decoding behavior
 */
contract RLPReader_readList_standard_Test is Test {
    
    using stdJson for string;
    string jsonData = vm.readFile("./test/testdata/rlptest.json");

    /**
     * @notice Helper function to run a specific list test case from the test vectors
     * @param testCase The name of the test case in the JSON file
     */
    function _runVectorTest(string memory testCase) internal view {
        // Read the input string array from the JSON file
        string[] memory inputStrArr = stdJson.readStringArray(jsonData, string.concat(".", testCase, ".in"));
        
        // Create a bytes array with the same length as the input string array
        bytes[] memory input = new bytes[](inputStrArr.length);
        
        // Convert each string in the array to bytes
        for (uint256 i = 0; i < inputStrArr.length; i++) {
            input[i] = bytes(inputStrArr[i]);
        }
        
        // Read the expected output string from the JSON file
        string memory outputStr = stdJson.readString(jsonData, string.concat(".", testCase, ".out"));
        
        // Convert the expected output string to bytes
        bytes memory output = vm.parseBytes(outputStr);
        
        // Verify that the RLP encoding of the input matches the expected output
        assertEq(RLPReader.readList(output), input);
    }

    /**
     * @notice Tests RLP encoding of an empty list using standard test vector
     */
    function test_readList_standard_emptystring_succeeds() external view {
        _runVectorTest("emptylist");
    }

    /**
     * @notice Tests RLP encoding of a list of strings using standard test vector
     */
    function test_readList_standard_stringlist_succeeds() external view {
        _runVectorTest("stringlist");
    }

    /**
     * @notice Tests RLP encoding of a short list with maximum length using standard test vector
     */
    function test_readList_standard_shortListMax1_succeeds() external view {
        _runVectorTest("shortListMax1");
    }
}