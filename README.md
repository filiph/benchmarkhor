<img src="https://github.com/filiph/benchmarkhor/raw/main/doc/images/markhor.jpg" alt="An illustration of a markhor, a mountain goat" align="right">

![Build status](https://github.com/filiph/benchmarkhor/actions/workflows/test.yml/badge.svg)

**Benchmarkhor** is a benchmark comparison tool. 
It provides ways to compare benchmark data as a whole, as opposed to just
as a handful of summary numbers.

(Markhor is a species of 
[mountain goats](https://www.google.com/search?q=markhor).)

### Features

* **Visualizes performance changes with a diff histogram**.  
  This allows for a much more insightful comparison.
* **Saves each run in a tiny file without
  losing detail.**  
  Each `.benchmark` file takes only a few kilobytes 
  (about the size of this `README.md` text file).
  Compared to the 
  [timeline JSON files](https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU/preview),
  which can easily take hundreds of megabytes,
  this format takes about 0.003% on disk.
* **Summarizes performance improvements with a carefully selected
  set of metrics.**  
  This makes it easier to see if a particular performance
  optimization makes a significant difference, 
  and it makes it harder to be fooled by false indications of progress.

## Install

Currently, the tool requires that you have the 
[Dart SDK](https://dart.dev/get-dart)
installed and in your path.

Then, install this tool by running

```text
$ dart pub global activate benchmarkhor
```

## Use

**Note:** Benchmarkhor currently only supports comparison of Flutter
benchmarks. It may support more use cases in the future, but here we'll
assume you want to compare two versions of the same Flutter app.

### Creating the baseline ("before") benchmark

1. Exercise your app via an automated benchmarking approach, using 
  [`flutter_driver`](https://api.flutter.dev/flutter/flutter_driver/flutter_driver-library.html).
   (See 
   [instructions](https://medium.com/flutter/performance-testing-of-flutter-apps-df7669bb7df7) on how to make the benchmarks as stable as possible.)
   [Save the timeline](https://api.flutter.dev/flutter/flutter_driver/FlutterDriver/stopTracingAndDownloadTimeline.html)
   to a file, such as `baseline.json`.

2. Run the `benchextract` tool on this file:

       $ benchextract baseline.json
   
   This generates a `baseline.benchmark` file in the same directory. It is much smaller yet contains all the salient data.
   
3. (Optional.) You can delete `baseline.json` now.

4. Keep `baseline.benchmark` for later, possibly even adding it to your source version control.

### Creating the candidate ("after") benchmark

After you've made your performance optimization work, create a new `.benchmark` file by following the instructions above. (Excercise your app using `flutter_driver`, save the timeline to a `.json` file, run `benchextract` on that file, remove the `.json` file.)

### Comparing two benchmarks

Simply run the `benchcompare` tool on any two benchmark files:

```text
$ benchcompare baseline.benchmark new.benchmark
```

This will give a result like this:

```text
<-- (improvement)                  UI thread                (deterioration) -->
                                       █                                       
                                       █                                       
                                       █                                       
                                       █                                       
                                       █                                       
                                       █                                       
                                       █                                       
                                       █                                       
                                       █                                       
                                       █                                       
                                       █                                       
                                       █                                       
                                       █                                       
                                       █                                       
                                       █                                       
                                       █                                       
                                       █                                       
                                       █                                       
                                       █                                       
.          .                         ..█..                                     
───────────────────────────────────────────────────────────────────────────────
-115.4ms                               ^                                115.4ms


<-- (improvement)                Raster thread              (deterioration) -->
                                       █                                       
                                       █                                       
                                       █                                       
                                       █                                       
                                       █                                       
                                       █                                       
                                       █                                       
                                    ▄▄ █                                       
                                    ██ █                                       
                                    ██ █                                       
                                    ██ █                                       
                                    ██ █                                       
                                    ██ █                                       
                                   ▄██ █                                       
                                 █████ █                                       
                                 █████ █                                       
     ▄                          ▄███████                                       
     █                          ████████                                       
     █                     ▄  ▄█████████                                       
▄▄▄▄▄█▄██▄▄▄..▄.▄▄▄▄████████████████████  .                       .            
───────────────────────────────────────────────────────────────────────────────
-10.2ms                                ^                                 10.2ms

UI thread:
* 8.1% (1394ms) worsening of total execution time
* 0 ppt decrease in potential jank (185 -> 175)
* 0.2% of individual measurements improved by 1ms+
* 0.2% of individual measurements worsened by 1ms+

Raster thread:
* 23.4% (-7886ms) improvement of total execution time
* 17 ppt decrease in potential jank (1111 -> 206)
* 43.9% of individual measurements improved by 1ms+
* 0.0% of individual measurements worsened by 1ms+
```

In the above example, we can see a massive improvement on the raster thread. The histogram tells us this improvement is consistent: most of the graph is to the left of center, which means that most of the measurements in `new.benchmark` were shorter (faster) than in `baseline.benchmark`.

We can also see some deterioration on the UI thread, but only in total execution time (which roughly translates to battery usage). We can now decide whether this deterioration on the UI thread is a fair price for the improvement on the raster thread. (For what it's worth: _it definitely is, in this case._)

## Contribute

Please file an issue first, or feel free to fork this project if you can't wait. This is a personal project, so there are no guarantees.
