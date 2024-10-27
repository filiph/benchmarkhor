original_file = "baseline-battery-after-upgrade.dat"
original_name = "baseline"
new_file = "baseline-battery-only-1-raycast.dat"
new_name = "only 1 raycast"

export_to_png = 0
export_size = 1100
export_file_name = "output.png"

if (export_to_png) {
    set terminal pngcairo size export_size, export_size enhanced font 'Arial,16'
    set output export_file_name
}


# Generate a reusable set of data points from a mixture of Gaussians
# nsamp = 3000 

# set print $viol1
# do for [i=1:nsamp] {
#     y = (i%4 == 0) ? 300. +  70.*invnorm(rand(0)) \
#       : (i%4 == 1) ? 400. +  10.*invnorm(rand(0)) \
#       :              120. +  40.*invnorm(rand(0))
#     print sprintf(" 35.0 %8.5g", y)
# }
# unset print

# $viol1 << EOD
#   plot 'baseline-A.dat'
# EOD

# $viol2 << EOD
#   plot 'baseline-B.dat'
# EOD

# stats 'baseline-A.dat' nooutput
# $viol1 << EOD
#     plot 'baseline-A.dat' using 1
# EOD

# $viol1 << EOD
# 5140
# 4352
# 5368
# 5422
# 5263
# 5370
# 5379
# 4981
# 5534
# 5351
# 4920
# 5381
# EOD

# stats 'baseline-B.dat' nooutput
# $viol2 << EOD
#     plot 'baseline-B.dat' using 1
# EOD


# set print $viol2
# do for [i=1:nsamp] {
#     y = (i%4 == 0) ? 300. +  70.*invnorm(rand(0)) \
#       : (i%4 == 1) ? 250. +  10.*invnorm(rand(0)) \
#       :               70. +  20.*invnorm(rand(0))
#     print sprintf(" 34.0 %8.5g", y)
# }
# unset print


set border 2
set xrange [33:36]
set xtics ("A" 34, "B" 35)
set xtics nomirror scale 0
set ytics nomirror rangelimited
unset key

set jitter overlap first 2
set title font ",15"
set title "swarm jitter with a large number of points\n approximates a violin plot"
set style data points

set linetype  9 lc "#80bbaa44" ps 0.5 pt 5
set linetype 10 lc "#8033bbbb" ps 0.5 pt 5

# plot $viol1 lt 9, $viol2 lt 10

# pause -1 'Hit <cr> to continue'

set title "Gaussian random jitter"
unset jitter

J = 0.1
# plot $viol1 using ($1 + J*invnorm(rand(0))):2 lt 9, \
#      $viol2 using ($1 + J*invnorm(rand(0))):2 lt 10 

# pause -1 "Hit <cr> to continue"

set title "Same data - kernel density"
set style data filledcurves below
set auto x
set xtics 0,50,500
unset ytics
set border 3
set margins screen .15, screen .85, screen .15, screen .85
set key

# plot "baseline-A.dat" using 1:(1) smooth kdensity bandwidth 50. with filledcurves above x1 lt 9 title 'B', \
#      "baseline-B.dat" using 1:(1) smooth kdensity bandwidth 50. with filledcurves above x1 lt 10 title 'A'

# pause -1 "Hit <cr> to continue"

#
# Save each kernel density plot to a data block 
# Then replot, mirrored, along the vertical axis
#

set title "kdensity mirrored sideways to give a violin plot"

bandwidth_setting = 100.

set table $kdensity1
plot original_file smooth kdensity bandwidth bandwidth_setting with filledcurves above y lt 9
set table $kdensity2
plot new_file smooth kdensity bandwidth bandwidth_setting with filledcurves above y lt 10
unset table
# unset key

set border 2
unset margins
unset xtics
set ytics nomirror rangelimited

set title 'Violin plots for the win'

set xrange [-1:5]

set style fill solid bo -1
set boxwidth 0.075
set errorbars lt black lw 1

set ylabel "Frame time (µs)"

frame_budget_sixty = 1000000 / 60
frame_budget_onetwenty = 1000000 / 120

# set ytics add ("60Hz" frame_budget_sixty)
set arrow from graph 0, first frame_budget_sixty to graph 1, first frame_budget_sixty nohead lc "#80bb4444" lw 1
set label 1 "60Hz" at graph 0.95, first frame_budget_sixty offset 0, 0.5 tc "#80bb4444" font ",10"

# set ytics add ("120Hz" frame_budget_onetwenty)
set arrow from graph 0, first frame_budget_onetwenty to graph 1, first frame_budget_onetwenty nohead lc "#10cccccc" lw 1
set label 2 "120Hz" at graph 0.95, first frame_budget_onetwenty offset 0, 0.5 tc "#10cccccc" font ",10"


plot 0 with lines lt 2 lc rgb "black" notitle, \
    1000000 / 60 with lines lt 2 lc "#80bb4444" notitle, \
    1000000 / 120 with lines lt 2 lc "#10cccccc" notitle, \
    $kdensity1 using (1 + $2/2.):1 with filledcurve x=1 lt 10 title original_name, \
    '' using (1 - $2/2.):1 with filledcurve x=1 lt 10 notitle, \
    $kdensity2 using (3 + $2/2.):1 with filledcurve x=3 lt 9 title new_name, \
    '' using (3 - $2/2.):1 with filledcurve x=3 lt 9 notitle, \
    original_file using (1):1 with boxplot fc "white" lw 2 notitle, \
    new_file using (3):1 with boxplot fc "white" lw 2 notitle

# # pause -1 "Hit <cr> to continue"



# replot original_file using (1):1 with boxplot fc "white" lw 2 notitle, \
#        new_file using (3):1 with boxplot fc "white" lw 2 notitle



# pause -1 "Hit <cr> to continue"

reset
