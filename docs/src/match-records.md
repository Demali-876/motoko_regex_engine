# Overview

The `Match` record represents the result of a pattern matching operation on text, typically used in regular expression or string matching operations. It contains detailed information about what was matched, where it was found, and any captured groups within the match.

## Structure

```motoko
public type Match = {
    string: Text;
    value: Text;
    status: {
        #FullMatch;
        #NoMatch;
    };
    position: (Nat, Nat);
    capturedGroups: ?[(Text,Nat)];
    spans: [(Nat, Nat)];
    lastIndex: Nat;
};
```

## Field Descriptions

### string: Text

The original input string that was searched for matches. This field preserves the complete text that was analyzed during the matching operation.

### value: Text

The actual matched substring found in the original text. This represents the specific portion of text that satisfied the matching criteria.

### status

An enumerated type that indicates the match result:

- `#FullMatch`: Indicates a successful match was found
- `#NoMatch`: Indicates no match was found in the input string

### position: (Nat, Nat)

A tuple containing the start and end indices of the match in the original string:

- First value: Starting index of the match
- Second value: Ending index of the match

### capturedGroups: ?[(Text,Nat)]

An optional array of tuples containing captured groups from the match:

- Each tuple contains:
  - Text: The captured text
  - Nat: The index of the captured group
- `null` if no groups were captured

### spans: [(Nat, Nat)]

An array of tuples representing the character spans of the respective match

### lastIndex: Nat

The index where the last match ended. This is particularly useful when performing multiple sequential matches on the same text.

## Usage Examples

### Basic Match Checking

```motoko
if (matchResult.status == #FullMatch) {
    Debug.print("Found match: " # matchResult.value);
} else {
    Debug.print("No match found");
};
```

### Working with Captured Groups

```motoko
switch (matchResult.capturedGroups) {
    case (null) { Debug.print("No groups captured") };
    case (?groups) {
        for ((text, index) in groups.vals()) {
            Debug.print("Group " # debug_show(index) # ": " # text);
        };
    };
};
```
