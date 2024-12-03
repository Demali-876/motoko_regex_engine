# Overview

The `findIter()` method returns an iterator that yields all non-overlapping matches of the regex pattern in the input text. This method is memory-efficient as it generates matches lazily instead of collecting them all at once like `findAll()`.

## Signature

```motoko
public func findIter(text: Text): Result.Result<Iter.Iter<Match>, RegexError>
```

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| text | Text | The input string to search for matches |

## Return Value

**Type**: `Result.Result<Iter.Iter<Match>, RegexError>`

### Success Case

Returns an iterator that yields `Match` objects, where each contains:

- The matched substring (`value`)
- The position of the match within the input string
- Any captured groups
- Match status (`#FullMatch`)

### Error Case

Returns `RegexError` (`#NotCompiled`) if the pattern failed to compile during instantiation


### Iteration Process

1. Starts from the beginning of the input string
2. For each match found:
   - Yields a `Match` object
   - Advances to the position after the current match
3. Continues until no more matches are found
4. Automatically handles the internal state between iterations

### Match Generation

- Matches are generated one at a time as the iterator is consumed
- Non-overlapping matches are guaranteed
- The iteration order follows the text from left to right
