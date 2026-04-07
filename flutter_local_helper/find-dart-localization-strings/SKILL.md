---
name: find-dart-localization-strings
description: Use this skill when the task is to scan a Flutter or Dart project for user-visible string literals that should likely be localized, using the local flutter_local_helper CLI and interpreting its JSON output.
---

# Find Dart Localization Strings

Use this skill when you need a fast local scan of `.dart` files to find strings that are likely visible in the UI and should be reviewed for localization.

## Why use the CLI

Use `./bin/flutter_local_helper` because it is:

- local and deterministic, without depending on Dart, `jq`, or `awk`
- focused on Dart/Flutter string literals that look user-visible
- suitable for quick audits, refactors, and CI-style checks because it emits JSON

## How to use

Run the CLI from the repository root:

```bash
./bin/flutter_local_helper
```

Scan another project root:

```bash
./bin/flutter_local_helper --root /caminho/do/app
```

Scan a different directory relative to the project root:

```bash
./bin/flutter_local_helper --root /caminho/do/app --scan test
```

Write the JSON output to a file:

```bash
./bin/flutter_local_helper --root /caminho/do/app --output strings.json
```

## Output

The command returns a JSON list. Each item contains:

- `file`
- `line`
- `column`
- `text`

Use the output as a review list, not as a guarantee that every entry must be localized.

## Notes

- The scan is heuristic and intentionally ignores many technical strings such as URLs, asset paths, and internal identifiers.
- The parser supports raw strings, triple-quoted strings, interpolation, and adjacent string literals.
- Pure interpolations such as `$value` or `${service.format()}` are ignored unless there is meaningful literal text around them.
- Prefer reviewing matches in UI contexts first, such as `Text(...)`, labels, hints, titles, tooltips, and error messages.
