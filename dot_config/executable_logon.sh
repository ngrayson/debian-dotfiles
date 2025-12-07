# ~/.profile or sway config exec lines
# export GDK_SCALE=2
# export GDK_DPI_SCALE=0.5   # Adjust for your screen
# export QT_SCALE_FACTOR=2
# export QT_AUTO_SCREEN_SCALE_FACTOR=0
# export QT_FONT_DPI=192

#wait for waybar to finish loading
sleep 1

swaymsg splith

kitty -e zsh -is eval 'sleep 1 && fetch'&
sleep 0.100


kitty -e zsh -is eval 'sleep 1 && btm'&
sleep 0.100


## swaymsg "[con_mark="zsh"]" focus 
sleep 2.400
swaymsg move right
swaymsg focus left
swaymsg resize set width 400px
swaymsg splitv
#
kitty -e zsh -is eval 'sleep 0.6 && clock'&
sleep 2.400
swaymsg move up
swaymsg resize set height 160px
