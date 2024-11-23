# Matching

```motoko
let regex = Regex.Regex("\d{3}-\d{2}-\d{4}", null);
let result = regex.match("629-07-2021");

switch (result) {
  case (#Match(matchRecord)):
    Debug.print("Match found: " # matchRecord.value);
  case (#NoMatch):
    Debug.print("No match found.");
}
```

## Understanding the Matcher

The matcher evaluates the input text against the regex pattern using the following principles:

1. **Full Match Required**: The input must traverse all states of the NFA and reach an accept state.
2. **Immediate Termination**: If a valid path cannot be identified, the matcher stops and returns `#NoMatch`.
3. **First Match Priority**: The matcher stops as soon as it finds a valid match.

---
