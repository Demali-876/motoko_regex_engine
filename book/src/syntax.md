# Regular Expression Syntax

The Motoko Regex Engine supports the following regex syntax:

- **Character classes**: `[abc]`, `[^abc]`, `[a-z]`
- **Quantifiers**: `*`, `+`, `?`, `{m,n}`
- **Anchors**: `^`, `$`
- **Groups**: `(abc)`, `(?:abc)`
- **Escaping special characters**: `\`, `\d`, `\w`

Unsupported features:

- Lookaround assertions (TODO: See case(#lookaround) in matcher line 179 )
- Non-greedy quantifiers (TODO: see case (#Quantifier) in compiler line 79)
- Anchors (TODO: see case (#Anchor) in matcher line 149)
