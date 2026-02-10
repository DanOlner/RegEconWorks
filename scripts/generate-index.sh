#!/usr/bin/env bash
# generate-index.sh — Scan docs/*/index.html for <title> tags and build
# a root docs/index.html linking to each sub-page.
#
# Usage: bash scripts/generate-index.sh

set -euo pipefail

DOCS_DIR="docs"
OUT="$DOCS_DIR/index.html"

# Collect entries: folder name + title
entries=()
while IFS= read -r html_file; do
  folder="$(basename "$(dirname "$html_file")")"
  # Extract content of first <title> tag
  title=$(sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' "$html_file" | head -1)
  # Fall back to folder name if no title found
  [ -z "$title" ] && title="$folder"
  entries+=("$folder|$title")
done < <(find "$DOCS_DIR" -mindepth 2 -maxdepth 2 -name "index.html" | sort)

# Build the HTML
cat > "$OUT" <<'HEADER'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>RegEconWorks</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      max-width: 720px;
      margin: 0 auto;
      padding: 40px 20px;
      background: #fafafa;
      color: #333;
    }
    h1 { font-size: 1.5rem; margin-bottom: 0.3rem; }
    .subtitle { color: #666; font-size: 0.95rem; margin-bottom: 2rem; }
    ul { list-style: none; padding: 0; }
    li { margin-bottom: 0.75rem; }
    a {
      color: #0366d6;
      text-decoration: none;
      font-size: 1.05rem;
    }
    a:hover { text-decoration: underline; }
    .folder {
      color: #999;
      font-size: 0.85rem;
      margin-left: 0.5rem;
    }
    footer {
      margin-top: 3rem;
      padding-top: 1rem;
      border-top: 1px solid #ddd;
      color: #999;
      font-size: 0.8rem;
    }
  </style>
</head>
<body>
  <h1>RegEconWorks</h1>
  <p class="subtitle">Interactive viewers and modular outputs</p>
  <ul>
HEADER

for entry in "${entries[@]}"; do
  folder="${entry%%|*}"
  title="${entry#*|}"
  cat >> "$OUT" <<LINK
    <li><a href="${folder}/">${title}</a> <span class="folder">${folder}/</span></li>
LINK
done

cat >> "$OUT" <<'FOOTER'
  </ul>
  <footer>Auto-generated index — updated on each push.</footer>
</body>
</html>
FOOTER

echo "Generated $OUT with ${#entries[@]} entries."
