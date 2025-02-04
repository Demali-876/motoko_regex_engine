# Backreferences

## Introduction

Backreferences allow a regular expression to match repeated substrings by referring back to a previously captured group. They enable patterns to enforce consistency within the matched text.

## Syntax

Backreferences use the following syntax:

- `\1, \2, ...`: Refers to a numbered capturing group in order of appearance and can only be used in `replace` and `sub` methods.
- `\k<name>`: Refers to a named capturing group and can be used within matching.

### Example

```regex
(?<greeting>hello)\s+\k<greeting>
```

This matches hello followed by one or more space followed by hello again.
