# Context: Benchmarkhor Plotting

This document defines the domain terms used in the `benchmarkhor` plotting utility (`bin/plot.dart` and `lib/src/plot/`).

## Glossary

### Violin Plot
A method of plotting numeric data. It is similar to a box plot, with the addition of a rotated kernel density plot on each side.
In `benchmarkhor`, the violin plot is rendered as an SVG `<polygon>`. The visual appearance of structural elements adapts according to the selected **Theme** (defaulting to **Dark Theme**).

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
In `benchmarkhor`, the box plot is drawn on top of the violin as a notched box plot, including whiskers and outliers. It uses high-contrast outlines and a transparent fill to ensure visibility according to the active **Theme**.

### Notch
A visual narrowing of the box plot around the median indicating the 95% confidence interval for the median.
The bounds of the notch are calculated as $\text{median} \pm 1.58 \times \frac{\text{IQR}}{\sqrt{n}}$, narrowing down to 60% of the full box width at the median position. If the notch bounds extend beyond Q1 or Q3 (e.g., due to small sample size or high variability), the notch lines are allowed to extend beyond the box, creating a flipped/flared shape.
_Avoid_: Waist, confidence interval cutoff

### Median Label
A text label displayed to the right of the median line (at the notch waist) showing the median value formatted as $\mu_{1/2} = \text{value}$ (`μ½ = <value>`), where $\mu_{1/2}$ denotes the median (with subscript ½) in small light gray text.

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

### SESOI (Smallest Effect Size of Interest)
The minimal magnitude of change (expressed as a percentage or fraction of baseline) that is engineering-relevant or meaningful to detect.

### Bootstrap Sample Size
The estimated minimum number of trials or rounds required per variant to achieve a target statistical power and significance level ($\alpha$), determined via noise resampling and simulated 1-sample t-tests.

### Calibrated Bootstrap
An empirical critical value calculation (studentized bootstrap-t resampling) that holds the false-positive rate at $\alpha$ under skewed noise distributions. It is enabled by default for sample size estimation, falling back to the parametric Student's t critical value when the pilot observation count is small ($n < 20$).

### Win Rate
The proportion of paired rounds in which the variant outperforms the baseline (e.g., $\text{change} < 0$, with ties credited as $0.5$), measuring the non-parametric effect size of the comparison.

### Statistical Power
The probability that an experiment will detect a true effect of at least the **SESOI** when one exists, given the observed noise distribution, sample size, and significance level ($\alpha$).

### Significance Test
A hypothesis test evaluating whether there is statistically significant evidence of improvement of at least the **SESOI** ($\bar{d} \le -\text{SESOI} \times \text{baseMean}$ and one-tailed $p < \alpha$) using the **Calibrated Bootstrap**.

### Theme
A visual presentation scheme for plots. Plot themes adjust the colors of structural elements (axes, grid lines, zero baseline, box plots, and typography) to ensure optimal legibility and contrast against expected background canvas colors while maintaining consistent data series palette colors.

### Plot Layout
The spatial geometry and dimension specifications for rendering a plot. It defines the overall canvas dimensions (width and height), surrounding margins, and the resulting inner plotting area (`plotWidth` and `plotHeight`) where data and axes are drawn.
_Avoid_: Canvas size, plot dimensions

### Dark Theme
The default **Theme**, optimized for dark background canvases. Structural elements, labels, and box plots are drawn with white or light gray strokes and fills, leaving the SVG background transparent.

### Light Theme
A **Theme** optimized for white or light background canvases. Structural elements, labels, and box plots are drawn with black or dark gray strokes and fills, leaving the SVG background transparent.

### Iteration
A technical replicate in a pure-Dart benchmark: the repeated verbatim execution of a measured unit of work (such as an algorithmic operation or loop pass), recorded with its execution duration in microseconds (`durationUs`) and timestamp. Unlike UI benchmarks that produce **Frames**, pure-Dart benchmarks record a stream of Iterations.

### Harness APK
A minimal, headless Android/Flutter application package wrapping a pure-Dart benchmark. It provides the AOT Dart runtime on the Android DUT and is launched directly via `am start` without requiring a companion test APK.

### iterations.jsonl
The raw measurement file written by a **Harness APK** on the device during a **Trial**, containing one JSON object per **Iteration** with its duration and timestamp. Like `frames.jsonl`, it records unaggregated raw data; metric aggregation into `.dat` files is performed on the host.

### Local Runner
A command-line benchmark harness (`bin/local_runner.dart`) that executes benchmark variants directly on the local macOS host machine in randomized rounds, capturing stdout runtime metrics (`(RunTime): ??? us`) and writing session artifacts compatible with `bin/extract_dat.dart`.

### Host Execution Environment
The local machine environment (macOS) on which benchmark trials are spawned as subprocesses, with non-privileged telemetry (thermal pressure level, hardware model, macOS version, CPU brand, load average) recorded before and after each trial.
