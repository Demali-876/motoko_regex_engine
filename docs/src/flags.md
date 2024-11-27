# Flags

Flags in Motoko regex provide flexibility by modifying the behavior of the regex matching process. This section covers the available flags, their purpose, and how to use them effectively.

---

## Overview

Flags are optional parameters that can alter how the regex engine interprets and processes a pattern. They enable features such as case-insensitive matching and handling multiline inputs.

---

## Available Flags

### **1. CASE_SENSITIVE**

- **Type:** `Bool`
- **Default:** `true`
- **Description:** Determines whether the regex should consider case when matching characters.
- **Behavior:**
  - When `caseSensitive = true`: Matches are case-sensitive (default behavior).
  - When `caseSensitive = false`: Matches are case-insensitive, treating uppercase and lowercase letters as equivalent.
- **Example:**

  ```motoko
  let regex = Regex.Regex("abc", ?{caseSensitive = false});
  assert(regex.search("ABC") == #FullMatch);
  ```

### **2. MULTILINE**

- **Type:** `Bool`
- **Default:** `false`
- **Description:** Alters the behavior of anchors (`^` and `$`) to match at line boundaries rather than the start or end of the entire string.
- **Behavior:**
  - When `multiline = true`:
    - `^` matches the start of any line.
    - `$` matches the end of any line.
  - When `multiline = false` (default behavior):
    - `^` matches the beginning of the entire input.
    - `$` matches the end of the entire input.
- **Example:**

  ```motoko
  let regex = Regex.Regex("^abc$", ?{multiline = true});
  assert(regex.search("abc\ndef\nabc") == #FullMatch);
  ```

---

## Combining Flags

You can combine flags to fine-tune the regex engine's behavior. For example:

```motoko
let regex = Regex.Regex("abc", ?{caseSensitive = false; multiline = true});
assert(regex.search("ABC\ndef\nabc") == #FullMatch);
```

In this example:

- The pattern `abc` is matched regardless of case.
- The engine processes each line independently due to `multiline = true`.

---

## Default Behavior Without Flags

If no flags are specified, the engine uses the following defaults:

- `caseSensitive = true`
- `multiline = false`

This means:

- Matching is case-sensitive.
- Anchors (`^` and `$`) match only at the start and end of the entire input.

---

## Best Practices

- Use `caseSensitive = false` for patterns that need to ignore case differences, such as matching user inputs in a case-insensitive manner.
- Use `multiline = true` when processing multi-line text, such as logs or formatted documents, where each line might have independent matching requirements.

---
