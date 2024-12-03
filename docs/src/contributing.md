# Contributing to Motoko Regex Engine

Thank you for your interest in contributing to the Motoko Regex Engine project! This guide will help you get started with contributing to the project.

## Table of Contents

- [Contributing to Motoko Regex Engine](#contributing-to-motoko-regex-engine)
  - [Table of Contents](#table-of-contents)
  - [Getting Started](#getting-started)
  - [Development Process](#development-process)
  - [Commit Guidelines](#commit-guidelines)
  - [Pull Request Process](#pull-request-process)
  - [Testing Requirements](#testing-requirements)

## Getting Started

1. Fork the repository:
   - Visit <https://github.com/Demali-876/motoko_regex_engine>
   - Click the "Fork" button in the top-right corner

2. Clone your fork:

   ```bash
   git clone https://github.com/YOUR-USERNAME/motoko_regex_engine.git
   cd motoko_regex_engine
   ```

3. Add the upstream repository:

   ```bash
   git remote add upstream https://github.com/Demali-876/motoko_regex_engine.git
   ```

4. Create a new branch for your work:

   ```bash
   git checkout -b feat/your-feature-name
   ```

## Development Process

1. Set up your development environment:
   - Install the DFINITY SDK (dfx)
   - Install Node.js and npm
   - Run `npm install` to install dependencies

2. Make your changes:
   - Keep your changes focused and concise
   - Update documentation if needed

3. Keep your fork up to date:

   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

## Commit Guidelines

We use [Conventional Commits](https://www.conventionalcommits.org/) for clear and standardized commit messages. Each commit message should be structured as follows:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Types:

- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation only changes
- `style`: Changes that do not affect the meaning of the code
- `refactor`: A code change that neither fixes a bug nor adds a feature
- `perf`: A code change that improves performance
- `test`: Adding missing tests or correcting existing tests
- `chore`: Changes to the build process or auxiliary tools

Examples:
```
feat(parser): add support for lookahead assertions

fix(matcher): resolve infinite loop in nested groups

docs: update API documentation for search method

refactor(compiler): simplify NFA construction logic
```

## Pull Request Process

1. Push your changes to your fork:

   ```bash
   git push origin feat/your-feature-name
   ```

2. Create a Pull Request:
   - Go to <https://github.com/Demali-876/motoko_regex_engine/pulls>
   - Click "New Pull Request"
   - Select your fork and branch
   - Fill out the PR template with:
     - Clear description of changes
     - Any breaking changes
     - Evidence of testing (screenshots, console output, etc.)

3. PR Review Process:
   - Maintainers will review your PR
   - Address any requested changes
   - Once approved, your PR will be merged

## Testing Requirements

While formal tests are not required, you must provide evidence that you've tested your changes. This can include:

- Screenshots of the feature working
- Console output showing successful execution
- Example usage and results
- Description of test cases you've tried

Example test evidence in PR:

```
Tested the new alternation operator with:
1. Simple patterns: "a|b" against "a" and "b"
2. Complex patterns: "(foo|bar)+" against "foofoobar"
3. Edge cases: "a||b" and "|a|b|"

Results:
- All patterns matched correctly
- No infinite loops or crashes
- Proper error handling for invalid patterns
```

Thank you for contributing to the Motoko Regex Engine project!
