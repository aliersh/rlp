# Ethereum RLP Encoding and Decoding

This project provides a Solidity implementation of Recursive Length Prefix (RLP) encoding and decoding, which is the primary data serialization method used in Ethereum.

## What is RLP?

Recursive Length Prefix (RLP) is a serialization format defined in the Ethereum Yellow Paper. It is designed to encode arbitrarily nested arrays of binary data. RLP is the main encoding method used to serialize objects in Ethereum's execution layer.

The primary purpose of RLP is to encode structure; encoding specific data types (like strings, floats) is left up to higher-order protocols. In Ethereum, RLP is used for encoding transactions, blocks, and other network data structures.

## Implementation

This library provides a Solidity implementation of RLP with three main components:

### Input Types

**Important**: All RLP functions accept only `bytes` or arrays of `bytes` as inputs. Any other data types (strings, integers, booleans, etc.) must be converted to `bytes` format by the user before passing to the RLP encoding functions.

For example:
- To encode a string: first convert it to bytes using `abi.encodePacked(string)`
- To encode an integer: first convert it to its bytes representation using `abi.encodePacked(uint256)`
- For addresses: convert using `abi.encodePacked(address)`

### RLPWriter

The `RLPWriter` library handles encoding data into the RLP format. It provides two main functions:

1. `writeBytes(bytes memory)`: Encodes a single byte array into RLP format
2. `writeList(bytes[] memory)`: Encodes a list of pre-encoded RLP items into an RLP list

The library follows the RLP specification with comprehensive validation and error handling:

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

### RLPReader

The `RLPReader` library handles decoding RLP encoded data back into its original form. It provides two main functions:

1. `readBytes(bytes memory)`: Decodes RLP encoded bytes into the original byte array
2. `readList(bytes memory)`: Decodes an RLP encoded list into an array of RLP items

The library implements comprehensive decoding with validation:

1. **Single byte decoding (0x00-0x7f)**:
   - Returns the byte as a single-element bytes array

2. **String decoding**:
   - Short strings (0x80-0xb7): Extracts length from prefix and returns data
   - Long strings (0xb8-0xbf): Extracts length of length, then length, then data

3. **List decoding**:
   - Short lists (0xc0-0xf7): Extracts items based on prefix length
   - Long lists (0xf8-0xff): Extracts length of length, then length, then items

### RLPHelpers

The `RLPHelpers` library provides essential utility functions used by both the writer and reader:

1. `getLengthBytes(bytes memory)`: Calculates and returns the number of bytes needed for length encoding
2. `getFlattenedArray(bytes[] memory)`: Efficiently concatenates multiple byte arrays
3. `validateRLPItem(bytes memory)`: Performs comprehensive RLP encoding validation:
   - Validates prefix bytes match content length
   - Ensures proper encoding format for different data types
   - Checks for valid length encodings

## Usage

### Encoding Examples

```solidity
// IMPORTANT: All inputs must be bytes or arrays of bytes
import {RLPWriter} from "./RLPWriter.sol";

// Example 1: Encoding different data types
bytes memory encodedAddress = RLPWriter.writeBytes(abi.encodePacked(address(0x123)));
bytes memory encodedUint = RLPWriter.writeBytes(abi.encodePacked(uint256(42)));
bytes memory encodedString = RLPWriter.writeBytes(abi.encodePacked("Hello"));

// Example 2: Encoding a list of items
bytes[] memory items = new bytes[](3);
items[0] = RLPWriter.writeBytes(abi.encodePacked(uint256(1)));
items[1] = RLPWriter.writeBytes(abi.encodePacked("test"));
items[2] = RLPWriter.writeBytes(abi.encodePacked(address(0x123)));
bytes memory encodedList = RLPWriter.writeList(items);

// Example 3: Encoding a nested list
bytes[] memory innerList = new bytes[](2);
innerList[0] = RLPWriter.writeBytes(abi.encodePacked("inner1"));
innerList[1] = RLPWriter.writeBytes(abi.encodePacked("inner2"));
bytes memory encodedInner = RLPWriter.writeList(innerList);

bytes[] memory outerList = new bytes[](2);
outerList[0] = RLPWriter.writeBytes(abi.encodePacked("outer"));
outerList[1] = encodedInner;  // Add the encoded inner list
bytes memory encodedNested = RLPWriter.writeList(outerList);
```

### Decoding Examples

```solidity
import {RLPReader} from "./RLPReader.sol";

// Example 1: Decoding a simple value
bytes memory encoded = hex"8568656c6c6f";  // RLP encoded "hello"
bytes memory decoded = RLPReader.readBytes(encoded);
// decoded now contains the original "hello" bytes

// Example 2: Decoding a list
bytes memory encodedList = hex"c88568656c6c6f8474657374";  // RLP encoding of ["hello", "test"]
bytes[] memory decodedList = RLPReader.readList(encodedList);
// decodedList[0] contains encoded "hello"
// decodedList[1] contains encoded "test"

// Example 3: Working with decoded data
bytes memory decodedItem = RLPReader.readBytes(decodedList[0]);
// Convert back to string if needed:
string memory str = string(decodedItem);
```

## Testing

The implementation includes comprehensive test coverage:

- ✅ RLPWriter
  - Single byte encoding
  - String encoding (short and long)
  - List encoding (short and long)
  - Nested list encoding
  - Error cases

- ✅ RLPReader
  - Single byte decoding
  - String decoding (short and long)
  - List decoding (short and long)
  - Nested list decoding
  - Error handling

Run the tests with:

```shell
$ forge test
```

## References

- [Ethereum Yellow Paper](https://ethereum.github.io/yellowpaper/paper.pdf)
- [RLP Specification](https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp/)
- [Ethereum Wiki on RLP](https://eth.wiki/en/fundamentals/rlp)
