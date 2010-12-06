
convert -delay 2 -loop 0 right*.png right-animate.gif
gifsicle --batch --optimize right-animate.gif
