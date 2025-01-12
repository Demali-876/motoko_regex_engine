# **replace()**

The `replace()` function substitutes matches in the input string with a specified replacement string. This function allows specifying a maximum number of replacements (`maxReplacements`).

---

## **Signature**

```motoko
public func replace(text: Text, replacement: Text, maxReplacements: ?Nat): Result.Result<Text, RegexError>
```

---

### **Parameters**

| Parameter        | Type        | Description                                                             |
|-------------------|-------------|-------------------------------------------------------------------------|
| `text`           | `Text`      | The input string to perform replacements on.                           |
| `replacement`    | `Text`      | The string to replace matches with.                                    |
| `maxReplacements`| `?Nat`      | Optional limit on the number of replacements. If `null`, replaces all. |

---

### **Return Value**

`Result.Result<Text, RegexError>`:

- **On Success** (`Text`):
  - The updated string after performing replacements.
- **On Failure** (`RegexError`):
  - Indicates why the operation failed (e.g., invalid regex or replacement).

---

### **Behavior**

1. **Input Validation**:
   - Checks if the regex has been compiled.
   - Returns `#NotCompiled` error if unavailable.

2. **Replacement Process**:
   - Matches the regex pattern in the input string.
   - Replaces each match with the specified string.
   - Respects the `maxReplacements` limit if provided.

3. **Result Construction**:
   - Returns the updated string on success.
   - Returns `RegexError` for invalid inputs or uncompiled regex.

---

### **Example Usage**

#### **1. Replace All Matches**

```motoko
let replaceRegex = Regex.Regex("Hello");
let result = replaceRegex.replace("Hello world, Hello universe", "Hi", null);

switch (result) {
  case (#ok(updatedText)) {
    Debug.print("Updated text: " # updatedText);
  };
  case (#err(error)) {
    Debug.print("Error: " # debug_show(error));
  };
}
```

**Output**:

```
Updated text: Hi world, Hi universe
```

---

#### **2. Replace with Limit**

```motoko
let replaceRegex = Regex.Regex("Hello");
let result = replaceRegex.replace("Hello world, Hello universe", "Hi", ?1);

switch (result) {
  case (#ok(updatedText)) {
    Debug.print("Updated text: " # updatedText);
  };
  case (#err(error)) {
    Debug.print("Error: " # debug_show(error));
  };
}
```

**Output**:

```
Updated text: Hi world, Hello universe
```

---
