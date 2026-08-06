import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_models.dart';

class LearningAssistantService {
  const LearningAssistantService();

  Future<String?> solveProblem({
    required String lesson,
    required String question,
  }) async {
    final apiKey = const String.fromEnvironment('GEMINI_API_KEY');
    if (apiKey.isEmpty) return null;
    try {
      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/'
          'gemini-1.5-flash:generateContent?key=$apiKey',
        ),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text':
                      'أنت مساعد تعليمي عربي للأطفال. أجب باختصار وبطريقة مبسطة. '
                      'محتوى الدرس:\n$lesson\n\nسؤال الطالب:\n$question',
                }
              ]
            }
          ]
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;
      final candidates = data['candidates'];
      if (candidates is! List || candidates.isEmpty) return null;
      final content = candidates.first['content'];
      final parts = content is Map ? content['parts'] : null;
      if (parts is! List || parts.isEmpty) return null;
      final text = parts.first is Map ? parts.first['text'] : null;
      final answer = text?.toString().trim();
      return answer == null || answer.isEmpty ? null : answer;
    } catch (_) {
      return null;
    }
  }

  Future<String?> solveMathProblem({required String problem}) async {
    final question = problem.trim();
    if (question.isEmpty) return null;
    final apiKey = const String.fromEnvironment('GEMINI_API_KEY');
    if (apiKey.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/'
            'gemini-1.5-flash:generateContent?key=$apiKey',
          ),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {
                    'text':
                        'حل هذه المسألة الرياضية بالعربية بخطوات واضحة ومبسطة '
                        'للطلاب، ثم اذكر الإجابة النهائية:\n$question',
                  }
                ]
              }
            ]
          }),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          final candidates = data is Map ? data['candidates'] : null;
          final content = candidates is List && candidates.isNotEmpty
              ? candidates.first['content']
              : null;
          final parts = content is Map ? content['parts'] : null;
          final text = parts is List && parts.isNotEmpty && parts.first is Map
              ? parts.first['text']?.toString().trim()
              : null;
          if (text != null && text.isNotEmpty) return text;
        }
      } catch (_) {
        // Use the offline solver when the network or AI response is unavailable.
      }
    }
    return _solveMathLocally(question);
  }

  Future<List<QuizQuestion>> generateQuestions({
    required String lesson,
    required int count,
    required String grade,
    required String subject,
    required String unit,
  }) async {
    final apiKey = const String.fromEnvironment('GEMINI_API_KEY');
    if (apiKey.isEmpty) {
      return localQuestions(
        lesson: lesson,
        count: count,
        grade: grade,
        subject: subject,
        unit: unit,
      );
    }
    try {
      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/'
          'gemini-1.5-flash:generateContent?key=$apiKey',
        ),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text':
                      'أنشئ $count أسئلة اختيار من متعدد بالعربية من محتوى الدرس. '
                      'أعد JSON فقط كمصفوفة، وكل عنصر يحتوي question وoptions (4 نصوص) '
                      'وcorrectAnswer. الدرس:\n$lesson',
                }
              ]
            }
          ]
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List?;
        final firstCandidate =
            candidates?.isNotEmpty == true && candidates!.first is Map
                ? candidates.first as Map
                : null;
        final content = firstCandidate?['content'];
        final parts = content is Map ? content['parts'] : null;
        final firstPart = parts is List && parts.isNotEmpty && parts.first is Map
            ? parts.first as Map
            : null;
        final text = firstPart?['text']?.toString();
        if (text != null) {
          final cleaned = text
              .replaceFirst(RegExp(r'^```json\s*'), '')
              .replaceFirst(RegExp(r'```$'), '')
              .trim();
          final items = jsonDecode(cleaned) as List;
          final generated = items.whereType<Map>().map((item) {
            final options = (item['options'] as List? ?? const [])
                .map((option) => option.toString())
                .toList();
            return QuizQuestion(
              id: 'ai-${DateTime.now().microsecondsSinceEpoch}-${items.indexOf(item)}',
              question: item['question']?.toString() ?? '',
              options: options,
              correctAnswer: item['correctAnswer']?.toString() ?? '',
              grade: grade,
              subject: subject,
              unit: unit,
              source: 'gemini',
            );
          }).where((item) => item.question.isNotEmpty && item.options.length >= 2)
              .toList();
          if (generated.isNotEmpty) return generated.take(count).toList();
        }
      }
    } catch (_) {
      // Offline and malformed responses use the deterministic local generator.
    }
    return localQuestions(
      lesson: lesson,
      count: count,
      grade: grade,
      subject: subject,
      unit: unit,
    );
  }

  List<QuizQuestion> localQuestions({
    required String lesson,
    required int count,
    required String grade,
    required String subject,
    required String unit,
  }) {
    final sentences = lesson
        .split(RegExp(r'[.!؟\n]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (sentences.isEmpty) return const [];
    final amount = count.clamp(1, sentences.length).toInt();
    return List.generate(amount, (index) {
      final statement = sentences[index];
      final correct = statement.length > 90
          ? '${statement.substring(0, 90)}...'
          : statement;
      final options = [
        correct,
        'فكرة جانبية من الدرس',
        'إجابة غير مرتبطة',
        'لا توجد معلومات كافية',
      ];
      return QuizQuestion(
        id: 'local-$index-${statement.hashCode}',
        question: 'اختر الفكرة الصحيحة من الدرس: «$statement»',
        options: options,
        correctAnswer: correct,
        grade: grade,
        subject: subject,
        unit: unit,
        source: 'local',
      );
    });
  }

  String? _solveMathLocally(String input) {
    final normalized = _normalizeMathInput(input);
    final percentage = RegExp(
      r'(\d+(?:\.\d+)?)\s*%\s*(?:من|of)\s*(\d+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (percentage != null) {
      final percent = double.parse(percentage.group(1)!);
      final amount = double.parse(percentage.group(2)!);
      final result = percent * amount / 100;
      return 'نحسب النسبة:\n$percent% من $amount = '
          '${_formatNumber(result)}\n\nالإجابة النهائية: ${_formatNumber(result)}';
    }

    if (normalized.contains('اجمع')) {
      final numbers = RegExp(r'\d+(?:\.\d+)?')
          .allMatches(normalized)
          .map((match) => double.parse(match.group(0)!))
          .toList();
      if (numbers.length >= 2) {
        final result = numbers.fold<double>(0, (sum, value) => sum + value);
        return 'نجمع الأعداد: ${numbers.map(_formatNumber).join(' + ')}\n\n'
            'الإجابة النهائية: ${_formatNumber(result)}';
      }
    }

    final expression = normalized
        .replaceAll('؟', '')
        .replaceAll('?', '')
        .replaceAll('=', '')
        .trim();
    if (expression.isEmpty) return null;
    try {
      final result = _ExpressionParser(expression).parse();
      return 'نحسب العملية خطوة بخطوة:\n$expression = ${_formatNumber(result)}\n\n'
          'الإجابة النهائية: ${_formatNumber(result)}';
    } catch (_) {
      return null;
    }
  }

  String _normalizeMathInput(String value) {
    return value
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .replaceAll('٪', '%')
        .replaceAll('×', '*')
        .replaceAll('✕', '*')
        .replaceAll('÷', '/')
        .replaceAll('^', '^')
        .replaceAll('²', '^2')
        .replaceAll('³', '^3')
        .replaceAll('⁴', '^4')
        .replaceAll('⁵', '^5');
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }
}

class _ExpressionParser {
  _ExpressionParser(this.source);

  final String source;
  int index = 0;

  double parse() {
    final value = _parseExpression();
    _skipSpaces();
    if (index != source.length) {
      throw const FormatException('Unexpected input');
    }
    return value;
  }

  double _parseExpression() {
    var value = _parseTerm();
    while (true) {
      _skipSpaces();
      if (_consume('+')) {
        value += _parseTerm();
      } else if (_consume('-')) {
        value -= _parseTerm();
      } else {
        return value;
      }
    }
  }

  double _parseTerm() {
    var value = _parsePower();
    while (true) {
      _skipSpaces();
      if (_consume('*')) {
        value *= _parsePower();
      } else if (_consume('/')) {
        final divisor = _parsePower();
        if (divisor == 0) throw const FormatException('Division by zero');
        value /= divisor;
      } else {
        return value;
      }
    }
  }

  double _parsePower() {
    final base = _parseUnary();
    _skipSpaces();
    if (_consume('^')) {
      return _power(base, _parsePower());
    }
    return base;
  }

  double _parseUnary() {
    _skipSpaces();
    if (_consume('+')) return _parseUnary();
    if (_consume('-')) return -_parseUnary();
    return _parsePrimary();
  }

  double _parsePrimary() {
    _skipSpaces();
    if (_consume('(')) {
      final value = _parseExpression();
      if (!_consume(')')) throw const FormatException('Missing parenthesis');
      return value;
    }
    final start = index;
    while (index < source.length &&
        RegExp(r'[0-9.]').hasMatch(source[index])) {
      index++;
    }
    if (start == index) throw const FormatException('Expected number');
    return double.parse(source.substring(start, index));
  }

  bool _consume(String character) {
    if (index < source.length && source[index] == character) {
      index++;
      return true;
    }
    return false;
  }

  void _skipSpaces() {
    while (index < source.length && source[index].trim().isEmpty) {
      index++;
    }
  }

  double _power(double base, double exponent) {
    if (exponent == exponent.roundToDouble() && exponent.abs() <= 100) {
      var result = 1.0;
      final count = exponent.abs().toInt();
      for (var i = 0; i < count; i++) {
        result *= base;
      }
      return exponent < 0 ? 1 / result : result;
    }
    throw const FormatException('Unsupported exponent');
  }
}