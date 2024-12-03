# Overview

The `findAll()` method returns an array of all non-overlapping matches of the regex pattern in the input text. Unlike `findIter()`, this method collects all matches at once into an array.

## Signature

```motoko
public func findAll(text: Text): Result.Result<[Match], RegexError>
```

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| text | Text | The input string to search for matches |

## Return Value

**Type**: `Result.Result<[Match], RegexError>`

### Success Case

Returns an array of `Match` objects, where each contains:

- The matched substring (`value`)
- The position of the match within the input string
- Any captured groups
- Match status (`#FullMatch`)

### Error Case

Returns `RegexError` (`#NotCompiled`) if the pattern failed to compile during instantiation

### Match Collection Process

1. Starts from the beginning of the input string
2. Collects all non-overlapping matches into an array
3. Preserves the order of matches as they appear in the text
4. Returns an empty array if no matches are found
