import 'package:http/http.dart' as http;
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../utils/reload_export.dart';

@client
class StartNextButton extends StatelessComponent {
  final bool disabled;

  const StartNextButton({this.disabled = false, super.key});

  @override
  Component build(BuildContext context) {
    return button(
      disabled: disabled,
      onClick: disabled
          ? null
          : () async {
              await http.post(Uri.parse('/api/queue/next'));
              reloadLocation();
            },
      [.text('Start Next Queued Session')],
    );
  }
}
