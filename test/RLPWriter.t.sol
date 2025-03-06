// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { RLPWriter } from "src/RLPWriter.sol";

contract RLPWriter_TestInit is Test {
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

contract RLPWriter_writeBytes_Test is RLPWriter_TestInit {
    function test_writeBytes_00to7f_succeeds() external pure {
        for (uint8 i = 0x00; i < 0x80; i++) {
            bytes memory encodedInput = abi.encodePacked(bytes1(i));
            assertEq(RLPWriter.writeBytes(encodedInput), encodedInput);
        }
    }

    function test_writeBytes_empty_succeeds() external pure {
        assertEq(RLPWriter.writeBytes(hex""), hex"80");
    }

    function testFuzz_writeBytes_1to55bytes_succeeds(bytes memory _input) external view {
        if (_input.length > 55) {
            _input = vm.randomBytes(55);
        }
        if (_input.length == 0) {
            _input = vm.randomBytes(1);
        }
        if (_input.length == 1 && uint8(_input[0]) < 128) {
            _input = vm.randomBytes(2);
        }

        bytes memory lengthByte = abi.encodePacked(bytes1(uint8(0x80 + _input.length)));
        bytes memory encodedInput = bytes.concat(lengthByte, _input);

        assertEq(RLPWriter.writeBytes(_input), encodedInput);
    }

    function testFuzz_writeBytes_morethan55bytes_succeeds(bytes memory _input) external view {
        if (_input.length <= 55) {
            _input = vm.randomBytes(56);
        }

        // Call to convert length to bytes helper function
        (uint8 lengthLength, bytes memory lengthBytes) = getLengthBytes(_input);

        // Spec says that for values longer than 55 bytes, the encoding is:
        // 0xb7 + len(len(value)), len(value), value
        bytes memory lengthLengthBytes = abi.encodePacked(bytes1(uint8(0xb7 + lengthLength))); // correct!
        bytes memory encodedInput = bytes.concat(lengthLengthBytes, lengthBytes, _input);

        // Assert that reading the encoded input gives us our input
        assertEq(RLPWriter.writeBytes(_input), encodedInput);
    }
}

contract RLPWriter_writeList_Test is RLPWriter_TestInit {
    function testFuzz_writeList_empty_succeeds(bytes[] memory _input) external pure {
        // TODO
    }

    function testFuzz_writeList_payload1to55bytes_succeeds(uint8 _length) external pure {
        // TODO
    }

    function testFuzz_writeList_payloadmorethan55bytes_succeeds(uint8 _length) external pure {
        // TODO
    }
}
