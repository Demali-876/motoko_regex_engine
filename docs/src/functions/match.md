# **Overview**

The `match()` function is a core API for performing regex-based matching. It takes an input string and matches it against a precompiled regex represented as an NFA. The function handles matching mechanics, including state transitions, greedy and lazy quantifiers, and group captures.

---

## **Signature**

```motoko
public func match(text: Text): Result.Result<Match, RegexError>
```

---

### **Parameters**

| Parameter | Type        | Description                                                                 |
|-----------|-------------|-----------------------------------------------------------------------------|
| `text`    | `Text`      | The input string to be matched against the compiled regex.                 |

---

### **Return Value**

`Result.Result<Match, RegexError>`:

- **On Success** (`Match`):
  - Contains details of the match, such as the matched substring, captured groups, and spans.
- **On Failure** (`RegexError`):
  - Indicates why the matching process failed (e.g., regex not compiled).

---

### **Behavior**

1. **Input Validation**:
   - Checks if the regex has been compiled.
   - Returns `#NotCompiled` error if the regex is unavailable.

2. **Matching Process**:
   - Delegates the actual matching logic to the `matcher.match` function.
   - Traverses the NFA based on input characters.
   - Respects greedy and lazy quantifier modes.
   - Handles capture groups and anchors (e.g., `^`, `$`).

3. **Result Construction**:
   - Builds a `Match` object for successful matches.
   - Returns `RegexError` for failures.

---

### **Example Usage**

#### **1. Successful Match**

```motoko
let pattern = Regex.Regex("h.*o",null); 
let result = pattern.match("hello");

switch (result) {
  case (#ok(match)) {
    Debug.print("Matched value: " # match.value);
  };
  case (#err(error)) {
    Debug.print("Error: " # debug_show(error));
  };
}
```

**Output**:

```
Matched value: hello
```

---

#### **2. No Match**

```motoko
let pattern = Regex.Regex("z+",null);
let result = pattern.match("hello");

switch (result) {
  case (#ok(match)) {
    Debug.print("Matched value: " # match.value);
  };
  case (#err(error)) {
    Debug.print("Error: " # debug_show(error));
  };
}
```

**Output**:

```
#ok: status = #NoMatch
```

---

#### **Input Validation**

- Before matching, the function ensures the regex is compiled.
- If `nfa` is `null`, the function returns:

  ```motoko
  #err(#NotCompiled)
  ```

---

#### **Delegation to `matcher.match`**

- The compiled NFA, input `text`, and optional `flags` are passed to `matcher.match`.
- `matcher.match` performs:
  - **State Transitions**:
    - Moves between states in the NFA based on input characters.
  - **Greedy and Lazy Quantifiers**:
    - Greedy quantifiers consume as much input as possible.
    - Lazy quantifiers stop at the first valid match.
  - **Capture Groups**:
    - Tracks and extracts group matches.
  - **Anchors**:
    - Ensures patterns anchored to the start (`^`) or end (`$`) are respected.

---
