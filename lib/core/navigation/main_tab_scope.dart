import 'package:flutter/widgets.dart';

class MainTabScope extends InheritedWidget {
  final int currentIndex;
  final ValueChanged<int> setIndex;

  const MainTabScope({
    super.key,
    required this.currentIndex,
    required this.setIndex,
    required super.child,
  });

  static MainTabScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainTabScope>();
  }

  @override
  bool updateShouldNotify(MainTabScope oldWidget) {
    return oldWidget.currentIndex != currentIndex;
  }
}
