import 'package:flutter/material.dart';
import 'bgm_service.dart';

class BgmRouteObserver extends NavigatorObserver {
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

    // 1. SILENCE BGM on these screens
    if (routeName == '/role-selection' || routeName == '/') {
      BgmService.stop();
    } 
    // 2. Relax music for parent/teacher
    else if (['/parent-dashboard', '/teacher-dashboard', '/parent-welcome', '/teacher-welcome'].contains(routeName)) {
      BgmService.playTrack(BgmTrack.relax);
    } 
    // 3. Lesson music
    else if (['/lesson-play', '/passage', '/lesson-intro'].contains(routeName)) {
      BgmService.playTrack(BgmTrack.lesson);
    } 
    // 4. Game music
    else if ([
      '/memory-match', '/bubble-pop', '/drag-drop', '/word-scramble', 
      '/sentence-builder', '/floor-is-lava', '/word-hunt', '/category-sort', '/quiz-play'
    ].contains(routeName)) {
      BgmService.playTrack(BgmTrack.game);
    } 
    // 5. Default to Main Menu music for everything else
    else {
      BgmService.playTrack(BgmTrack.main);
    }
  }
}