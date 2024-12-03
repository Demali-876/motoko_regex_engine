# Overview

The `search()` function scans an input string for the first occurrence of the regex pattern. Unlike `match()`, which requires the pattern to span the entire input, `search()` identifies the first substring that satisfies the pattern.

## Signature

```motoko
public func search(text: Text): Result.Result<Match, RegexError>
```

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| text | Text | The input string to search for the first match |

## Return Value

**Type**: `Result.Result<Match, RegexError>`

### Success Case

Returns a `Match` object containing:

- The matched substring (`value`)
- The position of the match within the input string
- Captured groups (if any)

### No Match Case

Returns a `Match` object with:

- `status = #NoMatch`
- Empty `value`

### Error Case

Returns `RegexError` (`#NotCompiled`) only if the pattern failed to compile during instantiation

## Behavior

### Input Validation

- If the regex instantiation failed (due to an invalid pattern), returns `RegexError` (`#NotCompiled`)

### Search Process

1. Scans the input string character by character
2. Identifies if a potential match could begin at the current position
3. Delegates to `match()` for full matching starting from that position

### Result Construction

- On finding a match:
  - Returns a `Match` object with details of the match
- If no match is found after scanning the string:
  - Returns a `Match` object with `status = #NoMatch`

## Example Usage

### 1. Successful Match

**Pattern**: `"a+"` **Input**: `"xxaaayy"`

```motoko
let pattern = Regex.Regex("a+", null);
let result = pattern.search("xxaaayy");
switch (result) {
    case (#ok(match)) Debug.print("First match: " # match.value);  // Output: "aaa"
    case (#err(error)) Debug.print("Error: " # debug_show(error));
};
```

**Output**:

```
First match: aaa
```

### 2. No Match Found

**Pattern**: `"z+"` **Input**: `"xxaaaayy"`

```motoko
let pattern = Regex.Regex("z+", null);
let result = pattern.search("xxaaaayy");
switch (result) {
    case (#ok(match)) {
        switch (match.status) {
            case (#NoMatch) Debug.print("No match found.");
            case (#FullMatch) Debug.print("First match: " # match.value);
        };
    };
    case (#err(error)) Debug.print("Error: " # debug_show(error));
};
```

**Output**:
```
No match found.
```

### 3. Invalid Pattern

**Scenario**: Creating a regex with an invalid pattern

```motoko
let pattern = Regex.Regex("[a-");
let result = pattern.search("xxaaaayy");
switch (result) {
    case (#ok(match)) Debug.print("First match: " # match.value);
    case (#err(error)) Debug.print("Error: " # debug_show(error)); // Output: #NotCompiled
};
```

**Output**:

```
Error: #NotCompiled
```
