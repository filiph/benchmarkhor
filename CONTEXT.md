# Context: Benchmarkhor Plotting

This document defines the domain terms used in the `benchmarkhor` plotting utility (`bin/plot.dart` and `lib/src/plot/`).

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
In `benchmarkhor`, the box plot is drawn on top of the violin as a notched box plot, including whiskers and outliers. It uses light-colored outlines and a transparent fill to ensure visibility on dark backgrounds.

### Notch
A visual narrowing of the box plot around the median indicating the 95% confidence interval for the median.
The bounds of the notch are calculated as $\text{median} \pm 1.58 \times \frac{\text{IQR}}{\sqrt{n}}$, narrowing down to 60% of the full box width at the median position. If the notch bounds extend beyond Q1 or Q3 (e.g., due to small sample size or high variability), the notch lines are allowed to extend beyond the box, creating a flipped/flared shape.
_Avoid_: Waist, confidence interval cutoff

### Whisker
The lines extending from the box plot.
In `benchmarkhor`, whiskers extend to the most extreme data points within $1.5 \times IQR$ of the first and third quartiles. These points also define the vertical truncation bounds for the KDE curve.

### Plot Maximum
The upper limit of the **Plot Range**. It is calculated by taking the maximum of all "input maxima".
Each input maximum is defined as `median + (N * IQR)`, where `N` is the `max-outlier-coefficient`. If all measurements in an input are non-positive, its input maximum is bounded at 0.

### Plot Minimum
The lower limit of the **Plot Range**, defined symmetrically to the Plot Maximum: the minimum of all "input minima", where each input minimum is `median - (N * IQR)`. If all measurements in an input are non-negative, its input minimum is bounded at 0.

### Plot Range
The span of data values the plot commits to showing, from **Plot Minimum** to **Plot Maximum**. Data outside the Plot Range is subject to **Outlier Exclusion**. The Plot Range always includes zero (see **Zero Anchoring**).
The Plot Range is a Violin Plot concept only: a Line Plot never discards data, so its range is simply the span of all values (zero-anchored).

### Axis Padding
Extra space added beyond the **Plot Range** so that data does not touch the edge of the drawing area. Padding is added only to an end of the range that is not zero, and amounts to 5% of the Plot Range. A consequence of **Zero Anchoring**: with all-positive data the zero baseline sits flush at the bottom, with all-negative data flush at the top, and data straddling zero is padded at both ends.

### Zero Anchoring
The **Plot Range** always contains the value zero, even when no measurement is near it. Benchmark values are magnitudes, so a zero baseline keeps visual differences honest. Consequently, when every measurement is positive, zero is the bottom of the range; when every measurement is negative, zero is the top.

### Outlier Exclusion
To prevent extreme values from compressing the main visualization, outliers falling outside the **Plot Range** are not drawn.
Instead, a summary note (e.g., `+12 outliers (max 42000)`) is displayed beyond the corresponding edge of the violin's slot: above the slot for values above the Plot Maximum, below it for values below the Plot Minimum.

### Line Plot
A method of plotting a single `.dat` file as a polyline, one point per line of input, in file order. The X-axis is the point's index (not a timestamp or Round number); the Y-axis is the raw value. When multiple inputs are given to `plot line`, all polylines are drawn on shared axes, colored using the same palette as violin plots, for direct comparison.

### Segment
A straight line drawn between two consecutive points of a Line Plot. No smoothing or curve-fitting is applied — a Line Plot is a plain polyline.
