# inspectRegex()

Returns a detailed text representation of the NFA structure for a compiled regular expression pattern.

## Overview

The `inspectRegex()` function allows you to examine the internal NFA (Non-deterministic Finite Automaton) structure of a compiled regular expression. This is particularly useful for debugging complex patterns and understanding how the regex engine processes matches.

## Return Value

- Type: `Result.Result<Text, RegexError>`
- Success: Returns `#ok(Text)` with formatted NFA representation
- Error: Returns `#err(#NotCompiled)` if regex is not compiled

## Example: Social Security Number Pattern

```motoko
// Create regex for basic SSN pattern: ^\d{3}-\d{2}-\d{4}$
let regex = Regex.new("^\\d{3}-\\d{2}-\\d{4}$");

// Inspect the NFA structure
switch(regex.inspectRegex()) {
    case (#ok(nfa)) Debug.print(nfa);
    case (#err(e)) Debug.print("Error: Not compiled");
};
```

### Example Output

```
=== NFA State Machine ===
Initial State → 0
Accept States → [11]

=== Transitions ===
From State 0:
  #Range('0', '9') → 1 (#Greedy)

From State 1:
  #Range('0', '9') → 2 (#Greedy)

From State 2:
  #Range('0', '9') → 3 (#Greedy)

From State 3:
  #Char('-') → 4

From State 4:
  #Range('0', '9') → 5 (#Greedy)

From State 5:
  #Range('0', '9') → 6 (#Greedy)

From State 6:
  #Char('-') → 7

From State 7:
  #Range('0', '9') → 8 (#Greedy)

From State 8:
  #Range('0', '9') → 9 (#Greedy)

From State 9:
  #Range('0', '9') → 10 (#Greedy)

From State 10:
  #Range('0', '9') → 11 (#Greedy)

=== Assertions ===
Anchor: {aType = #StartOfString; position = 0}
Anchor: {aType = #EndOfString; position = 11}
```

## Pattern Breakdown

The NFA structure represents the SSN pattern `^\d{3}-\d{2}-\d{4}$` as follows:

1. Start anchor at position 0
2. States 0-2: First three digits (`\d{3}`) with greedy quantifiers
3. State 3: Literal hyphen (`-`)
4. States 4-5: Next two digits (`\d{2}`) with greedy quantifiers
5. State 6: Second hyphen (`-`)
6. States 7-10: Final four digits (`\d{4}`) with greedy quantifiers
7. State 11: Accept state
8. End anchor at position 11
