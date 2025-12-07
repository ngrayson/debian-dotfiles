# ~/.profile or sway config exec lines
# export GDK_SCALE=2
# export GDK_DPI_SCALE=0.5   # Adjust for your screen
# export QT_SCALE_FACTOR=2
# export QT_AUTO_SCREEN_SCALE_FACTOR=0
# export QT_FONT_DPI=192

#wait for waybar to finish loading
sleep 2

kitty -e zsh -is eval 'sleep 1.9 && fetch'&
sleep 1.000
swaymsg mark zsh

kitty -e zsh -is eval 'sleep 1 && btm'&
sleep 1.000

swaymsg "[con_mark="zsh"]" focus 
swaymsg resize set width 400px
swaymsg splitv

kitty -e zsh -is eval 'sleep 0.6 && clock'&
sleep 1.000
swaymsg move up
swaymsg resize set height 160px
swaymsg splith


swaymsg "[con_mark="zsh"]" focus 

