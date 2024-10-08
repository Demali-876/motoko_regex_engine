# [0.0.0] Unreleased - 10-03-2024

## 🚀 New Features

- **Flattened AST Structure**
  - [#420f70a](https://github.com/Demali-876/motoko_regex_engine/commit/420f70a46a0ace335d2be8631b2c372022b8f2f2) **Date: 10-07-2024 | New:** Introduced a new, flattened AST structure to simplify regex expression handling. This includes using lists for concatenations and alternations, reducing the depth of nested expressions.
- **Single Group Token**
  - [#420f70a](https://github.com/Demali-876/motoko_regex_engine/commit/420f70a46a0ace335d2be8631b2c372022b8f2f2) **Date: 10-07-2024 | New:** Introduced a unified `#Group` token that now encapsulates the group modifier and sub-expression, streamlining group handling in both the lexer and the parser.
- **Capture Index Tracking**
  - Implemented capture group index tracking for pre-matching optimization.

## 🐛 Bug Fixes

- **Token Position Implementation**
  - [#10a8c13](https://github.com/Demali-876/motoko_regex_engine/commit/10a8c130877896551a4735ebde6e56aab7f418ee) **Date: 09-17-2024 | Fix:** Token position now accounts for instances and tokens that span ranges.
  
- **Lazy Greedy Possessive Quantifiers (Lexer)**
  - [#6279c34](https://github.com/Demali-876/motoko_regex_engine/commit/6279c34557a50328ac43555533fbf5708f867679) **Date: 10-03-2024 | Fix:** Lexer correctly identifies lazy, possessive, and greedy quantifiers, correctly applying ranges to characters, character classes, and groups.

- **Lazy Greedy Possessive Quantifiers (Parser and Compiler)**
  - [#bdc0aab](https://github.com/Demali-876/motoko_regex_engine/commit/bdc0aab2a6e140c2e55a420fcb3cb0c237f3f1d0) **Date: 10-03-2024 | Fixes (Multiple):**
    - **Parser Fixes**:
      - Modified to handle the new `QuantifierType` structure, which includes `min`, `max`, and `mode`.
      - Ensured that the quantifier modes parsed are those already set by the lexer.
    - **Compiler Fixes**:
      - Refactored to directly use the new `QuantifierType` structure `(min, max, mode)` in all quantifier cases.
      - Improved handling of infinite upper bounds `(max = null)` and optional repetitions in bounded ranges.
  
## 🔄 Changes

- **Reduced Token Count in Lexer**
  - [#420f70a](https://github.com/Demali-876/motoko_regex_engine/commit/420f70a46a0ace335d2be8631b2c372022b8f2f2) **Date: 10-07-2024 | Improved:**Reduced the number of tokens in the lexer by eliminating `#GroupStart` and `#GroupEnd` in favor of a single `#Group` token, simplifying group handling during the parsing process.
- **Unified Group Token**
  - [#420f70a](https://github.com/Demali-876/motoko_regex_engine/commit/420f70a46a0ace335d2be8631b2c372022b8f2f2) **Date: 10-07-2024 | Improved :** Removed the standalone `GroupModifierType` token, integrating it into the `#Group` token type.
- **NextToken() Improvements**
  - [#420f70a](https://github.com/Demali-876/motoko_regex_engine/commit/420f70a46a0ace335d2be8631b2c372022b8f2f2) **Date: 10-07-2024 | Improved:** Removed redundant cases.
- **Complete Parser and Compiler Redesign**
  - Optimized NFA generation using Thompson's Construction Algorithm.
    - Complete Parser rework using new ast structure.
    - Introduction of Parser Errors. Parser now produces an AST or an Error.

## ❌ Removed

- [#6279c34](https://github.com/Demali-876/motoko_regex_engine/commit/6279c34557a50328ac43555533fbf5708f867679) **Date: 10-03-2024 | Removed:** Removed `#QuantifierRange` token. All ranges are now handled by the `#Quantifier` token.
- []() Eliminated Redundant Tokens

---

### **To-Do Checklist**

- [x] **Parser Overhaul | Status: Completed  Date: 10-08-2024** Commit: 
  - [x] Adapt the parser to utilize the new flattened AST structure.
  - [x] Ensure proper handling of the unified `#Group` token, including its modifiers and sub-expression references.

- [x] **NFA Construction | Status: Started Date: 10-08-2024** Commit: 
  - [x] Refactor NFA construction to take advantage of the flattened AST for incremental optimization.
  - [ ] Implement state reduction and bisimulation in the NFA to prevent state explosion.

- [ ] **Incremental Optimization**
  - [ ] Introduce optimizations during NFA construction to reduce unnecessary state transitions.
  - [ ] Merge equivalent states where possible to minimize the NFA's complexity
