import 'package:http/http.dart' as http;
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../utils/reload_export.dart';

@client
class DiscoverButton extends StatelessComponent {
  const DiscoverButton({super.key});

  @override
  Component build(BuildContext context) {
    return button(
      onClick: () async {
        await http.post(Uri.parse('/api/sessions/discover'));
        reloadLocation();
      },
      [.text('Discover New Sessions')],
    );
  }
}
