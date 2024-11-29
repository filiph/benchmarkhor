Here, I experiment with `gnuplot` to output violin graphs of given data.
This is based on the
[`violinplot.dem`](https://gnuplot.sourceforge.net/demo_svg_6.0/violinplot.html)
example from gnuplot docs.

First, you have to [install `gnuplot`](http://gnuplot.info/).

How to use:

1. Provide two `.dat` files to compare. The file format is simple: a single
   number per line.
2. Edit the beginning of `violin.p` to point to those files.
3. In the `gnuplot/` directory, 
   run `gnuplot -p "violin.p"` to generate the plot and show it in a window.
4. Run `gnuplot "violin.p"` if you just want to output the file 
   and don't want to see the window.
