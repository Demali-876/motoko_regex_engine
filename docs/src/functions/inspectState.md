# inspectState(state: Types.State)

Examines and returns the transitions for a specific state in the NFA (Non-deterministic Finite Automaton) structure.

## Overview

The `inspectState()` function allows you to inspect the transitions from any particular state in the compiled regex pattern. This is useful for debugging specific parts of pattern matching behavior.

## Parameters

- `state`: Nat - The state number to inspect

## Return Value

- Type: `Result.Result<Text, RegexError>`
- Success: Returns `#ok(Text)` with formatted transitions from the specified state
- Error: Returns `#err(#NotCompiled)` if regex is not compiled

## Example: Social Security Number Pattern State

Using the same SSN pattern (`^\d{3}-\d{2}-\d{4}$`), let's inspect state 4, which handles the first digit after the first hyphen:

```motoko
let regex = Regex.Regex("^\d{3}-\d{2}-\d{4}$");

switch(regex.inspectState(3)) {
    case (#ok(transitions)) Debug.print(transitions);
    case (#err(e)) Debug.print("Error: Not compiled");
};
```

### Example Output

```
From State 3:
  #Char('-') → 4
```

This shows the transitions available for state 3 in the NFA. There is only one transition available for state 3 which is the dash character.
