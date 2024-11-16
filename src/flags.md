# Flags

Flags modify the behavior of the regex engine:

- `CASE_SENSITIVE`: Makes matching case-insensitive.
- `MULTILINE`: Allows `^` and `$` to match at line boundaries.

Example:

```motoko
let regex = Regex.Regex("abc", ?{caseSensitive =false});
