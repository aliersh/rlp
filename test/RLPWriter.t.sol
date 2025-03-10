// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { RLPWriter } from "src/RLPWriter.sol";
import "../src/utils/RLPHelpers.sol";
import "forge-std/StdJson.sol";

contract RLPWriter_writeBytes_Test is Test {
    function test_writeBytes_empty_succeeds() external pure {
        assertEq(RLPWriter.writeBytes(hex""), hex"80");
    }

    function test_writeBytes_00to7f_succeeds() external pure {
        for (uint8 i = 0; i < 128; i++) {
            bytes memory encodedInput = abi.encodePacked(bytes1(i));
            assertEq(RLPWriter.writeBytes(encodedInput), encodedInput);
        }
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
        (uint8 lengthLength, bytes memory lengthBytes) = RLPHelpers.getLengthBytes(_input);

        // Spec says that for values longer than 55 bytes, the encoding is:
        // 0xb7 + len(len(value)), len(value), value
        bytes memory lengthLengthBytes = abi.encodePacked(bytes1(uint8(0xb7 + lengthLength))); // correct!
        bytes memory encodedInput = bytes.concat(lengthLengthBytes, lengthBytes, _input);

        // Assert that reading the encoded input gives us our input
        assertEq(RLPWriter.writeBytes(_input), encodedInput);
    }
}

contract RLPWriter_writeBytes_standard_Test is Test {
    using stdJson for string;
    string jsonData = vm.readFile("./test/testdata/rlptest.json");

    function _runVectorTest(string memory testCase) internal view {
        string memory inputStr = stdJson.readString(jsonData, string.concat(".", testCase, ".in"));
        string memory outputStr = stdJson.readString(jsonData, string.concat(".", testCase, ".out"));
        bytes memory input = bytes(inputStr);
        bytes memory output = vm.parseBytes(outputStr);
        assertEq(RLPWriter.writeBytes(input), output);
    }

    function test_writeBytes_standard_emptystring_succeeds() external view {
        _runVectorTest("emptystring");
    }

    function test_writeBytes_standard_bytestring00_succeeds() external view {
        _runVectorTest("bytestring00");
    }

    function test_writeBytes_standard_bytestring01_succeeds() external view {
        _runVectorTest("bytestring01");
    }

    function test_writeBytes_standard_bytestring7F_succeeds() external view {
        _runVectorTest("bytestring7F");
    }

    function test_writeBytes_standard_shortstring_succeeds() external view {
        _runVectorTest("shortstring");
    }

    function test_writeBytes_standard_shortstring2_succeeds() external view {
        _runVectorTest("shortstring2");
    }

    function test_writeBytes_standard_longstring_succeeds() external view {
        _runVectorTest("longstring");
    }

    function test_writeBytes_standard_longstring2_succeeds() external view {
        _runVectorTest("longstring2");
    }
}

// // contract RLPWriter_writeList_Test is Test {
// //     function testFuzz_writeList_empty_succeeds(bytes[] memory _input) external pure {
// //         // TODO
// //     }

// //     function testFuzz_writeList_payload1to55bytes_succeeds(uint8 _length) external pure {
// //         // TODO
// //     }

//     function testFuzz_writeList_payloadmorethan55bytes_succeeds(uint8 _length) external pure {
//         TODO
// //     }
// // }
