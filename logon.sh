#wait for waybar to finish loading
sleep 1
# open a terminal and btm
wezterm -e zsh -is eval 'fetch' &
sleep 0.5
wezterm -e zsh -is eval 'btm' &
sleep 0.5
swaymsg focus left
swaymsg move right
swaymsg focus left
swaymsg resize set width 295px
swaymsg splitv
wezterm -e zsh -is eval 'chafa ~/Downloads/polaroid.png' -s 15x30 &
sleep 0.5
swaymsg focus up
# splitv
# wezterm
# focus up
