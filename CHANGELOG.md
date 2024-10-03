# [0.0.0] Unreleased - 10-03-2024

## 🚀 New Features

- To be decided

## 🐛 Bug Fixes

- **Token Position Implementation**
  - [#10a8c13](https://github.com/Demali-876/motoko_regex_engine/commit/10a8c130877896551a4735ebde6e56aab7f418ee) **Date: 09-17-2024 | Fix:** Token position now accounts for instances and tokens that span ranges.
  
- **Lazy Greedy Possessive Quantifiers(Lexer)**
  - [#6279c34](https://github.com/Demali-876/motoko_regex_engine/commit/6279c34557a50328ac43555533fbf5708f867679) **Date: 10-03-2024 | Fix:** Lexer correctly identifies lazy possessive and greedy quantifiers, correctly applying ranges to characters, character classes and groups.

-**Lazy Greedy Possessive Quantifiers (Parser and Compiler)** **Date: 10-03-2024 | Fix:**

- Parser Fixes
  - Modified the function to handle the new `QuantifierType` structure, which includes `min`, `max`, and `mode`.
  - Set to use the mode already set by the lexer, ensuring accurate quantifier modes are parsed.
- Compiler Fixes
  - Refactored to directly use the new `QuantifierType` structure `(min, max, mode)` in all quantifier cases.
  - Improved handling of infinite upper bounds `(max = null)` and optional repetitions in bounded ranges

## ❌ Removed

- [#6279c34](https://github.com/Demali-876/motoko_regex_engine/commit/6279c34557a50328ac43555533fbf5708f867679) **Date: 10-03-2024 | Removed:** Removal of `#QuantifierRange` token. All Ranges are now handled by the `#Quantifier` token.
  