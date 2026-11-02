import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/myx/myx_dashboard.dart';
import 'package:lantern/features/myx/myx_locations.dart';
import 'package:lantern/features/myx/myx_settings.dart';
import 'package:lantern/features/myx/myx_splash.dart';

/// Selected bottom-nav tab: 0 Home, 1 Locations, 2 Settings.
final myxTabProvider = NotifierProvider<MyxTab, int>(MyxTab.new);

class MyxTab extends Notifier<int> {
  @override
  int build() => 0;
  void go(int index) => state = index;
}

/// myx-VPN app shell: dark navy backdrop, three tabs, splash on cold start.
class MyxShell extends HookConsumerWidget {
  const MyxShell({super.key});

  static bool _splashShown = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(myxTabProvider);
    final showSplash = useState(!MyxShell._splashShown);
    useEffect(() {
      MyxShell._splashShown = true;
      return null;
    }, const []);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.myxDash3,
      ),
      child: Stack(
        children: [
          Scaffold(
            key: const Key('home.screen'),
            backgroundColor: AppColors.myxDash3,
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.myxDash1,
                    AppColors.myxDash2,
                    AppColors.myxDash3,
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
              // The shell is always dark navy, whatever the app appearance.
              child: Theme(
                data: AppTheme.darkTheme().copyWith(
                  scaffoldBackgroundColor: Colors.transparent,
                ),
                child: IndexedStack(
                  index: tab,
                  children: const [
                    MyxDashboard(),
                    MyxLocations(),
                    MyxSettings(),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: _MyxBottomBar(
              index: tab,
              onSelected: ref.read(myxTabProvider.notifier).go,
            ),
          ),
          if (showSplash.value)
            MyxSplash(onDone: () => showSplash.value = false),
        ],
      ),
    );
  }
}

class _MyxBottomBar extends StatelessWidget {
  const _MyxBottomBar({required this.index, required this.onSelected});
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_rounded, 'myx_home'.i18n),
      (Icons.location_on_outlined, 'myx_locations'.i18n),
      (Icons.settings_outlined, 'myx_settings'.i18n),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A1640),
        border: Border(top: BorderSide(color: Color(0x1FFFFFFF))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: InkWell(
                    key: Key('myx.tab.$i'),
                    onTap: () => onSelected(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: i == index
                                ? AppColors.myxRed.withValues(alpha: 0.14)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Icon(
                            items[i].$1,
                            size: 24,
                            color: i == index
                                ? AppColors.myxRed
                                : Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          items[i].$2,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight:
                                i == index ? FontWeight.w700 : FontWeight.w500,
                            color: i == index
                                ? AppColors.myxRed
                                : Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
