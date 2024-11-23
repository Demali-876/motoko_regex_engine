# Searching

The `search` function scans the input text from left to right to find a match.

```motoko
let result = regex.search("launch icp 629-07-2021");
switch (result) {
  case (#Match(matchRecord)):
    Debug.print("Search result: " # matchRecord.value);
  case (#NoMatch):
    Debug.print("No match found.");
}
```
