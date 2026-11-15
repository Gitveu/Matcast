import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/legacy.dart';

import 'models/receiver_state.dart';
import 'state/receiver_provider.dart';
import 'state/settings_provider.dart';
import 'ui/theme/app_theme.dart';
import 'ui/views/devices_view.dart';
import 'ui/views/display_view.dart';
import 'ui/views/protocols_view.dart';
import 'ui/views/settings_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(960, 640),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    title: 'Matcast',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setTitle('Matcast');
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProxyProvider<SettingsProvider, ReceiverProvider>(
          create: (ctx) => ReceiverProvider(
            settings: ctx.read<SettingsProvider>(),
          ),
          update: (ctx, settings, previous) =>
              previous ?? ReceiverProvider(settings: settings),
        ),
      ],
      child: const MatcastApp(),
    ),
  );
}

class MatcastApp extends StatelessWidget {
  const MatcastApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
      title: 'Matcast',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: settings.themeMode,
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  bool _wasStreaming = false;
  final FocusNode _focusNode = FocusNode();

  final List<Widget> _views = const [
    DisplayView(),
    DevicesView(),
    ProtocolsView(),
    SettingsView(),
  ];

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event, ReceiverProvider provider) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.f11) {
        provider.toggleFullScreen();
      } else if (event.logicalKey == LogicalKeyboardKey.escape &&
          provider.state.isFullScreen) {
        provider.setFullScreen(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReceiverProvider>();
    final isStreaming = provider.state.status == ReceiverStatus.streaming;
    final isFullScreen = provider.state.isFullScreen;

    if (isStreaming && !_wasStreaming) {
      _wasStreaming = true;
      try {
        windowManager.show();
        windowManager.restore();
        windowManager.focus();
      } catch (_) {}
      if (_selectedIndex != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selectedIndex = 0);
        });
      }
    } else if (!isStreaming && _wasStreaming) {
      _wasStreaming = false;
    }

    final strings = provider.settings.tr(context);

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) => _handleKeyEvent(event, provider),
      child: Scaffold(
        body: Row(
          children: [
            // Hide NavigationRail in full screen
            if (!isFullScreen)
              NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (idx) {
                  setState(() => _selectedIndex = idx);
                },
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.cast_connected,
                      color: Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                  ),
                ),
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: IconButton(
                        tooltip: strings.tooltipFullscreenEnter,
                        icon: const Icon(Icons.fullscreen),
                        onPressed: () => provider.toggleFullScreen(),
                      ),
                    ),
                  ),
                ),
                destinations: [
                  NavigationRailDestination(
                    icon: const Icon(Icons.tv_outlined),
                    selectedIcon: const Icon(Icons.tv),
                    label: Text(strings.tabScreen),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.devices_outlined),
                    selectedIcon: const Icon(Icons.devices),
                    label: Text(strings.tabDevices),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.hub_outlined),
                    selectedIcon: const Icon(Icons.hub),
                    label: Text(strings.tabProtocols),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.settings_outlined),
                    selectedIcon: const Icon(Icons.settings),
                    label: Text(strings.tabSettings),
                  ),
                ],
              ),
            if (!isFullScreen) const VerticalDivider(width: 1),

            // Main Active View
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: _views,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
