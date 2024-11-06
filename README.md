# Motoko Regex Engine

A NFA based regular expression engine implemented in Motoko.

⚠️ **Note**: This project is currently under development and not intended for production use.

## Installation

You can install the regex engine using [MOPS](https://mops.one/):

```bash
mops install Regex
```

## Import

```motoko
import Regex "mo:Regex";
```

## Basic Usage

```motoko
// Create a regex using a pattern and set matching flags(multiline and case sensitive matching)
// The pattern is automatically compiled upon instantiation.
let regex = Regex.Regex("abc", null); //

// Match against a string
    switch(regex.match("abcdef")) {
        case (#ok(match)) {
            #ok(match) /A match can have a status to be a full match, partial match or no match. 
            //A match also contains a tuple of the start and end positions of the match, the text value of the match and optional capture group
        };
        case (#err(error)) {
            #err(error)/ The engine provides detailed error types for various failure cases this tracks error from lexical analysis all the way to matching errors.
        };
    };
};
```

## Types

### Match Result

```motoko
public type Match = {
    status: Status;
    position: (Nat, Nat);  // (start, end)
    value: Text;
    capturedGroups: ?[?Text];
};

public type Status = {
    #FullMatch;
    #PartialMatch;
    #NoMatch;
};
```

### Pattern Support

The engine supports various regex constructs:

1. **Basic Characters**
   - Single characters: `a`, `b`, `c`
   - Character ranges: `a-z`, `0-9`

2. **Special Characters**
   - `.` - Any character
   - `\w` - Word character
   - `\d` - Digit
   - `\s` - Whitespace

3. **Quantifiers**
   - `*` - Zero or more
   - `+` - One or more
   - `?` - Zero or one
   - `{n}` - Exactly n
   - `{n,}` - n or more
   - `{n,m}` - Between n and m

4. **Character Classes**
   - `[abc]` - Any of a, b, or c
   - `[^abc]` - Not a, b, or c
   - `[a-z]` - a through z

5. **Anchors**
   - `^` - Start of string
   - `$` - End of string

6. **Groups and Alternation**
   - `(...)` - Capturing group
   - `(?:...)` - Non-capturing group
   - `a|b` - a or b

### Flags

Flags are used to modify matching behavior.

```motoko
public type Flags = {
    caseInsensitive : ?Bool;
    multiline: ?Bool;
};
```

## Error Handling

The engine provides detailed error types for various failure cases, this comprehensive error handling ensures robustness from lexical analysis through to matching. See [Types.mo](src/Types.mo) for full error list.

## Examples

### Basic Matching

```motoko
// Case insensitive matching
let flags = { caseInsensitive = ?true; multiline = null };
let regex2 = Regex.Regex("hello", ?flags);
let result2 = regex2.match("HELLO world");  // Full match: "HELLO"
```

### Pattern Matching

```motoko
// Match digits
let regex3 = Regex.Regex("\\d+", null);
let result3 = regex3.match("123");  // Full match: "123"

// Match with alternation
let regex4 = Regex.Regex("cat|dog", null);
let result4 = regex4.match("cat");  // Full match: "cat"
```

## Contributing

Please see [Contributing Guidelines](CONTRIBUTING.md).
