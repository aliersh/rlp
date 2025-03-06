// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { RLPReader } from "src/RLPReader.sol";

contract RLPReader_TestInit is Test {
    function getLengthBytes(bytes memory bytesInput) internal pure returns (uint8, bytes memory) {
        // Convert the uint hex value of _input.length to bytes32 for an easy iteration
        bytes32 inputLengthBytes = bytes32(bytesInput.length);

        // Iterate from left to right until we find the first non-zero value
        uint8 lengthLength = 0;
        for (uint8 i = 0; i < 32; i++) {
            if (inputLengthBytes[i] > 0) {
                lengthLength = 32 - i;
                break;
            }
        }

        // Want to create a bytes where length is equal to lengthLength
        // Here we're storing directly into the content of lengthBytes
        bytes memory lengthBytes = new bytes(lengthLength); // empty, but it's the right size!
        assembly {
            // Equivalent to inputLengthBytes << (32 - lengthLength) * 8
            mstore(add(lengthBytes, 32), shl(mul(sub(32, lengthLength), 8), inputLengthBytes))
        }

        return (lengthLength, lengthBytes);
    }
}

contract RLPReader_readBytes_Test is RLPReader_TestInit {
    // Test single bytes in range [0x00, 0x7f] are encoded as themselves
    function test_readBytes_00to7f_succeeds() external pure {
        // Check if all values between 0x00 and 0x7f decodes as the same byte
        for (uint8 i = 0x00; i < 0x80; i++) {
            bytes memory encodedInput = abi.encodePacked(bytes1(i));
            assertEq(RLPReader.readBytes(encodedInput), encodedInput);
        }
    }

    // Test empty byte array is encoded as 0x80
    function test_readBytes_empty_succeeds() external pure {
        // Check if 0x80 decodes as an empty bytes array
        assertEq(RLPReader.readBytes(hex"80"), hex""); //? What's the difference between hex"80", 0x80, bytes1(0x80)?
    }

    // Test bytes array with less than 55 bytes long are encoded correctly
    function testFuzz_readBytes_1to55bytes_succeeds(bytes memory _input) external pure {
        // We don't care about values longer than 55 bytes, we can safely clobber the memory here.
        if (_input.length > 55) {
            //? Why we cannot use vm.assume for all these if statements?
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

    // Test bytes array with more than 55 bytes long are encoded correctly
    function testFuzz_readBytes_morethan55bytes_succeeds(bytes memory _input) external pure {
        // We ensure that any input with length less than 55 becomes a 2-bytes input
        if (_input.length <= 55) {
            _input = abi.encodePacked(keccak256(_input), keccak256(_input));
        }

        // Call to convert length to bytes helper function
        (uint8 lengthLength, bytes memory lengthBytes) = getLengthBytes(_input);

        // Spec says that for values longer than 55 bytes, the encoding is:
        // 0xb7 + len(len(value)), len(value), value
        bytes memory lengthLengthBytes = abi.encodePacked(bytes1(uint8(0xb7 + lengthLength))); // correct!
        bytes memory encodedInput = bytes.concat(lengthLengthBytes, lengthBytes, _input);

        // Assert that reading the encoded input gives us our input
        assertEq(RLPReader.readBytes(encodedInput), _input);
    }
}

contract RLPReader_readList_Test is RLPReader_TestInit {
    function testFuzz_readList_empty_succeeds(bytes[] memory _input) external {
        // TODO
    }

    // Test lists with less than 55 bytes long payload are encoded correctly
    function testFuzz_readList_payload1to55bytes_succeeds(uint8 _length) external {
        // Allocate an array of bytes, 55 elements long (bytes[])
        bytes[] memory currentPayload = new bytes[](55); //? is it better to init an empty array?
        uint8 index = 0;

        // 1. Start with total_available_bytes = _length (bounded to 1, 54)
        uint256 total_available_bytes = bound(_length, 1, 54);

        // 2. If total_avalable_bytes = 0, start to encode the thing
        while (total_available_bytes > 0) {
            // 3. Pick a random number between 0 and total_available_bytes = x
            uint256 randomNumber = vm.randomUint(0, total_available_bytes);

            // 4. Generate a random bytes with length x
            bytes memory randomBytes = vm.randomBytes(randomNumber);

            // 5. Encode that bytes
            bytes memory encodedBytesInput;
            if (randomBytes.length == 0) {
                encodedBytesInput = hex"80";
            } else if (randomBytes.length == 1 && uint8(randomBytes[0]) < 128) {
                encodedBytesInput = abi.encodePacked(randomBytes[0]);
            } else {
                bytes memory lengthBytes = abi.encodePacked(bytes1(uint8(0x80 + randomBytes.length)));
                encodedBytesInput = bytes.concat(lengthBytes, randomBytes);
            }

            // 7. Push it to the allocated array
            currentPayload[index] = encodedBytesInput;

            // 8. Reduce total_available_bytes by the length of the encoded thing (min(x, 1))
            total_available_bytes -= encodedBytesInput.length;
            index++;
        }

        // I'm building 2 things here from the payload array, a decoded list and an encoded output, to assert at the end
        bytes[] memory decodedList = new bytes[](index);
        bytes memory bytesPayload;

        for (uint8 i = 0; i < index; i++) {
            decodedList[i] = RLPReader.readBytes(currentPayload[i]); //* Assuming I have this function ready
            bytesPayload = abi.encodePacked(bytesPayload, currentPayload[i]); // Converting bytes[] to bytes to concatenate later
        }

        // If the bytes payload is greater than 55 bytes, we have a problem
        if (bytesPayload.length > 55) {
            revert("Bytes payload is greater than 55 bytes");
        }

        // Spec for lists less that 55 byte long: 0xc0 + len(payload), payload
        bytes memory lengthByte = abi.encodePacked(bytes1(uint8(0xc0 + bytesPayload.length)));
        bytes memory encodedInput = bytes.concat(lengthByte, bytesPayload);

        // Assert that reading the encoded input gives us our decoded list
        assertEq(RLPReader.readList(encodedInput), decodedList);
    }

    // Test lists with more than 55 bytes long payload are encoded correctly
    function testFuzz_readList_payloadMoreThan55bytes_succeeds(bytes[] memory _input) external {
        // If empty, force it not to be.
        if (_input.length == 0) {
            _input = new bytes[](1);
        }

        // Make sure that the list payload will always be more than 55 bytes long
        _input[vm.randomUint(0, _input.length - 1)] = vm.randomBytes(55);

        // Init array to build the payload
        bytes[] memory payload = new bytes[](_input.length);

        // Encode the input array.
        for (uint8 i = 0; i < _input.length; i++) {
            if (_input[i].length <= 55) {
                bytes memory lengthByte = abi.encodePacked(bytes1(uint8(0x80 + _input[i].length)));
                bytes memory encodedInputElement = bytes.concat(lengthByte, _input[i]);
                payload[i] = encodedInputElement;
            } else {
                // Call to convert length to bytes helper function
                (uint8 lengthLength, bytes memory lengthBytes) = getLengthBytes(_input[i]);
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

        // Call to convert payload length to bytes helper function
        (uint8 payloadLengthLength, bytes memory payloadLengthBytes) = getLengthBytes(bytesPayload);

        // Spec for lists less that 55 byte long: 0xf7 + len(len(value)), len(value), value
        bytes memory payloadLengthLengthBytes = abi.encodePacked(bytes1(uint8(0xf7 + payloadLengthLength)));
        bytes memory encodedInput = bytes.concat(payloadLengthLengthBytes, payloadLengthBytes, bytesPayload);

        // Output should match our expected output.
        assertEq(RLPReader.readList(encodedInput), _input);
    }
}
