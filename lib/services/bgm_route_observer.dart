import 'package:flutter/material.dart';

import 'bgm_service.dart';

class BgmRouteObserver extends NavigatorObserver {
  // Routes that should play the "relax" track (parent + teacher UI)
  static const Set<String> _relaxRoutes = {
    // Parent portal
    '/parent-welcome',
    '/parent-signup',
    '/parent-login',
    '/parent-dashboard',
    '/add-child',
    '/child-progress',
    '/generate-link-code',
    '/parent-settings',
    // Teacher portal
    '/teacher-welcome',
    '/teacher-signup',
    '/teacher-login',
    '/teacher-dashboard',
    '/create-class',
    '/class-overview',
    '/teacher-student-progress',
    '/class-analytics',
    '/class-leaderboard',
    '/teacher-settings',
  };

  static const Set<String> _lessonRoutes = {
    '/lesson-play',
    '/passage',
    '/lesson-intro',
  };

  static const Set<String> _gameRoutes = {
    '/memory-match',
    '/bubble-pop',
    '/drag-drop',
    '/word-scramble',
    '/sentence-builder',
    '/floor-is-lava',
    '/word-hunt',
    '/category-sort',
    '/quiz-play',
  };

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _handleRoute(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _handleRoute(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _handleRoute(newRoute);
    }
  }

  void _handleRoute(Route<dynamic> route) {
    final routeName = route.settings.name;
    if (routeName == null) return;

    if (routeName == '/' || routeName == '/role-selection') {
      BgmService.stop();
    } else if (_relaxRoutes.contains(routeName)) {
      BgmService.playTrack(BgmTrack.relax);
    } else if (_lessonRoutes.contains(routeName)) {
      BgmService.playTrack(BgmTrack.lesson);
    } else if (_gameRoutes.contains(routeName)) {
      BgmService.playTrack(BgmTrack.game);
    } else {
      BgmService.playTrack(BgmTrack.main);
    }
  }
}