# Ethereum RLP Encoding and Decoding

This project provides a Solidity implementation of Recursive Length Prefix (RLP) encoding and decoding, which is the primary data serialization method used in Ethereum.

## What is RLP?

Recursive Length Prefix (RLP) is a serialization format defined in the Ethereum Yellow Paper. It is designed to encode arbitrarily nested arrays of binary data. RLP is the main encoding method used to serialize objects in Ethereum's execution layer.

The primary purpose of RLP is to encode structure; encoding specific data types (like strings, floats) is left up to higher-order protocols. In Ethereum, RLP is used for encoding transactions, blocks, and other network data structures.

## Implementation

This library provides a Solidity implementation of RLP with two main components:

### Input Types

**Important**: All RLP functions accept only `bytes` or arrays of `bytes` as inputs. Any other data types (strings, integers, booleans, etc.) must be converted to `bytes` format by the user before passing to the RLP encoding functions.

For example:
- To encode a string: first convert it to bytes, then pass to RLPWriter
- To encode an integer: first convert it to its bytes representation, then pass to RLPWriter

### RLPWriter

The `RLPWriter` library handles encoding data into the RLP format. It follows the RLP specification as defined in the Ethereum Yellow Paper:

1. **Single byte encoding**: 
   - For a single byte with value < 0x80, the byte itself is its own RLP encoding
   - For the empty byte array, the RLP encoding is 0x80

2. **String encoding (0-55 bytes)**:
   - Prefix: 0x80 + length of the string
   - Followed by the string itself

3. **String encoding (>55 bytes)**:
   - Prefix: 0xb7 + length of the length
   - Followed by the length of the string
   - Followed by the string itself

4. **List encoding (total payload 0-55 bytes)**:
   - Prefix: 0xc0 + length of the concatenated RLP encodings
   - Followed by the concatenated RLP encodings of the list items

5. **List encoding (total payload >55 bytes)**:
   - Prefix: 0xf7 + length of the length
   - Followed by the length of the concatenated encodings
   - Followed by the concatenated RLP encodings of the list items

### RLPReader [PENDING]

The `RLPReader` library will handle decoding RLP encoded data back into its original form. It will implement the inverse operations of the encoding process:

1. Identify the type and length of the encoded data based on the first byte
2. Extract the raw data according to the identified type and length
3. For lists, recursively decode each item in the list

Current status: Basic structure defined, implementation pending.

### Helper Functions

The `RLPHelpers` library provides utility functions for both encoding and decoding:

1. `getLengthBytes`: Determines the number of bytes needed to represent a length and extracts those bytes
2. `flattenArray`: Concatenates an array of byte arrays into a single byte array

## Usage

### Encoding Data

```solidity
// IMPORTANT: All inputs must be bytes or arrays of bytes

// Example 1: Encoding a byte array
// Note: String literals in Solidity are automatically converted to bytes
bytes memory myData = "Hello, Ethereum!";
bytes memory encoded = RLPWriter.writeBytes(myData);

// Example 2: Encoding an integer (must be converted to bytes first)
uint256 myNumber = 42;
bytes memory numberAsBytes = abi.encodePacked(myNumber);
bytes memory encodedNumber = RLPWriter.writeBytes(numberAsBytes);

// Example 3: Encoding a list
bytes[] memory myList = new bytes[](2);
myList[0] = "item1"; // String literals converted to bytes
myList[1] = "item2";
bytes memory encodedList = RLPWriter.writeList(myList);
```

### Decoding Data [PENDING]

```solidity
// Decoding a byte array
bytes memory encoded = hex"8a48656c6c6f2c20455448"; // RLP encoding of "Hello, ETH"
bytes memory decoded = RLPReader.readBytes(encoded);

// Decoding a list
bytes memory encodedList = hex"c88a48656c6c6f2c20455448847465737421"; // RLP encoding of ["Hello, ETH", "test!"]
bytes[] memory decodedList = RLPReader.readList(encodedList);

// After decoding, the user is responsible for converting the bytes back to their original types
```

## Testing

Current test coverage:
- ✅ RLPWriter.writeBytes() - Complete
- ✅ RLPWriter.writeList() - Complete
- ✅ RLPReader.readBytes() - Complete
- ✅ RLPReader.readList() - Complete

Run the tests with:

```shell
$ forge test
```

## References

- [Ethereum Yellow Paper](https://ethereum.github.io/yellowpaper/paper.pdf)
- [RLP Specification](https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp/)
- [Ethereum Wiki on RLP](https://eth.wiki/en/fundamentals/rlp)
