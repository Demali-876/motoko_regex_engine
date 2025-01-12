# **split()**

The `split()` function divides a string into substrings based on matches of the regex pattern, with an optional limit on the number of splits (`maxSplit`).

---

## **Signature**

```motoko
public func split(text: Text, maxSplit: ?Nat): Result.Result<[Text], RegexError>
```

---

### **Parameters**

| Parameter  | Type        | Description                                                      |
|------------|-------------|------------------------------------------------------------------|
| `text`     | `Text`      | The input string to be split based on the regex pattern.        |
| `maxSplit` | `?Nat`      | Optional limit on the number of splits. If `null`, splits all.  |

---

### **Return Value**

`Result.Result<[Text], RegexError>`:

- **On Success** (`[Text]`):
  - A vector of substrings resulting from splitting the input string.
- **On Failure** (`RegexError`):
  - Indicates why the operation failed (e.g., invalid regex).

---

### **Behavior**

1. **Input Validation**:
   - Checks if the regex has been compiled.
   - Returns `#NotCompiled` error if unavailable.

2. **Splitting Process**:
   - Matches the regex pattern in the input string.
   - Divides the string at each match, respecting the `maxSplit` limit if provided.
   - Handles edge cases (e.g., no matches or empty input).

3. **Result Construction**:
   - Returns a vector of substrings on success.
   - Returns `RegexError` for invalid inputs or uncompiled regex.

---

### **Example Usage**

#### **1. Splitting Without Limit**

```motoko
let splitRegex = Regex.Regex(",");
let result = splitRegex.split("one,two,three", null);

switch (result) {
  case (#ok(parts)) {
    Debug.print("Split result: " # debug_show(parts));
  };
  case (#err(error)) {
    Debug.print("Error: " # debug_show(error));
  };
}
```

**Output**:

```
Split result: ["one", "two", "three"]
```

---

#### **2. Splitting With Limit**

```motoko
let splitRegex = Regex.Regex(",");
let result = splitRegex.split("one,two,three", ?1);

switch (result) {
  case (#ok(parts)) {
    Debug.print("Split result: " # debug_show(parts));
  };
  case (#err(error)) {
    Debug.print("Error: " # debug_show(error));
  };
}
```

**Output**:

```
Split result: ["one", "two,three"]
```

---
