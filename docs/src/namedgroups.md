# Named Groups

## Introduction

Named capturing groups allow for more readable and maintainable regular expressions by associating a descriptive name with a capturing group. Instead of referring to groups by their numeric index, named groups enable easier access to matched substrings.

## Syntax

Named groups are defined using the following syntax:

```regex
(?<name>pattern)
```

`name`: A unique identifier for the group.

`pattern`: The regular expression pattern to be captured.

Example:

`(?<word>\w+)`

This matches a sequence of word characters and assigns the match to the named group word.

