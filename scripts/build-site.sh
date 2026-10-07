#!/usr/bin/env bash
# Assemble the GitHub Pages site into an output directory (default: _site).
#
# Every folder under projects/ that has an index.html is published at
# /<project-name>/, with Markdown files (specs, logs) left out. A root
# index.html linking to each project is generated from each project's
# <title> and <meta name="description">.
#
# Usage: scripts/build-site.sh [output-dir]
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="${1:-$repo_root/_site}"

html_escape() {
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

# Print the first match of a sed -n pattern from a file, or nothing.
extract() {
  sed -n "$1" "$2" | head -n 1
}

rm -rf "$out"
mkdir -p "$out"
out="$(cd "$out" && pwd)"  # absolute, since the copy below runs from each project dir
touch "$out/.nojekyll"

items=""
for dir in "$repo_root"/projects/*/; do
  [[ -f "$dir/index.html" ]] || continue
  name="$(basename "$dir")"

  mkdir -p "$out/$name"
  (cd "$dir" && find . -type f ! -name '*.md' -exec cp --parents -t "$out/$name/" {} +)

  title="$(extract 's:.*<title>\(.*\)</title>.*:\1:p' "$dir/index.html")"
  desc="$(extract 's:.*<meta name="description" content="\([^"]*\)".*:\1:p' "$dir/index.html")"
  title="$(printf '%s' "${title:-$name}" | html_escape)"
  desc="$(printf '%s' "$desc" | html_escape)"

  items+="      <li><a href=\"$name/\"><span class=\"name\">$title</span>"
  [[ -n "$desc" ]] && items+="<span class=\"desc\">$desc</span>"
  items+="</a></li>"$'\n'
  echo "published: $name/ ($title)"
done

cat > "$out/index.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>black-lion</title>
  <style>
    :root {
      --bg: #f0f2f5; --surface: #ffffff; --border: #e2e5ea;
      --text: #1a1a1a; --text-muted: #6b7280; --accent: #4f46e5;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #111318; --surface: #1b1e25; --border: #2b2f38;
        --text: #e8e9ec; --text-muted: #9aa0ab; --accent: #8b85ff;
      }
    }
    * { box-sizing: border-box; }
    body {
      margin: 0; padding: 3rem 1rem; background: var(--bg); color: var(--text);
      font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    }
    main { max-width: 40rem; margin: 0 auto; }
    h1 { margin: 0 0 1.5rem; font-size: 1.75rem; }
    ul { list-style: none; margin: 0; padding: 0; display: grid; gap: 0.75rem; }
    a {
      display: block; padding: 1rem 1.25rem; border-radius: 10px;
      background: var(--surface); border: 1px solid var(--border);
      color: inherit; text-decoration: none;
    }
    a:hover, a:focus-visible { border-color: var(--accent); }
    .name { display: block; font-weight: 600; color: var(--accent); }
    .desc { display: block; margin-top: 0.25rem; color: var(--text-muted); font-size: 0.95rem; }
  </style>
</head>
<body>
  <main>
    <h1>black-lion</h1>
    <ul>
$items    </ul>
  </main>
</body>
</html>
EOF

echo "site written to $out"
