#!/usr/bin/env bash
# generate-index.sh — Scan docs/*/index.html for <title> tags and build
# a root docs/index.html linking to each sub-page.
#
# Usage: bash scripts/generate-index.sh

set -euo pipefail

DOCS_DIR="docs"
OUT="$DOCS_DIR/index.html"

# Collect entries: relative path + title
# Searches both docs/*/index.html and docs/chunks/*/index.html
entries=()
while IFS= read -r html_file; do
  # Build the relative path from docs/ to the folder containing index.html
  rel_path="${html_file#$DOCS_DIR/}"        # e.g. "chunks/uncertainty_in_regionalGVA/index.html"
  rel_dir="$(dirname "$rel_path")"          # e.g. "chunks/uncertainty_in_regionalGVA"
  display_name="$(basename "$rel_dir")"
  # Extract content of first <title> tag
  title=$(sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' "$html_file" | head -1)
  # Fall back to folder name if no title found
  [ -z "$title" ] && title="$display_name"
  entries+=("$rel_dir|$title")
done < <(find "$DOCS_DIR" -mindepth 2 -maxdepth 3 -name "index.html" -not -path "$OUT" | sort)

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
  rel_dir="${entry%%|*}"
  title="${entry#*|}"
  cat >> "$OUT" <<LINK
    <li><a href="${rel_dir}/">${title}</a> <span class="folder">${rel_dir}/</span></li>
LINK
done

cat >> "$OUT" <<'FOOTER'
  </ul>
  <footer>Auto-generated index — updated on each push.</footer>
</body>
</html>
FOOTER

echo "Generated $OUT with ${#entries[@]} entries."
