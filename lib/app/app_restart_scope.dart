import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppRestartScope extends StatefulWidget {
  const AppRestartScope({super.key, required this.child});

  final Widget child;

  static _AppRestartScopeState? _instance;

  static Future<void> restartApp() async {
    _instance?._restart();
  }

  @override
  State<AppRestartScope> createState() => _AppRestartScopeState();
}

class _AppRestartScopeState extends State<AppRestartScope> {
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    AppRestartScope._instance = this;
  }

  @override
  void dispose() {
    if (identical(AppRestartScope._instance, this)) {
      AppRestartScope._instance = null;
    }
    super.dispose();
  }

  void _restart() {
    if (!mounted) {
      return;
    }
    setState(() {
      _epoch += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(key: ValueKey<int>(_epoch), child: widget.child);
  }
}
