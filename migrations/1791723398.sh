echo "Let Neovim's current line show the terminal background"

# ~/.config/nvim is copied once from omarchy-nvim, so its transparency file
# misses the package's later change. The block is the one omarchy-nvim ships,
# added before the loop that applies the list; a file without that loop was
# rewritten by hand and is left alone.
transparency="$HOME/.config/nvim/plugin/after/transparency.lua"
loop='for _, name in ipairs(groups) do'

if [[ -f $transparency ]] && ! grep -qF '"CursorLine"' "$transparency" && grep -qxF "$loop" "$transparency"; then
  block=$(mktemp)
  cat >"$block" <<'LUA'
-- The current line goes see-through too, leaving its number to mark it. The
-- file tree marks its selection with that line alone, so it keeps the colour.
local cursorline = vim.api.nvim_get_hl(0, { name = "CursorLine", link = false })
if cursorline.bg then
	vim.api.nvim_set_hl(0, "NeoTreeCursorLine", { bg = cursorline.bg })
end
table.insert(groups, "CursorLine")

LUA
  awk -v loop="$loop" -v block="$block" '
    $0 == loop && !done { while ((getline line < block) > 0) print line; done = 1 }
    { print }
  ' "$transparency" >"$transparency.new" && mv "$transparency.new" "$transparency"
  rm -f "$block"
fi
