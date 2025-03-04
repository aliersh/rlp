// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {RLPReader} from "src/RLPReader.sol";

contract RLPReader_readBytes_Test is Test {
    function test_readBytes_00to7f_succeeds() external pure {
        // Check if all values between 0x00 and 0x7f decodes as the same byte
        for (uint8 i = 0x00; i < 0x80; i++) {
            //? I changed i from decimal to hex for more clarity. Is there a convention to use one or the other?
            bytes memory encodedInput = abi.encodePacked(bytes1(i));
            assertEq(RLPReader.readBytes(encodedInput), encodedInput);
        }
    }

    function test_readBytes_empty_succeeds() external pure {
        // Check if 0x80 decodes as an empty bytes array
        assertEq(RLPReader.readBytes(hex"80"), hex""); //? What's the difference between hex"80", 0x80, bytes1(0x80)?
    }

    function testFuzz_readBytes_1to55bytes_succeeds(
        bytes memory _input
    ) external pure {
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
        bytes memory lengthByte = abi.encodePacked(
            bytes1(uint8(0x80 + _input.length))
        );
        bytes memory encodedInput = bytes.concat(lengthByte, _input);

        // Assert that reading the encoded input gives us our input
        assertEq(RLPReader.readBytes(encodedInput), _input);
    }

    function testFuzz_readBytes_morethan55bytes_succeeds(
        bytes memory _input
    ) external pure {
        // We ensure that any input with length less than 55 becomes a 2-bytes input
        if (_input.length <= 55) {
            _input = abi.encodePacked(keccak256(_input), keccak256(_input));
        }

        // Convert the uint hex value of _input.length to bytes32 for an easy iteration
        bytes32 inputLengthBytes = bytes32(_input.length);

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
            mstore(
                add(lengthBytes, 32),
                shl(mul(sub(32, lengthLength), 8), inputLengthBytes)
            )
        }

        // Less efficient but it works
        // for (uint8 i = 0; i < lengthLength; i++) {
        //    lengthBytes[i] = inputLengthBytes[32 - lengthLength + i];
        // }

        // Spec says that for values longer than 55 bytes, the encoding is:
        // 0xb7 + len(len(value)), len(value), value
        bytes memory lenghtLenghtBytes = abi.encodePacked(
            bytes1(uint8(0xb7 + lengthLength))
        ); // correct!
        bytes memory encodedInput = bytes.concat(
            lenghtLenghtBytes,
            lengthBytes,
            _input
        );

        // Assert that reading the encoded input gives us our input
        assertEq(RLPReader.readBytes(encodedInput), _input);
    }

    //Empty list
    function test_readList_empty_succeeds() external pure {
        // Check if 0xc0 decodes as an empty bytes array
        bytes[] memory result = RLPReader.readList(hex"c0");
        bytes[] memory emptyList = new bytes[](0);

        assertEq(result, emptyList);
    }

    //List with 1 element less than 55 bytes long
    function test_readList_one_element_1to55bytes_succeeds(
        bytes memory _input
    ) external pure {
        // We don't care about values longer than 54 bytes, we can safely clobber the memory here.
        if (_input.length > 54) {
            assembly {
                mstore(_input, 54)
            }
        }

        // Encoding single element of the array
        bytes memory elementLengthByte = abi.encodePacked(
            bytes1(uint8(0x80 + _input.length))
        );
        bytes memory payload = bytes.concat(elementLengthByte, _input);

        // 0xc0 + len(payload), payload
        bytes memory lengthPayload = abi.encodePacked(
            bytes1(uint8(0xc0 + payload.length))
        );
        bytes memory encodedInput = bytes.concat(lengthPayload, payload);

        // Generate our expected output
        bytes[] memory expectedOutput = new bytes[](1);
        expectedOutput[0] = _input;

        // Assert that reading the encoded input gives us our expected output
        assertEq(RLPReader.readList(encodedInput), expectedOutput);
    }

    //List with 2 elements less than 55 bytes long
    function test_readList_two_element_1to55bytes_succeeds(
        bytes memory _input1,
        bytes memory _input2
    ) external pure {
        // We don't care about values longer than 26 bytes, we can safely clobber the memory here.
        if (_input1.length > 26) {
            assembly {
                mstore(_input1, 26)
            }
        }

        // We don't care about values longer than 26 bytes, we can safely clobber the memory here.
        if (_input2.length > 26) {
            assembly {
                mstore(_input2, 26)
            }
        }

        //Encoding elements of the array
        bytes memory firstElementLengthByte = abi.encodePacked(
            bytes1(uint8(0x80 + _input1.length))
        );
        bytes memory secondElementLengthByte = abi.encodePacked(
            bytes1(uint8(0x80 + _input2.length))
        );
        bytes memory payload = bytes.concat(
            firstElementLengthByte,
            _input1,
            secondElementLengthByte,
            _input2
        );

        // 0xc0 + len(payload), payload
        bytes memory lengthPayload = abi.encodePacked(
            bytes1(uint8(0xc0 + payload.length))
        );
        bytes memory encodedInput = bytes.concat(lengthPayload, payload);

        // Generate our expected output
        bytes[] memory expectedOutput = new bytes[](2);
        expectedOutput[0] = _input1;
        expectedOutput[1] = _input2;

        // Assert that reading the encoded input gives us our expectedOutput
        assertEq(RLPReader.readList(encodedInput), expectedOutput);
    }

    function testFuzz_readList_payload1to55bytes_succeeds(
        uint8 _length
    ) external {
        // Allocate an array of bytes, 55 elements long (bytes[])
        bytes[] memory currentPayload = new bytes[](55); //? is it better to init an empty array?
        uint8 index = 0;

        // 1. Start with total_available_bytes = _length (bounded to 1, 54)
        uint256 total_available_bytes = bound(_length, 1, 54);

        // 2. If total_avalable_bytes = 0, start to encode the thing
        while (total_available_bytes > 0) {
            // 3. Pick a random number between 0 and total_available_bytes = x
            uint256 randomNumber = vm.randomUint(0, total_available_bytes); //? min 0 or 1?

            // 4. Generate a random bytes with length x
            bytes memory randomBytes = vm.randomBytes(randomNumber);

            // 5. Encode that bytes
            bytes memory lengthBytes = abi.encodePacked(
                bytes1(uint8(0x80 + randomBytes.length))
            );

            // 6. Add it to our encoded input
            bytes memory encodedBytesInput = bytes.concat(lengthBytes, randomBytes);

            // 7. Push it to the allocated array
            currentPayload[index] = encodedBytesInput;

            // 8. Reduce total_available_bytes by the length of the encoded thing (min(x, 1))
            total_available_bytes -= encodedBytesInput.length;
            index++;
        }

        // Reduce the size of the allocated array to the actual number of inputs
        bytes[] memory payload = new bytes[](index);

        // I'm building 2 things here from the payload array, a decoded list and an encoded output, to assert at the end
        bytes[] memory decodedList;
        bytes memory bytesPayload;
        
        for (uint8 i = 0; i < index; i++) { 
            payload[i] = currentPayload[i];
            decodedList[i] = RLPReader.readBytes(payload[i]); //* Assuming I have this function ready
            bytesPayload = abi.encodePacked(bytesPayload, payload[i]); // Converting bytes[] to bytes to concatenate later //? Could I use concat here?
        }

        // Spec for lists less that 55 byte long: 0xc0 + len(payload), payload
        bytes memory lengthByte = abi.encodePacked(
            bytes1(uint8(0xc0 + payload.length))
        );
        bytes memory encodedInput = bytes.concat(lengthByte, bytesPayload);

        // Assert that reading the encoded input gives us our decoded list
        assertEq(RLPReader.readList(encodedInput), decodedList);
    }

    function testFuzz_readList_payloadMoreThan55bytes_succeeds(
        bytes[] memory _input
    ) external {
        // If empty, force it not to be.
        if (_input.length == 0) {
            _input = new bytes[](1);
        }

        // Make sure that the list payload will always be more than 55 bytes long
        _input[vm.randomUint(0, _input.length - 1)] = vm.randomBytes(55);

        // Encode the input array.
        for (uint8 i =0; i < _input.length; i++) {
            if (_input[i].length < 55) {
                bytes memory lengthByte = abi.encodePacked(bytes1(uint8(0x80 + _input.length)));
                bytes memory encodedInputElement = bytes.concat(lengthByte, _input[i]);
            } else {
                //lengthLength???
                // bytes memory lenghtLenghtBytes = abi.encodePacked(bytes1(uint8(0xb7 + lengthLength)));
            }
        }

        // Generate the expected output array.

        // Output should match our expected output.
        // assertEq(RLPReader.readList(encodedInput), expectedOutput);
    }
}
