// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { RLPReader } from "src/RLPReader.sol";

contract RLPReader_readBytes_Test is Test {
    function test_readBytes_00to7f_succeeds() external pure {
        // Check if all values between 0x00 and 0x7f decodes as the same byte
        for (uint8 i = 0x00; i < 0x80; i++) { //? I changed i from decimal to hex for more clarity. Is there a convention to use one or the other?
            bytes memory encodedInput = abi.encodePacked(bytes1(i));
            assertEq(RLPReader.readBytes(encodedInput), encodedInput);
        }
    }

    function test_readBytes_empty_succeeds() external pure {
        // Check if 0x80 decodes as an empty bytes array
        assertEq(RLPReader.readBytes(hex"80"), hex""); //? What's the difference between hex"80", 0x80, bytes1(0x80)? 
    }

    function testFuzz_readBytes_1to55bytes_succeeds(bytes memory _input) external pure {
        // We don't care about values longer than 55 bytes, we can safely clobber the memory here.
        if (_input.length > 55) { //? Why we cannot use vm.assume for all these if statements?
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

    function testFuzz_readBytes_morethan55bytes_succeeds(bytes memory _input) external pure {
        // We ensure that any input with length less than 55 becomes a 2-bytes input
        if (_input.length <= 55) {
            _input = abi.encodePacked(keccak256(_input), keccak256(_input));
        }

        // What's the algorithm for this?
        // Broadly:
        // - The byte furthest to the left that is non-zero tells us how long it should be
        // -- Example: 0x0000001234 
        // -- Example: 0x0000120034
        // To find the length, we must find the non-zero byte that is furthest to the left
        // Once we have the length:
        // Copy over the bytes, starting from the index of the non-zero byte that is furthest to the left
        // Starter algorithm:
        // 1. Figure out the length by finding the index of the non-zero byte furthest to the left
        // 2. Make a bytes object with that length
        // 3. Go back and copy the bytes into the bytes object, starting from the index of that left-most byte //? Why do you need the bytes themselves? It is not enough having just the length?

        // Convert the uint hex value of _input.length to bytes32 for an easy iteration
        bytes32 inputLengthBytes = bytes32(_input.length);
        uint lengthLengthValue;

        for (uint i = 31; i < 32; i--) { //* The i < 32 part is super contraintuitive at first, but I understand why because the uint nature
            //I check the first non zero value to have the lenght of the _input.length
            if (inputLengthBytes[i] > 0) {
                lengthLengthValue = i + 1;
                break;
            }
            if (i == 0) break; // To stop the loop
        }

        // Spec says that for values longer than 55 bytes, the encoding is:
        // 0xb7 + len(len(value)), len(value), value
        bytes memory lenghtLenghtBytes = abi.encodePacked(bytes1(uint8(0xb7 + lengthLengthValue)));
        bytes memory lengthBytes = abi.encodePacked(_input.length);
        bytes memory encodedInput = bytes.concat(lenghtLenghtBytes, lengthBytes, _input);

        // Assert that reading the encoded input gives us our input
        assertEq(RLPReader.readBytes(encodedInput), _input);
    }
}