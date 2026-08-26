import 'package:flutter/material.dart';

/// D-ID supplies its Agent Embed as a browser module. Native support stays
/// explicit rather than silently opening the creator dashboard in a WebView.
class DIdAgentEmbed extends StatelessWidget {
  const DIdAgentEmbed({
    required this.apiBaseUrl,
    super.key,
  });

  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFF101D33),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'المعلم الافتراضي متاح حاليًا في نسخة الويب من منارة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );
}