#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cli="$repo_root/bin/flutter_local_helper"

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if ! grep -Fq "$needle" <<<"$haystack"; then
    printf 'Expected output to contain: %s\n' "$needle" >&2
    exit 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if grep -Fq "$needle" <<<"$haystack"; then
    printf 'Did not expect output to contain: %s\n' "$needle" >&2
    exit 1
  fi
}

test_finds_ui_strings() {
  local temp_dir
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN

  mkdir -p "$temp_dir/lib"
  cat >"$temp_dir/lib/demo.dart" <<'EOF'
import 'package:flutter/widgets.dart';

class Demo {
  Widget build() {
    return Column(
      children: const [
        Text('Welcome back'),
        TextButton(
          onPressed: null,
          child: Text('Save changes'),
        ),
      ],
    );
  }
}
EOF

  local output
  output="$("$cli" --root "$temp_dir")"

  assert_contains "$output" '['
  assert_contains "$output" '"file":"lib/demo.dart","line":7,"column":14,"text":"Welcome back"'
  assert_contains "$output" '"file":"lib/demo.dart","line":10,"column":23,"text":"Save changes"'
}

test_ignores_technical_strings() {
  local temp_dir
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN

  mkdir -p "$temp_dir/lib"
  cat >"$temp_dir/lib/technical.dart" <<'EOF'
const image = 'assets/icons/home.png';
const api = 'https://example.com/v1';
const route = 'settings_route';
EOF

  local output
  output="$("$cli" --root "$temp_dir")"

  assert_contains "$output" '['
  assert_contains "$output" ']'
  assert_not_contains "$output" 'settings_route'
}

test_reports_positions_and_sorting() {
  local temp_dir
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN

  mkdir -p "$temp_dir/lib"
  cat >"$temp_dir/lib/b.dart" <<'EOF'
final label = Text('Second file');
EOF

  cat >"$temp_dir/lib/a.dart" <<'EOF'
class Demo {
  void build() {
    final label = Text('First file');
  }
}
EOF

  local output
  output="$("$cli" --root "$temp_dir")"

  assert_contains "$output" '['
  assert_contains "$output" '"file":"lib/a.dart","line":3,"column":24,"text":"First file"'
  assert_contains "$output" '"file":"lib/b.dart","line":1,"column":20,"text":"Second file"'

  if ! printf '%s' "$output" | perl -0ne 'my $a = index($_, q{"file":"lib/a.dart"}); my $b = index($_, q{"file":"lib/b.dart"}); exit($a >= 0 && $b > $a ? 0 : 1)'; then
    printf 'Expected sorted output with lib/a.dart before lib/b.dart\n' >&2
    exit 1
  fi
}

test_writes_output_file() {
  local temp_dir
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN

  mkdir -p "$temp_dir/lib"
  cat >"$temp_dir/lib/demo.dart" <<'EOF'
final label = Text('Reset password');
EOF

  local output_file="$temp_dir/strings.json"
  "$cli" --root "$temp_dir" --output "$output_file"

  if [[ ! -s "$output_file" ]]; then
    printf 'Expected output file to be created\n' >&2
    exit 1
  fi

  local saved_output
  saved_output="$(cat "$output_file")"
  assert_contains "$saved_output" '"text":"Reset password"'
}

test_handles_interpolation_and_nested_strings() {
  local temp_dir
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN

  mkdir -p "$temp_dir/lib"
  cat >"$temp_dir/lib/interpolation.dart" <<'EOF'
class Demo {
  String message(bool value, String name) {
    return Text('Status: ${value ? 'enabled' : 'disabled'} for $name');
  }
}
EOF

  local output
  output="$("$cli" --root "$temp_dir")"

  assert_contains "$output" '"file":"lib/interpolation.dart","line":3,"column":17,"text":"Status: ${value ? '\''enabled'\'' : '\''disabled'\''} for $name"'
}

test_merges_adjacent_string_literals() {
  local temp_dir
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN

  mkdir -p "$temp_dir/lib"
  cat >"$temp_dir/lib/adjacent.dart" <<'EOF'
class Demo {
  void build() {
    final label = Text('Hello, '
      'world'
      '! Welcome');
  }
}
EOF

  local output
  output="$("$cli" --root "$temp_dir")"

  assert_contains "$output" '"file":"lib/adjacent.dart","line":3,"column":24,"text":"Hello, world! Welcome"'
}

test_supports_raw_and_triple_quoted_strings() {
  local temp_dir
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN

  mkdir -p "$temp_dir/lib"
  cat >"$temp_dir/lib/multiline.dart" <<'EOF'
class Demo {
  void build() {
    final title = Text(r'Use $HOME now');
    final body = Text('''First line
Second line''');
  }
}
EOF

  local output
  output="$("$cli" --root "$temp_dir")"

  assert_contains "$output" '"text":"Use $HOME now"'
  assert_contains "$output" '"text":"First line\nSecond line"'
}

test_ignores_interpolation_only_strings() {
  local temp_dir
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN

  mkdir -p "$temp_dir/lib"
  cat >"$temp_dir/lib/interpolation_only.dart" <<'EOF'
class Demo {
  void build(User user) {
    final a = Text('$user');
    final b = Text('${user.name}');
    final c = Text('${formatter.formatTotal()}');
  }
}
EOF

  local output
  output="$("$cli" --root "$temp_dir")"

  assert_not_contains "$output" '"file":"lib/interpolation_only.dart"'
}

test_keeps_interpolation_with_literal_context() {
  local temp_dir
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN

  mkdir -p "$temp_dir/lib"
  cat >"$temp_dir/lib/interpolation_context.dart" <<'EOF'
class Demo {
  void build(User user) {
    final a = Text('Hello $user');
    final b = Text('Total: ${formatter.formatTotal()}');
  }
}
EOF

  local output
  output="$("$cli" --root "$temp_dir")"

  assert_contains "$output" '"text":"Hello $user"'
  assert_contains "$output" '"text":"Total: ${formatter.formatTotal()}"'
}

test_finds_ui_strings
test_ignores_technical_strings
test_reports_positions_and_sorting
test_writes_output_file
test_handles_interpolation_and_nested_strings
test_merges_adjacent_string_literals
test_supports_raw_and_triple_quoted_strings
test_ignores_interpolation_only_strings
test_keeps_interpolation_with_literal_context

printf 'All tests passed.\n'
