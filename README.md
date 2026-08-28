# GitTrailers

Parse, serialize, and manipulate Git commit-message trailers in pure Elixir, with behavior anchored to `git interpret-trailers` and zero runtime dependencies.

[![CI](https://github.com/ivan-podgurskiy/git_trailers/actions/workflows/ci.yml/badge.svg)](https://github.com/ivan-podgurskiy/git_trailers/actions/workflows/ci.yml)
[![Hex version](https://img.shields.io/hexpm/v/git_trailers.svg)](https://hex.pm/packages/git_trailers)
[![Hex downloads](https://img.shields.io/hexpm/dt/git_trailers.svg)](https://hex.pm/packages/git_trailers)
[![HexDocs](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/git_trailers)
[![Elixir 1.14+](https://img.shields.io/badge/Elixir-1.14%2B-purple?logo=elixir&logoColor=white)](https://hex.pm/docs/elixir)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Git trailers are structured `Key: value` records in the final block of a commit message, such as `Signed-off-by`, `Reviewed-by`, `Fixes`, and `Co-authored-by`. Their detection rules are more precise than a footer regex: Git supports folded values, configurable separators, a 25% tolerance rule, recognized keys, and patch-divider handling.

`git_trailers` implements those rules for in-memory binaries. It never shells out, reads Git configuration, touches a repository, or performs network access.

## Installation

Add `git_trailers` to your dependencies:

```elixir
def deps do
  [
    {:git_trailers, "~> 1.0"}
  ]
end
```

## Parse

`GitTrailers.parse/2` returns a tagged result containing the subject, body, block position, divider status, and parsed trailer structs:

```elixir
message = """
Add audit export

Keep the report ordering stable.

Reviewed-by: Alice <alice@example.com>
Signed-off-by: Bob <bob@example.com>
"""

{:ok, result} = GitTrailers.parse(message)

result.subject
#=> "Add audit export"

result.body
#=> "\nKeep the report ordering stable.\n"

Enum.map(result.trailers, &{&1.key, &1.value})
#=> [
#=>   {"Reviewed-by", "Alice <alice@example.com>"},
#=>   {"Signed-off-by", "Bob <bob@example.com>"}
#=> ]

result.block_start
#=> 4
```

Message content is never considered malformed. If Git's block rules do not accept a trailer block, parsing succeeds with `trailers: []` and `block_start: -1`. Invalid argument types and invalid options raise `ArgumentError`.

Folded RFC 822-style values are unfolded by default while exact source bytes remain in `raw`:

```elixir
{:ok, %{trailers: [trailer]}} =
  GitTrailers.parse("subject\n\nCc: Alice\n  Bob\n")

trailer.value
#=> "Alice Bob"

trailer.raw
#=> "Cc: Alice\n  Bob\n"
```

Set `unfold: false` to keep physical folding in `value` as well.

### Parse options

- `:separators` — accepted separator characters; defaults to `":"`. The first matching character on a line is retained in `trailer.separator`.
- `:divider` — stop before a `---` patch divider; defaults to `true`.
- `:unfold` — join continuation lines with spaces; defaults to `true`.
- `:known_keys` — additional case-insensitive keys that count as recognized for Git's 25% trailer-block rule.

```elixir
GitTrailers.parse(message,
  separators: ":%=",
  known_keys: ["Audit-key"],
  divider: false,
  unfold: false
)
```

## Add and update trailers

`GitTrailers.add/3` accepts `{key, value}` tuples, maps with `:key` and `:value`, or parsed `GitTrailers.Trailer` structs:

```elixir
GitTrailers.add(
  "Fix export\n",
  [
    {"Fixes", "#42"},
    %{key: "Reviewed-by", value: "Alice <alice@example.com>"}
  ]
)
#=> "Fix export\n\nFixes: #42\nReviewed-by: Alice <alice@example.com>\n"
```

When a trailer block exists, additions are applied sequentially and key matching is case-insensitive. The default behavior adds at the end unless the same key and value are already adjacent to that insertion point.

### Placement and duplicate policies

`where` controls placement:

- `:end` — at the end of the block; the default.
- `:start` — at the beginning of the whole block.
- `:after` — after the last matching key, or at the end when absent.
- `:before` — before the first matching key, or at the end when absent.

`if_exists` controls a trailer whose key already exists:

- `:add_if_different_neighbor` — add unless the insertion neighbor has the same key and value; the default.
- `:add_if_different` — add unless any matching trailer has the same value.
- `:add` — always add.
- `:replace` — replace the matching trailer nearest the insertion point.
- `:do_nothing` — leave the message unchanged.

`if_missing` is `:add` by default and may be set to `:do_nothing`. Use `trim_empty: true` to remove existing whitespace-only trailers and ignore incoming empty values.

```elixir
GitTrailers.add(message, [{"Reviewed-by", "Bob"}],
  where: :after,
  if_exists: :add_if_different,
  if_missing: :add,
  trim_empty: true
)
```

No-op mutations return the original binary byte-for-byte. When a block changes, that block is emitted with LF and canonical spacing; bytes outside it, including CRLF content and divider material, are preserved.

## Format and serialize

Format one trailer with a one-character separator:

```elixir
GitTrailers.format({" Fixes ", " #42 "})
#=> "Fixes: #42"

GitTrailers.format(%{key: "Bug", value: "42"}, "#")
#=> "Bug# 42"
```

Serialize a collection in canonical form. The result uses LF between records and has no final newline:

```elixir
GitTrailers.serialize([{"Fixes", "#42"}, {"Reviewed-by", "Alice"}])
#=> "Fixes: #42\nReviewed-by: Alice"
```

Keys may contain ASCII letters, digits, and hyphens. Values may contain ordinary Unicode text but not CR or LF; use parsed folded values rather than constructing multiline serializer input.

## Git compatibility

The implementation targets the behavior documented by `git-interpret-trailers(1)` and Git 2.54.0's `trailer.c`:

- A block must be preceded by a blank or whitespace-only line.
- An all-trailer final paragraph is accepted.
- A mixed paragraph requires a recognized Git prefix or a key supplied through `:known_keys`, with trailer records satisfying Git's 25% rule.
- Continuation lines begin with a space or tab.
- `---` dividers and the standard scissors line bound the message region examined by default.
- Configured separators are explicit options; ambient Git configuration is never read.

CI runs the language-neutral conformance corpus shared with the TypeScript `git-trailers` package and performs differential comparisons against a pinned Git 2.54.0 binary. The suite also includes real-world Linux and AI-attribution fixtures, property tests, and 100% production-module coverage.

## Compatibility

- Elixir 1.14 through 1.20 and OTP 25 through 29 are exercised in CI.
- Linux, macOS, and Windows are covered.
- The package has zero runtime dependencies.
- Inputs and outputs are binaries; callers choose how commit messages are obtained.

## Scope

The package parses, formats, serializes, and manipulates commit-message text. It deliberately does not:

- read Git configuration or `trailer.<alias>` definitions;
- execute `cmd` or `command` trailer hooks;
- run Git or read a repository;
- interpret Conventional Commits types, scopes, or breaking-change semantics;
- parse patch or mbox data beyond locating divider boundaries.

Use `git log --format=%B`, a repository library, or another transport layer to obtain the message binary, then pass that binary to `GitTrailers`.

## Provenance

Behavior is tested against independently expressed cases adapted from Git's `t7513-interpret-trailers.sh`, a shared language-neutral corpus, and pinned real-world fixtures. Attribution details are recorded in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## License

MIT. See [LICENSE](LICENSE).
