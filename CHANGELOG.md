# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-08-28

### Added

- `GitTrailers.parse/2` with Git-compatible final-block detection, the 25% rule, folded values, exact raw source preservation, configurable separators, known keys, and divider handling.
- `GitTrailers.add/3` with all `where`, `if_exists`, and `if_missing` policies plus empty-value trimming and byte-faithful no-op behavior.
- `GitTrailers.format/2` and `GitTrailers.serialize/1` for validated canonical trailer output.
- Structured `%GitTrailers.Result{}` and `%GitTrailers.Trailer{}` values with Elixir typespecs and ExDoc documentation.
- Shared TypeScript/Elixir conformance fixtures, Git 2.54.0 differential checks, real-world acceptance fixtures, property tests, and 100% production-module coverage.
- Hex package metadata and CI across Elixir 1.14–1.20 on Ubuntu, macOS, and Windows.

[1.0.0]: https://github.com/ivan-podgurskiy/git_trailers/releases/tag/v1.0.0
