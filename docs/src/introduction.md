# Introduction

Welcome to the **Motoko Regex Engine Documentation**, your go-to guide for leveraging the power of regular expressions in the Motoko programming language. This engine provides robust tools for pattern matching, searching, and text processing.

Inspired by other established regex libraries, this regex engine adapts their capabilities to meet the needs of Motoko.

---

## Installation and Import

Install the Motoko Regex Engine using:

```bash
mops add regex
```

Import it into your project with:

```motoko
import Regex "mo:regex";
```

---

## What is a Regular Expression?

A **regular expression** (regex) is a sequence of characters defining a search pattern. Regex is widely used in text processing for tasks such as:

- Searching for text patterns (e.g., keywords in a document).
- Validating formats (e.g., email addresses or phone numbers).
- Extracting data from structured text (e.g., logs or CSV files).

For example, the regex `^\d{3}-\d{2}-\d{4}$` matches a string formatted as a Social Security Number, such as `123-45-6789`.

---

## Key Features

### Pattern Support

- **Anchors**: `^` (start of string), `$` (end of string).
- **Character classes**: `[a-z]`, `[^0-9]`.
- **Quantifiers**: `*`, `+`, `?`, `{m,n}`.
- **Groups**: `()`, `(?:)`.
- **Alternation**: `|` (logical OR).
- **Escapes**: `\d`, `\w`, `\s`, etc.

### Flags

Flags are optional boolean values that modify the behavior of regex matching. They are set during instantiation and cannot be changed afterward. The engine currently supports:

- **`caseSensitive`**: Case-sensitive matching (default is true).
- **`multiline`**: Enables multiline matching.

Example with null flags (default behavior):

```motoko
let regex = Regex.Regex("\d{3}-\d{2}-\d{4}", null);
```

### API Functions

- **`match`**: Check for a full match of the pattern in the input text.
- **`search`**: Locate the first occurrence of the pattern in the input.
- **`findAll`**: Retrieve all matches for the pattern.
- **`findIter`**: Iterate over matches.

---
