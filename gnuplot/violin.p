# Settings.

original_file = "baseline-battery-after-upgrade.dat"
original_name = "baseline"
new_file = "baseline-battery-only-1-raycast.dat"
new_name = "only 1 raycast"

export_to_png = 0
export_size = 1100
export_file_name = "output.png"

bandwidth_setting = 100.


# Implementation.

if (export_to_png) {
    set terminal pngcairo size export_size, export_size enhanced font 'Arial,16'
    set output export_file_name
}

set linetype  9 lc "#80bbaa44" ps 0.5 pt 5
set linetype 10 lc "#8033bbbb" ps 0.5 pt 5

set table $kdensity1
plot original_file smooth kdensity bandwidth bandwidth_setting with filledcurves above y lt 9
set table $kdensity2
plot new_file smooth kdensity bandwidth bandwidth_setting with filledcurves above y lt 10
unset table

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
