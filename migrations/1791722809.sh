echo "Let herdr's tab bar show the terminal's background, so it turns glassy too"

config="$HOME/.config/herdr/config.toml"

# Only a tab bar still on the shipped black changes; any other choice is kept.
if [[ -f $config ]] && grep -qx 'panel_bg = "black"' "$config" && ! grep -q '^surface_dim' "$config"; then
  sed -i 's/^panel_bg = "black"$/panel_bg = "reset"\nsurface_dim = "black"/' "$config"
  omarchy-restart-herdr || true
fi
