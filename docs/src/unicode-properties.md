# Unicode Support and Unicode Properties

## Introduction

The Motoko Regex Engine supports Unicode properties, allowing users to match specific character categories using `\p{Property}` and `\P{Property}` syntax. This enhances pattern matching by enabling character classification based on Unicode properties.

## Syntax

Unicode properties can be matched using the following syntax:

```regex
\p{Property}   // Matches a character with the specified Unicode property
\P{Property}   // Matches a character that does NOT have the specified Unicode property
```

### Example

```regex
\p{L}   // Matches any letter
\p{N}   // Matches any number
\P{P}   // Matches any character except punctuation
```

## Supported Unicode Properties

The engine supports a subset of Unicode properties:

- `L`  (Letter)
- `Ll` (Lowercase Letter)
- `Lu` (Uppercase Letter)
- `N`  (Number)
- `P`  (Punctuation)
- `Zs` (Separator, Space)
- `Emoji` (Emoji characters)
