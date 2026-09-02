import 'dart:io';

/// Computes labels from a list of input file paths.
///
/// When [removeCommonPrefix] is true (default) and there are at least two paths,
/// any common prefix of `_`-delimited segments shared by all filenames is
/// stripped, unless doing so would leave any label empty.
List<String> computeLabels(
  List<String> paths, {
  bool removeCommonPrefix = true,
}) {
  final rawNames = paths.map((path) {
    return path
        .split(Platform.pathSeparator)
        .last
        .replaceAll(RegExp(r'\.dat$', caseSensitive: false), '');
  }).toList();

  if (!removeCommonPrefix || rawNames.length <= 1) {
    return rawNames;
  }

  final segmentsList = rawNames.map((name) => name.split('_')).toList();

  int commonPrefixLength = 0;
  final first = segmentsList.first;

  while (true) {
    if (commonPrefixLength >= first.length) break;
    final segment = first[commonPrefixLength];
    var allMatch = true;
    for (var i = 1; i < segmentsList.length; i++) {
      if (commonPrefixLength >= segmentsList[i].length ||
          segmentsList[i][commonPrefixLength] != segment) {
        allMatch = false;
        break;
      }
    }
    if (!allMatch) break;
    commonPrefixLength++;
  }

  if (commonPrefixLength == 0) {
    return rawNames;
  }

  final wouldEmptyAny = segmentsList.any(
    (segments) => segments.length <= commonPrefixLength,
  );
  if (wouldEmptyAny) {
    return rawNames;
  }

  return segmentsList
      .map((segments) => segments.sublist(commonPrefixLength).join('_'))
      .toList();
}
