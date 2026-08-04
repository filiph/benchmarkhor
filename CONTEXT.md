# Context: Benchmarkhor Plotting

This document defines the domain terms used in the `benchmarkhor` plotting utility (`bin/plot.dart`).

## Glossary

### Violin Plot
A method of plotting numeric data. It is similar to a box plot, with the addition of a rotated kernel density plot on each side.
In `benchmarkhor`, the violin plot is rendered as an SVG `<polygon>`. The output is optimized for dark backgrounds (no background color, light-colored elements).

### KDE (Kernel Density Estimation)
A non-parametric way to estimate the probability density function of a random variable.
In this tool, a Gaussian kernel is used to calculate the density of benchmark results.
The density is used to determine the width of the violin at different values along the Y-axis.
In `benchmarkhor`, the KDE curve is **truncated at the whiskers**. Outliers are excluded from both the density estimation and the bandwidth calculation to focus the visualization on the main distribution.

### Bandwidth (bw)
A parameter that determines the smoothness of the KDE.
The tool uses Silverman's rule of thumb by default: $1.06 \times \sigma \times n^{-0.2}$.
When calculating KDE for a violin, the bandwidth is derived only from the non-outlier data.

### Slot
The horizontal area dedicated to a single violin in the plot.
The tool divides the available `plotWidth` into equal slots based on the number of input datasets.

### Box Plot
A standardized way of displaying the distribution of data based on a five-number summary: minimum, first quartile (Q1), median, third quartile (Q3), and maximum.
In `benchmarkhor`, the box plot is drawn on top of the violin, including whiskers and outliers. It uses light-colored outlines and a transparent fill to ensure visibility on dark backgrounds.

### Whisker
The lines extending from the box plot.
In `benchmarkhor`, whiskers extend to the most extreme data points within $1.5 \times IQR$ of the first and third quartiles. These points also define the vertical truncation bounds for the KDE curve.

### Plot Maximum
The upper limit of the Y-axis. It is calculated by taking the maximum of all "input maxima".
Each input maximum is defined as `median + (N * IQR)`, where `N` is the `max-outlier-coefficient`.

### Outlier Exclusion
To prevent extreme values from compressing the main visualization, outliers exceeding the **Plot Maximum** are not drawn. 
Instead, a summary note (e.g., `+12 outliers (max 42000)`) is displayed at the top of the corresponding violin's slot.
