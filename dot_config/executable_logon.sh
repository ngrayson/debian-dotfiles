# ~/.profile or sway config exec lines
export GDK_SCALE=2
export GDK_DPI_SCALE=0.5   # Adjust for your screen
export QT_SCALE_FACTOR=2
export QT_AUTO_SCREEN_SCALE_FACTOR=0
export QT_FONT_DPI=192

#wait for waybar to finish loading
sleep 2

wezterm -e zsh -is eval 'sleep 1.9 && fetch'&
sleep 1.000
swaymsg mark zsh

wezterm -e zsh -is eval 'sleep 1 && btm'&
sleep 0.500

swaymsg "[con_mark="zsh"]" focus 
swaymsg resize set width 605px
swaymsg splitv

wezterm -e zsh -is eval 'sleep 0.6 && clock'&
sleep 0.500
swaymsg move up
swaymsg resize set height 290px

swaymsg "[con_mark="zsh"]" focus 

