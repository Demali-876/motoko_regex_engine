# Syntax

- [Syntax](#syntax)
  - [Supported Syntax](#supported-syntax)
  - [Quantifiers](#quantifiers)
    - [Supported Quantifiers](#supported-quantifiers)
    - [Quantifier Modes](#quantifier-modes)
    - [Invalid Quantifiers](#invalid-quantifiers)
  - [Metacharacters](#metacharacters)
  - [Character Classes](#character-classes)
    - [Nested Quantifiers](#nested-quantifiers)
  - [Anchors](#anchors)
  - [Groups and Group Modifiers](#groups-and-group-modifiers)
    - [Supported Group Modifiers](#supported-group-modifiers)
  - [Escaped Characters](#escaped-characters)
  - [Prohibited Patterns](#prohibited-patterns)
  - [Error Handling](#error-handling)
    - [Error Types](#error-types)

---

## Supported Syntax

Motoko regex supports a variety of syntax features for defining patterns. These include:

- Character matching (`a`, `b`, `c`, etc.)
- Alternation (`|`)
- Grouping (`()`)
- Character classes (`[]` with support for ranges like `[a-z]`)
- Quantifiers (`*`, `+`, `?`, `{n}`, `{n,m}`)
- Anchors (`^`, `$`)

---

## Quantifiers

Quantifiers specify how many times a preceding element must occur for a match.

### Supported Quantifiers

| Quantifier   | Meaning                                    | Example          |
|--------------|--------------------------------------------|------------------|
| `*`          | Match 0 or more times | `a*` matches "", "a", "aaa" |
| `+`          | Match 1 or more times | `a+` matches "a", "aaa" |
| `?`          | Match 0 or 1 time                        | `a?` matches "", "a" |
| `{n}`        | Match exactly `n` times                  | `a{2}` matches "aa" |
| `{n,}`       | Match at least `n` times                 | `a{2,}` matches "aa", "aaa" |
| `{n,m}`      | Match between `n` and `m` times          | `a{2,4}` matches "aa", "aaa", "aaaa" |

### Quantifier Modes

Quantifiers can operate in different modes:

- **Greedy:** Matches as many occurrences as possible.
- **Lazy (`?` after quantifier):** Matches as few as possible. E.g., `a*?` matches fewer occurrences of "a".
- **Possessive (`+` after quantifier):** Prevents backtracking. E.g., `a*+`.

### Invalid Quantifiers

Certain quantifier patterns are not allowed:

- Redundant modifiers, such as `a{2}+` or `a{2}?+`.
- Empty quantifiers, e.g., `{}` or `{,}`.
- Multiple commas in ranges, e.g., `{2,,4}`.

---

## Metacharacters

Metacharacters represent special patterns or symbols.

| Metacharacter | Meaning                       | Example         |
|---------------|-------------------------------|-----------------|
| `.`           | Match any character except `\n` | `a.b` matches "acb" |
| `\w`          | Match word characters (alphanumeric + `_`) | `\w+` matches "abc123" |
| `\W`          | Match non-word characters     | `\W` matches "@" |
| `\d`          | Match digits (`0-9`)          | `\d+` matches "123" |
| `\D`          | Match non-digits              | `\D` matches "a" |
| `\s`          | Match whitespace              | `\s+` matches "   " |
| `\S`          | Match non-whitespace          | `\S` matches "a" |

---

## Character Classes

Character classes allow matching sets of characters.

- `[abc]`: Matches any character `a`, `b`, or `c`.
- `[^abc]`: Matches any character except `a`, `b`, or `c`.
- `[a-z]`: Matches any character in the range `a` to `z`.

### Nested Quantifiers

Quantifiers inside character classes must be explicitly defined. Nested or redundant quantifiers, like `[a-z]{2}+`, are not allowed.

---

## Anchors

Anchors specify positions in the text.

| Anchor       | Meaning                      | Example          |
|--------------|------------------------------|------------------|
| `^`          | Start of the string          | `^abc` matches "abc" at the beginning |
| `$`          | End of the string            | `abc$` matches "abc" at the end |
| `\b`         | Word boundary                | `\bword\b` matches "word" |
| `\B`         | Non-word boundary            | `\Bword` matches "word" not at a boundary |

---

## Groups and Group Modifiers

Groups are enclosed in parentheses `()` and can be modified for specific behaviors.

### Supported Group Modifiers

| Modifier          | Syntax       | Meaning                         |
|-------------------|--------------|---------------------------------|
| Non-capturing     | `(?:...)`    | Groups without capturing        |
| Positive Lookahead | `(?=...)`   | Asserts that what follows matches |
| Negative Lookahead | `(?!...)`   | Asserts that what follows does not match |
| Positive Lookbehind | `(?<=...)` | Asserts that what precedes matches |
| Negative Lookbehind | `(?<!...)` | Asserts that what precedes does not match |

---

## Escaped Characters

Escape sequences represent special characters.

| Escape Sequence | Meaning                        |
|------------------|--------------------------------|
| `\\`             | Literal backslash             |
| `\n`             | Newline                       |
| `\t`             | Tab                           |
| `\w`, `\W`       | Word/Non-word characters      |
| `\d`, `\D`       | Digit/Non-digit               |
| `\s`, `\S`       | Whitespace/Non-whitespace     |

Invalid escape sequences throw an error.

---

## Prohibited Patterns

- Invalid group modifiers: e.g., `(?)`.
- Empty groups: `()` is not allowed.
- Empty character classes: `[]` results in an error.
- Redundant or conflicting quantifiers: `a{2}+`.

---

## Error Handling

The Motoko regex engine provides detailed error feedback to help developers identify and fix issues in their regular expressions. Below is a list of all possible errors, their meanings, and typical scenarios where they might occur.

### Error Types

| **Error**                    | **Description**                                                                                                      | **Cause**                                                                                  |
|------------------------------|----------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------|
| **`#UnexpectedCharacter`**   | An invalid character was encountered during parsing.                                                                | Using a character that is not allowed in regex syntax, such as unescaped special characters. |
| **`#UnexpectedEndOfInput`**  | The regex input ended unexpectedly, leaving constructs incomplete.                                                  | Omitting closing brackets, parentheses, or quantifier ranges.                             |
| **`#GenericError`**          | A generic error message providing additional context.                                                               | Various syntax or logic errors not covered by specific error types.                       |
| **`#InvalidQuantifierRange`**| A malformed or invalid quantifier range was used.                                                                   | Using invalid quantifier syntax, e.g., `{,}`, `{,3}`, `{a,b}`.                            |
| **`#InvalidEscapeSequence`** | An invalid escape sequence was encountered.                                                                         | Using unrecognized escape sequences like `\q` or `\x` without proper syntax.              |
| **`#UnmatchedParenthesis`**  | A closing parenthesis `)` does not match any preceding opening parenthesis `(`.                                     | Missing or extra closing parentheses in the regex pattern.                                |
| **`#MismatchedParenthesis`** | Parentheses do not form a valid pairing.                                                                            | Nested parentheses are incorrectly matched or unbalanced, e.g., `((a)b])`.               |
| **`#UnexpectedToken`**       | An unexpected token was encountered during parsing.                                                                 | Using misplaced or unrecognized tokens in the regex pattern.                              |
| **`#UnclosedGroup`**         | A group construct is not properly closed with a closing parenthesis `)`.                                            | Missing a closing parenthesis in a group definition.                                      |
| **`#InvalidQuantifier`**     | A quantifier is malformed or applied in an invalid context.                                                         | Using redundant or conflicting quantifiers, e.g., `a{2}+`.                                |
| **`#EmptyExpression`**       | The regex input is empty or contains no valid expressions.                                                          | Providing an empty string or expression with no meaningful content.                       |
| **`#NotCompiled`**           | The regex has not been compiled before attempting to use it.| There was an error during compilation of the reject object, this may be due to any of the previous errors. That error will be specified in the `#NotCompiled` variant.                             |

---
