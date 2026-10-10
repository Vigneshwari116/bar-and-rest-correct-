import 'dart:async';
import 'package:flutter/material.dart';

class SessionTimeoutListener extends StatefulWidget {
  final Widget child;
  final Duration timeoutDuration;
  final VoidCallback onTimeout;

  const SessionTimeoutListener({super.key, required this.child, required this.onTimeout, this.timeoutDuration = const Duration(minutes: 60)});

  @override
  State<SessionTimeoutListener> createState() => _SessionTimeoutListenerState();
}

class _SessionTimeoutListenerState extends State<SessionTimeoutListener> {
  Timer? _timer;

  @override
  void initState() { super.initState(); _resetInactivityTimer(); }
  void _resetInactivityTimer() {
    _timer?.cancel();
    _timer = Timer(widget.timeoutDuration, widget.onTimeout);
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetInactivityTimer(),
      onPointerMove: (_) => _resetInactivityTimer(),
      onPointerUp: (_) => _resetInactivityTimer(),
      child: widget.child,
    );
  }
}