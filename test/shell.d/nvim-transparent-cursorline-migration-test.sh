#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

migration="$ROOT/migrations/1791723398.sh"
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

transparency="$test_dir/.config/nvim/plugin/after/transparency.lua"
mkdir -p "${transparency%/*}"

run_migration() {
  HOME="$test_dir" bash -euo pipefail "$migration" >/dev/null
}

# The tail of the transparency file omarchy-nvim shipped before the change.
cat >"$transparency" <<'LUA'
local groups = {
	"Normal",
	"CursorLineNr",
}

for _, name in ipairs(groups) do
	make_transparent(name)
end
LUA

run_migration
run_migration

expected=$(cat <<'LUA'
local groups = {
	"Normal",
	"CursorLineNr",
}

-- The current line goes see-through too, leaving its number to mark it. The
-- file tree marks its selection with that line alone, so it keeps the colour.
local cursorline = vim.api.nvim_get_hl(0, { name = "CursorLine", link = false })
if cursorline.bg then
	vim.api.nvim_set_hl(0, "NeoTreeCursorLine", { bg = cursorline.bg })
end
table.insert(groups, "CursorLine")

for _, name in ipairs(groups) do
	make_transparent(name)
end
LUA
)
[[ $(<"$transparency") == "$expected" ]] || fail "the shipped transparency file gains the current line once" "$(cat "$transparency")"
pass "the shipped transparency file gains the current line once"

# A file rewritten by hand, without the shipped loop, is left as it is.
printf 'vim.api.nvim_set_hl(0, "Normal", { bg = "none" })\n' >"$transparency"
cp "$transparency" "$test_dir/custom.lua"
run_migration
cmp -s "$transparency" "$test_dir/custom.lua" || fail "a hand-written transparency file is left alone"
pass "a hand-written transparency file is left alone"

rm "$transparency"
run_migration
[[ ! -e $transparency ]] || fail "a missing transparency file is not created"
pass "a missing transparency file is not created"
