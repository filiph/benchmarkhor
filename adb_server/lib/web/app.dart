import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import '../config.dart';
import '../runner.dart';
import '../session_store.dart';
import 'pages/dashboard_page.dart';
import 'pages/session_detail_page.dart';

class AppData {
  final Config config;
  final SessionStore sessionStore;
  final Runner runner;

  const AppData({
    required this.config,
    required this.sessionStore,
    required this.runner,
  });
}

class AppDataProvider extends InheritedComponent {
  final AppData data;

  const AppDataProvider({required this.data, required super.child, super.key});

  static AppData? of(BuildContext context) {
    return context
        .dependOnInheritedComponentOfExactType<AppDataProvider>()
        ?.data;
  }

  @override
  bool updateShouldNotify(AppDataProvider oldWidget) => oldWidget.data != data;
}

class App extends StatelessComponent {
  final AppData? appData;

  const App({this.appData, super.key});

  @override
  Component build(BuildContext context) {
    final component = div(classes: 'main', [
      Router(
        routes: [
          Route(
            path: '/',
            title: 'adb_server',
            builder: (context, state) => const DashboardPage(),
          ),
          Route(
            path: '/sessions/:id',
            title: 'Session Detail',
            builder: (context, state) =>
                SessionDetailPage(id: state.params['id'] ?? ''),
          ),
        ],
      ),
    ]);

    if (appData != null) {
      return AppDataProvider(data: appData!, child: component);
    }
    return component;
  }
}
