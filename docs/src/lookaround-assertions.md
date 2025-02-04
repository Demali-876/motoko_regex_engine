# Lookaround Assertions

## Introduction

Lookaround assertions allow for pattern matching based on surrounding text without including that text in the final match. They enable advanced pattern constraints while maintaining flexibility in regex processing. However, in many cases, using a stricter pattern without lookarounds can be a better approach, leading to simpler and more efficient regex expressions.

## Lookaround Types

Lookaround assertions are divided into **Lookahead** and **Lookbehind**, and each has **Positive** and **Negative** variations. The following table summarizes them:

| Type | Positive | Negative |
|------|---------|---------|
| **Look-Ahead** | `A(?=B)` - Match `A` if `B` follows | `A(?!B)` - Match `A` if `B` does **not** follow |
| **Look-Behind** | `(?<=B)A` - Match `A` if `B` precedes | `(?<!B)A` - Match `A` if `B` does **not** precede |

### Lookahead

- **Positive Lookahead (`?=`)**: Ensures a pattern exists after the current position without consuming it.
- **Negative Lookahead (`?!`)**: Ensures a pattern does *not* exist after the current position.

```regex
foo(?=bar)   // Matches "foo" only if followed by "bar"
foo(?!bar)   // Matches "foo" only if NOT followed by "bar"
```

### Lookbehind

- **Positive Lookbehind (`?<=`)**: Ensures a pattern exists before the current position.
- **Negative Lookbehind (`?<!`)**: Ensures a pattern does *not* exist before the current position.

```regex
(?<=bar)foo   // Matches "foo" only if preceded by "bar"
(?<!bar)foo   // Matches "foo" only if NOT preceded by "bar"
```

## Behavior and Considerations

- Lookaround assertions do not consume characters; they only assert conditions.
- Combining lookahead and lookbehind can create complex matching rules.
- Negative lookaround can be used to enforce exclusions in matching.
- Lookbehind patterns must have a fixed length.
- In many cases, defining a stricter pattern instead of relying on lookaround assertions results in a more efficient and readable regex.

## Conclusion

Lookaround assertions provide powerful matching capabilities without consuming characters. However, in most cases, defining a stricter pattern can lead to better performance and clarity. The Motoko Regex Engine supports both lookahead and lookbehind assertions, but users should consider whether they can achieve the same result with a more precise pattern before resorting to lookarounds.
