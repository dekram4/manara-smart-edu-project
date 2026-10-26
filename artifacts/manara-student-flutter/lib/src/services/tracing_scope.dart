/// متى تظهر لعبةُ «تتبّع واكتب»: صفُّ «روضة منارة المعرفة» **و**إحدى موادّه
/// الأربع — «الحروف العربية»، «الحروف الإنجليزية»، «الأرقام العربية»،
/// «الأرقام الإنجليزية» — معاً. وأيُّ صفٍّ آخر أو مادّةٍ أخرى: لا تتبّع.
///
/// القاعدةُ نفسُها في الخادم (`tracingSetFor` في `lib/tracing.ts`)، وهو من
/// يرسل اللعبة. وهي هنا كذلك: خادمٌ لم يُحدَّث بعدُ قد يرسلها لصفٍّ آخر، فلا
/// تظهر فيه.
library;

/// الصفُّ الوحيد الذي تظهر فيه اللعبة.
const kindergartenGrade = 'روضة منارة المعرفة';

// بالرموز: نطاقُ التشكيل مكتوباً بحروفه يشمل الأرقامَ الهندية فيمحوها.
final _tashkeel = RegExp('[ً-ٰٟـ]');

String _key(String value) => value
    .replaceAll(_tashkeel, '')
    .toLowerCase()
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool isKindergartenGrade(String? grade) => _key(grade ?? '') == _key(kindergartenGrade);

/// مادّةُ حروفٍ أو أرقامٍ عربيةٍ أو إنجليزية — بأيّ همزةٍ أو تاءٍ كُتبت.
bool isTracingSubject(String? subject) {
  final key = _key(subject ?? '');
  final language = RegExp('انجليز|انكليز|english|عربي|arabic').hasMatch(key);
  final set = RegExp('حروف|الحرف|letters|alphabet|ارقام|اعداد|numbers|digits').hasMatch(key);
  return language && set;
}

bool tracingAllowedFor({required String? grade, required String? subject}) =>
    isKindergartenGrade(grade) && isTracingSubject(subject);
