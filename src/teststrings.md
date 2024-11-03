# Comprehensive List of Test Strings for Regex Engine

### 1. Character Literals

- `a` — Single character.
- `abc` — Concatenation of characters.

### 2. Character Classes

- `[a-z]` — Character range from 'a' to 'z'.
- `[aeiou]` — Specific set of characters.
- `[^0-9]` — Negated character class, any character except digits.
- `[a-z]{2,4}` — Character class with a quantifier.
- `[a-z]*` — Character class with a quantifier (zero or more repetitions).
- `[\w\d]` — Combination of word and digit metacharacters.

### 3. Quantifiers

- `a*` — Zero or more of 'a'.
- `b+` — One or more of 'b'.
- `c?` — Zero or one of 'c'.
- `d{2,5}` — Between 2 and 5 occurrences of 'd'.
- `(ab)+` — One or more repetitions of the group 'ab'.
- `(cd){3}` — Exactly three repetitions of the group 'cd'.
- `.*` — Zero or more of any character.

### 4. Nested Quantifiers

- `(a*)*` — Zero or more repetitions of a group that itself has a quantifier (nested Kleene star).
- `(b+)+` — One or more repetitions of a group that already has a quantifier.
- `([a-z]{2,4}){1,3}` — Between 1 and 3 repetitions of a character class range with quantifier.
- `((ab)*)+` — Nested group with quantifiers, repeating both inner and outer groups.

### 5. Metacharacters

- `.` — Matches any character.
- `\d` — Matches any digit (0-9).
- `\D` — Matches any non-digit.
- `\w` — Matches any word character (letters, digits, underscore).
- `\W` — Matches any non-word character.
- `\s` — Matches any whitespace character.
- `\S` — Matches any non-whitespace character.

### 6. Grouping and Group Modifiers

- `(abc)` — Capturing group with literal characters.
- `(?:abc)` — Non-capturing group.
- `(?=abc)` — Positive lookahead.
- `(?!abc)` — Negative lookahead.
- `(?<=abc)` — Positive lookbehind.
- `(?<!abc)` — Negative lookbehind.
- `(a|b|c)` — Alternation within a group.

### 7. Alternation

- `a|b|c` — Matches 'a', 'b', or 'c'.
- `(ab|cd|ef)` — Group with alternation, matches 'ab', 'cd', or 'ef'.
- `(a|b)+` — One or more repetitions of 'a' or 'b'.

### 8. Anchors

- `^abc` — Matches 'abc' at the start of the string.
- `abc$` — Matches 'abc' at the end of the string.
- `\bword\b` — Matches the word 'word' with word boundaries.
- `\Bword\B` — Matches 'word' not at a word boundary.

### 9. Complex Combinations

- `^(abc|def)+$` — Matches one or more repetitions of 'abc' or 'def', starting and ending at the line boundaries.
- `\d{3}-\d{2}-\d{4}` — Matches a pattern like a Social Security number.
- `(\w+)\s+(\w+)` — Matches two words separated by whitespace.
- `(?:(a|b){2,4})+` — Non-capturing group with nested quantifiers.
- `(\d{2,4}[a-z]*)?` — Optional group that matches between 2 to 4 digits followed by zero or more letters.
- `([a-zA-Z]+(?:\d*)?)` — Group with alternation and optional parts.
