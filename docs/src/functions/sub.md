# **sub()**

The `sub()` function substitutes matches in the input string with a specified replacement string. Unlike `replace`, it allows the use of regex patterns in the replacement string.

---

## **Signature**

```motoko
public func sub(text: Text, replacement: Text, maxSubstitutions: ?Nat): Result.Result<Text, RegexError>
```

---

### **Parameters**

| Parameter        | Type        | Description                                                             |
|-------------------|-------------|-------------------------------------------------------------------------|
| `text`           | `Text`      | The input string to perform substitutions on.                          |
| `replacement`    | `Text`      | The string (can include regex) to replace matches with.                |
| `maxSubstitutions`| `?Nat`      | Optional limit on the number of substitutions. If `null`, substitutes all. |

---

### **Return Value**

`Result.Result<Text, RegexError>`:

- **On Success** (`Text`):
  - The updated string after performing substitutions.
- **On Failure** (`RegexError`):
  - Indicates why the operation failed (e.g., invalid regex or replacement).

---

### **Behavior**

1. **Input Validation**:
   - Checks if the regex has been compiled.
   - Returns `#NotCompiled` error if unavailable.

2. **Substitution Process**:
   - Matches the regex pattern in the input string.
   - Substitutes each match with the specified replacement string.
   - Respects the `maxReplacements` limit if provided.

3. **Result Construction**:
   - Returns the updated string on success.
   - Returns `RegexError` for invalid inputs or uncompiled regex.

---

### **Implementation**

```motoko
public func sub(text: Text, replacement: Text, maxReplacements: ?Nat): Result.Result<Text, RegexError> {
    switch (nfa) {
        case (null) #err(#NotCompiled);
        case (?compiledNFA) {
            matcher.sub(compiledNFA, text, replacement, maxReplacements)
        };
    }
};
```

---

### **Example Usage**

#### **1. Substituting All Matches**

```motoko
let subRegex = Regex.Regex("\d+");
let result = subRegex.sub("I have 10 bananas and 20 apples", "many", null);

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
Updated text: I have many bananas and many apples
```

---

#### **2. Substituting with Limit**

```motoko
let subRegex = Regex.Regex("\\d+");
let result = subRegex.sub("I have 10 bananas and 20 apples", "many", ?1);

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
Updated text: I have many bananas and 20 apples
```
