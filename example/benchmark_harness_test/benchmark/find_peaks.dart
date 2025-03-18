/// Takes a sequence of numbers (such as in a histogram) and finds the peaks.
///
/// Returns the peaks, sorted from the most prominent to the least.
///
/// Adapted from
/// https://www.sthu.org/blog/13-perstopology-peakdetection/index.html
List<Peak> getPersistentHomology(List<double> seq) {
  List<_Peak> peaks = [];
  // Maps indices to peaks
  List<int?> idxToPeak = List.filled(seq.length, null);
  // Sequence indices sorted by values
  List<int> indices = List.generate(seq.length, (i) => i);
  indices.sort((a, b) => seq[b].compareTo(seq[a])); // Sort descending by value

  // Process each sample in descending order
  for (int idx in indices) {
    bool lftDone = (idx > 0 && idxToPeak[idx - 1] != null);
    bool rgtDone = (idx < seq.length - 1 && idxToPeak[idx + 1] != null);
    int? il = lftDone ? idxToPeak[idx - 1] : null;
    int? ir = rgtDone ? idxToPeak[idx + 1] : null;

    // New peak born
    if (!lftDone && !rgtDone) {
      peaks.add(_Peak(idx));
      idxToPeak[idx] = peaks.length - 1;
    }

    // Directly merge to next peak left
    if (lftDone && !rgtDone) {
      peaks[il!].right += 1;
      idxToPeak[idx] = il;
    }

    // Directly merge to next peak right
    if (!lftDone && rgtDone) {
      peaks[ir!].left -= 1;
      idxToPeak[idx] = ir;
    }

    // Merge left and right peaks
    if (lftDone && rgtDone) {
      if (seq[peaks[il!].born] > seq[peaks[ir!].born]) {
        peaks[ir].died = idx;
        peaks[il].right = peaks[ir].right;
        idxToPeak[peaks[il].right] = il;
        idxToPeak[idx] = il;
      } else {
        peaks[il].died = idx;
        peaks[ir].left = peaks[il].left;
        idxToPeak[peaks[ir].left] = ir;
        idxToPeak[idx] = ir;
      }
    }
  }

  final result = peaks.map((p) => p.bake(seq)).toList(growable: false);

  // This is optional convenience
  result.sort((a, b) => b.persistence.compareTo(a.persistence));
  return result;
}

class Peak {
  final int index;
  final int indexLeft;
  final int indexRight;
  final double value;
  final double persistence;

  const Peak._(this.index, this.indexLeft, this.indexRight, this.value,
      this.persistence);

  @override
  String toString() => 'Peak(<$indexLeft-^$index^-$indexRight>, '
      '${persistence.toStringAsFixed(3)})';
}

/// Working, mutable peak.
class _Peak {
  final int born;
  int left;
  int right;
  int? died;

  _Peak(int startIdx)
      : born = startIdx,
        left = startIdx,
        right = startIdx,
        died = null;

  double getPersistence(List<double> seq) {
    return died == null ? double.infinity : seq[born] - seq[died!];
  }

  Peak bake(List<double> seq) =>
      Peak._(born, left, right, seq[born], getPersistence(seq));
}
