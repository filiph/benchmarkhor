import 'package:http/http.dart' as http;
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../utils/reload_export.dart';

@client
class RequeueButton extends StatelessComponent {
  final String sessionId;

  const RequeueButton({required this.sessionId, super.key});

  @override
  Component build(BuildContext context) {
    return button(
      onClick: () async {
        await http.post(Uri.parse('/api/sessions/$sessionId/requeue'));
        reloadLocation();
      },
      [.text('Re-queue')],
    );
  }
}
