import 'package:flutter/widgets.dart';

/// Watches route changes so a screen can tell when it has been covered by
/// another and when it has been uncovered again.
///
/// The hub uses it to step the background music aside while a lesson, a video
/// or a game is open. Doing that from each card's own navigation call would
/// mean remembering to pause and resume at every push site — and the hub has
/// nine of them, several routed through helper methods. A route observer
/// catches all of them, including the ones added later.
final RouteObserver<PageRoute<dynamic>> studentRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
