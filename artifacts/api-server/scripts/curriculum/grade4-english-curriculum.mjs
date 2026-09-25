/**
 * منهج اللغة الإنجليزية للصف الرابع الابتدائي: ثمانية عشر درساً بنصوصها.
 *
 * مفصول عن السكربت الذي يكتبه عمداً، كما فُصل منهجا الرياضيات والعلوم:
 * هذا محتوًى يُراجَع بالعين العربية، وذاك منطقُ كتابةٍ يُراجَع بعين أخرى.
 *
 * والنصوص منقولة حرفاً بحرف كما وردت: لا اختصار ولا إعادة صياغة ولا
 * تصحيح إملاء — فما يقرؤه الطالب هو ما كتبه صاحب المنهج، وما يولّد منه
 * الذكاءُ الاصطناعي أسئلته.
 */

import { TERM_ONE, TERM_TWO } from "../grade4-math-curriculum.mjs";
import { stripMathMarkup } from "./strip-math-markup.mjs";

export const GRADE = "الصف الرابع الابتدائي";
export const SUBJECT = "اللغة الإنجليزية";

/** بادئة معرّفات دروس هذه المادة، كما `g4math_` و`g4sci_` لأختيها. */
export const ID_PREFIX = "g4eng_";

// أسماء الفصلين تُستعار من منهج الرياضيات لا تُكتب مرّتين: اسمٌ واحد
// يراه الطالب مهما كانت المادة، ولا يفترق بهمزةٍ هنا وهمزةٍ هناك.
export { TERM_ONE, TERM_TWO };

const UNIT_1 = "الوحدة الأولى: التعارف والترحيب والشخصية (Greetings & Personal Information)";
const UNIT_2 = "الوحدة الثانية: العائلة والعالم من حولي (Family & My World)";
const UNIT_3 = "الوحدة الثالثة: المدرسة والأدوات الدراسية (School & Classroom)";
const UNIT_4 = "الوحدة الرابعة: أجزاء الجسم والصفات (Body Parts & Adjectives)";
const UNIT_5 = "الوحدة الخامسة: الحيوانات والطبيعة (Animals & Abilities)";
const UNIT_6 = "الوحدة السادسة: الطعام والأنشطة والأصوات المركبة (Food, Routines & Digraphs)";

// التنقية قاعدةٌ واحدة لكل المناهج، فهي في وحدةٍ مشتركة. ويُعاد تصديرها
// هنا لأن من يستورد المنهج قد يحتاجها على نصٍّ يأتيه من خارجه.
export { stripMathMarkup };

const RAW = [
  // ── الفصل الدراسي الأول ─────────────────────────────────────────────
  {
    idSuffix: "1_1",
    term: TERM_ONE,
    unit: UNIT_1,
    lesson: "الدرس 1.1: التحيات والتعريف بالنفس (Greetings & Self-Introduction)",
    content: `الشرح والتحليل القواعدي العميق:
التحيات بحسب الوقت من اليوم:
من الصباح حتى 12 ظهراً: Good morning (صباح الخير).
من 12 ظهراً حتى 6 مساءً: Good afternoon (مساء الخير - بعد الظهيرة).
من 6 مساءً حتى وقت النوم: Good evening (مساء الخير - المساء).
عند المغادرة أو الذهاب للنوم: Good night (تصبح على خير) / Goodbye (مع السلامة).
صياغة الأسئلة والإجابات الشائعة:
السؤال عن الاسم: What + is + your name? -> What's your name?
الإجابة: My name is [Name] أو I'm [Name]
السؤال عن الحال: How are you?
الإجابات الممكنة:
I'm fine, thank you. (أنا بخير، شكراً لك).
I'm great! (أنا ممتاز!).
Very well, thanks. (بخير جداً، شكراً).
تركيب الضمائر مع فعل الكينونة (Verb to Be in Present):
I + am -> I'm (أنا أكون)
You / We / They + are -> You're / We're / They're (أنت/نحن/هم)
He / She / It + is -> He's / She's / It's (هو/هي/هو أو هي لغير العاقل)
الحوار النموذجي (Practice Dialogue):
Ali: Good morning! What's your name?
Omar: Good morning! My name is Omar. How are you?
Ali: I'm fine, thank you. Nice to meet you!
Omar: Nice to meet you, too!
الحصيلة اللغوية (Vocabulary):
Hello, Goodbye, Morning, Afternoon, Evening, Night, Name, Fine, Friend, Nice, Meet.
✏️ بنك التمارين والتطبيقات المكثفة:
اختر الإجابة الصحيحة (Multiple Choice):
A: How ........ you? — B: I'm fine. -> (is / are / am)
Nice to ........ you. -> (meet / name / fine)
My name ........ Ali. -> (is / are / am)
ترتيب الجمل (Reorder the words):
is / name / My / Sara. -> My name is Sara.
are / How / you / ? -> How are you?
تصحيح الخطأ القواعدي (Correct the mistake):
I is fine, thank you. -> I am (I'm) fine, thank you.`,
  },
  {
    idSuffix: "1_2",
    term: TERM_ONE,
    unit: UNIT_1,
    lesson: "الدرس 1.2: الأرقام والأعمار والقواعد (Numbers, Age & Plural Nouns)",
    content: `الشرح والتحليل القواعدي العميق:
كتابة ونطق الأرقام من 1 إلى 20:
الأعداد الفردية والمركبة البسيطة:
1: One, 2: Two, 3: Three, 4: Four, 5: Five, 6: Six, 7: Seven, 8: Eight, 9: Nine, 10: Ten.
أعداد العقود والـ "Teen":
11: Eleven, 12: Twelve, 13: Thirteen, 14: Fourteen, 15: Fifteen, 16: Sixteen, 17: Seventeen, 18: Eighteen, 19: Nineteen, 20: Twenty.
السؤال والإجابة عن العمر:
السؤال: How old are you? (كم عمرك؟)
الإجابة: I am [Number] years old. أو اختصاراً I'm [Number].
قاعدة الجمع المنتظم (Regular Plural Nouns):
عند تحويل الاسم المفرد (Singular) إلى جمع (Plural)، نضيف حرف (s) لنهاية الكلمة:
One book -> Three books
One pen -> Five pens
One apple -> Ten apples
الحصيلة اللغوية (Vocabulary):
Numbers, Count, How old, Years old, How many, One to Twenty.
✏️ بنك التمارين والتطبيقات المكثفة:
اكتب الرقم بالكلمات (Write in words):
12 -> Twelve
15 -> Fifteen
20 -> Twenty
حَوِّل المفرد إلى جمع (Convert to plural):
One cat -> Four cats
One pencil -> Six pencils
أكمل الحوار التالي (Complete the conversation):
A: How old ........ you?
B: I ........ nine years old.
الإجابة: are / am`,
  },
  {
    idSuffix: "1_3",
    term: TERM_ONE,
    unit: UNIT_1,
    lesson: "الدرس 1.3: الصوتيات والحروف (Phonics: Group 1 - A, B, C, D)",
    content: `الشرح والتحليل القواعدي العميق:
التمييز بين اسم الحرف وصوت الحرف (Letter Name vs. Letter Sound):
A a: اسم الحرف (Ey) / صوته القصيرة (/æ/) كما في: Apple (تفاحة), Ant (نملة), Alligator (تمساح).
B b: اسم الحرف (Bee) / صوته (/b/) كما في: Bear (دب), Ball (كرة), Book (كتاب), Boy (ولد).
C c: اسم الحرف (See) / صوته غالباً (/k/) كما في: Cat (قطة), Car (سيارة), Cup (كوب), Cake (كعكة).
D d: اسم الحرف (Dee) / صوته (/d/) كما في: Dog (كلب), Duck (بطة), Door (باب), Doll (دمية).
قواعد أسطر الكتابة (Handwriting Lines):
الحروف الكبيرة (Capital) تُكتب دائماً طوال الأسطر الثلاثة الأولى.
الحروف الصغيرة (Small) تختلف؛ بعضها يمر بالسطرين الأوسطين مثل (a, c) وبعضها صاعد مثل (b, d).
✏️ بنك التمارين والتطبيقات المكثفة:
اختر الحرف الأول المناسب للصوت (Circle the initial letter):
🍎 [Apple] -> (A / B / C)
🚗 [Car] -> (A / B / C)
🦆 [Duck] -> (B / D / A)
أكمل بالحرف الصغير المناسب (Write the small letter):
A -> a
B -> b
C -> c
D -> d`,
  },
  {
    idSuffix: "2_1",
    term: TERM_ONE,
    unit: UNIT_2,
    lesson: "الدرس 2.1: أفراد العائلة وأسماء الإشارة (Family Members & Demonstrative Pronouns)",
    content: `الشرح والتحليل القواعدي العميق:
شجرة العائلة والمفردات الممتدة:
Father / Dad (أب) <-> Mother / Mom (أم)
Brother (أخ) <-> Sister (أخت)
Grandfather / Grandpa (جد) <-> Grandmother / Grandma (جدة)
Uncle (عم / خال) <-> Aunt (عمة / خالة)
Baby (طفل رضيع)
أسماء الإشارة للمفرد (Demonstratives for Singular):
This is: يُستخدم للإشارة إلى المفرد القريب جداً من المتكلم.
مثال: This is my father. (هذا أبي - يقف بجانبي).
That is: يُستخدم للإشارة إلى المفرد البعيد عن المتكلم.
مثال: That is my grandfather. (ذاك جدي - يقف هناك بعيداً).
صفات الملكية (Possessive Adjectives):
My: ملكي أنا (My brother = أخي).
Your: ملكك أنت (Your sister = أختك).
الحصيلة اللغوية (Vocabulary):
Family, Father, Mother, Brother, Sister, Grandfather, Grandmother, Uncle, Aunt, This, That.
✏️ بنك التمارين والتطبيقات المكثفة:
اختر اسم الإشارة الصحيح:
........ is my mother (القريب). -> (This / That / These)
........ is my house (البعيد). -> (This / That / Those)
وصل الكلمة بعكسها أو مقابلها:
Father -> Mother
Brother -> Sister
Grandfather -> Grandmother
ضع الكلمة المناسبة في الفراغ (My / Your):
Hello! ........ name is Fahad. (اسم أنا) -> My`,
  },
  {
    idSuffix: "2_2",
    term: TERM_ONE,
    unit: UNIT_2,
    lesson: "الدرس 2.2: الألوان والمفردات والصفات (Colors & Descriptive Adjectives)",
    content: `الشرح والتحليل القواعدي العميق:
جدول الألوان الأكاديمي:
Red (أحمر), Blue (أزرق), Green (أخضر), Yellow (أصفر), Black (أسود), White (أبيض), Brown (بني), Orange (برتقالي), Pink (وردي), Purple (بنفسجي).
السؤال والجواب عن اللون:
السؤال: What color is it? (ما هذا اللون؟)
الإجابة: It is [Color]. أو It's [Color].
موقع الصفة والتأكيدات اللغوية (Adjective Position):
في اللغة الإنجليزية، الصفة تسبق الاسم الموصوف دائماً، بعكس اللغة العربية:
حقيبة حمراء -> A red bag (وليس Bag red).
أداة التعريف (a/an) توضع قبل الصفة:
A blue pen
An orange bag (لأن كلمة orange تبدأ بصوت متحرك).
✏️ بنك التمارين والتطبيقات المكثفة:
رتب الكلمات لتكوين جملة وصفية صحيحة:
is / a / It / car / yellow. -> It is a yellow car.
pen / a / is / This / red. -> This is a red pen.
اختر الإجابة الصحيحة:
What color ........ the sun? -> (is / are / am)
It is ........ apple. -> (a / an / two)
I have a (green bag / bag green). -> green bag`,
  },
  {
    idSuffix: "2_3",
    term: TERM_ONE,
    unit: UNIT_2,
    lesson: "الدرس 2.3: الصوتيات والحروف (Phonics: Group 2 - E, F, G, H)",
    content: `الشرح والتحليل القواعدي العميق:
E e: صوته القصير (/e/) كما في: Egg (بيضة), Elephant (فيل).
F f: صوته (/f/) كما في: Fish (سمكة), Fox (ثعلب), Frog (ضفدع).
G g: صوته الأساسي (/ɡ/) كما في: Goat (ماعز), Girl (بنت), Garden (حديقة).
H h: صوته (/h/) وينطق كحرف الهاء كما في: Hat (قبعة), Hen (دجاجة), House (بيت).
✏️ بنك التمارين والتطبيقات المكثفة:
ضع دائرة حول الكلمة التي تبدأ بالصوت المطلوب:
الصوت (/f/): (Egg / Fish / House)
الصوت (/h/): (Hat / Frog / Goat)
أكمل الحرف الناقص:
...gg -> E
...oat -> G`,
  },
  {
    idSuffix: "3_1",
    term: TERM_ONE,
    unit: UNIT_3,
    lesson: "الدرس 3.1: الأدوات الفصلية وأدوات التعريف (Classroom Objects & Articles a/an)",
    content: `الشرح والتحليل القواعدي العميق:
المفردات الفصلية الشاملة:
Book (كتاب), Notebook (دفتر), Pen (قلم حبر), Pencil (قلم رصاص), Eraser / Rubber (ممحاة), Ruler (مسطرة), Schoolbag (حقيبة مدرسية), Desk (طاولة مكتب), Chair (كرسي), Board (سبورة), Pencil case (مقلمة).
قاعدة أدوات النكرة المفردة (a / an):
تُستخدم (a) قبل الأسماء المفردة التي تبدأ بصوت ساكن (Consonant sound):
a book, a pencil, a ruler, a desk, a chair.
تُستخدم (an) قبل الأسماء المفردة التي تبدأ بصوت متحرك (Vowel sound: a, e, i, o, u):
an eraser, an apple, an elephant, an orange, an umbrella.
✏️ بنك التمارين والتطبيقات المكثفة:
ضع (a) أو (an) في الفراغ:
This is ........ eraser. -> an
That is ........ pencil case. -> a
I see ........ elephant. -> an
She has ........ yellow ruler. -> a
تصحيح الخطأ:
This is a eraser. -> This is an eraser.`,
  },
  {
    idSuffix: "3_2",
    term: TERM_ONE,
    unit: UNIT_3,
    lesson: "الدرس 3.2: الأوامر والتعليمات الصفية (Classroom Commands & Imperatives)",
    content: `الشرح والتحليل القواعدي العميق:
صياغة جملة الأمر المباشر (Imperative Sentence Structure):
تبدأ الجملة الأمرية بالفعل في المصدر المجرد (Base form of the verb) بدون إضافة أي فاعل قبله:
Stand up! (قف!)
Sit down! (اجلس!)
Open your book! (افتح كتابك!)
Close your door! (أغلق بابك!)
Listen to the teacher! (استمع للمعلم!)
Look at the board! (انظر إلى السبورة!)
Raise your hand! (ارفع يدك!)
Write your name! (اكتب اسمك!)
صيغة النهي (Negative Imperative):
لإعطاء أمر بعدم فعل شيء، نبدأ بـ Don't + Verb:
Don't talk! (لا تتحدث!)
Don't run! (لا تركض!)
أسلوب اللباقة (Politeness): إضافة كلمة Please في بداية الجملة أو نهايتها:
Open your book, please.
✏️ بنك التمارين والتطبيقات المكثفة:
اختر الفعل المناسب للتوجيه:
........ at the board, please. -> (Look / Listen / Stand)
Don't ........ in the classroom! -> (sit / run / listen)
........ your hand to speak. -> (Raise / Open / Close)
ترجم الجملة الآتية للإنجليزية:
"لا تتحدث، لو سمحت." -> Don't talk, please.`,
  },
  {
    idSuffix: "3_3",
    term: TERM_ONE,
    unit: UNIT_3,
    lesson: "الدرس 3.3: الصوتيات والحروف (Phonics: Group 3 - I, J, K, L)",
    content: `الشرح والتحليل القواعدي العميق:
I i: صوته القصير (/ɪ/) مثل: Ink (حبر), Insect (حشرة).
J j: صوته (/dʒ/) مثل: Jam (مربى), Juice (عصير), Jacket (سترة).
K k: صوته (/k/) مثل: Kite (طائرة ورقية), Kangaroo (كنغر), Key (مفتاح).
L l: صوته (/l/) مثل: Lion (أسد), Lemon (ليمون), Leaf (ورقة شجر).
✏️ بنك التمارين والتطبيقات المكثفة:
صل الصوت بالكلمة المناسبة:
I -> Ink
J -> Juice
K -> Kite
L -> Lion`,
  },

  // ── الفصل الدراسي الثاني ────────────────────────────────────────────
  {
    idSuffix: "4_1",
    term: TERM_TWO,
    unit: UNIT_4,
    lesson: "الدرس 4.1: أعضاء الجسم والملكيات (Body Parts & Have got / Has got)",
    content: `الشرح والتحليل القواعدي العميق:
تشريح المفردات الخاصة بالجسم:
Head (رأس), Face (وجه), Eyes (عيون), Ears (آذان), Nose (أنف), Mouth (فم), Teeth (أسنان - جمع غير منتظم مفردها Tooth), Arms (أذرع), Hands (أيدٍ), Fingers (أصابع اليد), Legs (أرجل), Feet (أقدام - جمع غير منتظم مفردها Foot), Hair (شعر).
شرح قاعدة الملكية والتعبير عن أجزاء الجسم (Have / Has):
I / You / We / They -> HAVE
I have two eyes and two ears.
They have long hair.
He / She / It -> HAS
He has one nose.
She has brown eyes.
It has four legs (للحيوان).
✏️ بنك التمارين والتطبيقات المكثفة:
اختر الفعل المناسب:
She ........ two hands. -> (have / has / is)
We ........ ten fingers. -> (have / has / are)
A rabbit ........ long ears. -> (have / has / is)
صحيح الكلمة بين القوسين:
I have two (foot). -> feet
He (have) blue eyes. -> has`,
  },
  {
    idSuffix: "4_2",
    term: TERM_TWO,
    unit: UNIT_4,
    lesson: "الدرس 4.2: صفات المقارنة والتضاد (Adjectives & Opposites)",
    content: `الشرح والتحليل القواعدي العميق:
جدول الصفات المتضادة بالكامل:
Big (كبير) <-> Small (صغير)
Tall (طويل القامة) <-> Short (قصير القامة)
Long (طويل للأشياء) <-> Short (قصير للأشياء)
Fast (سريع) <-> Slow (بطيء)
Happy (سعيد) <-> Sad (حزين)
Clean (نظيف) <-> Dirty (متسخ)
بناء الجمل الوصفية الكاملة:
Subject + verb to be (is/are) + Adjective
An elephant is big. A mouse is small.
Giraffes are tall. Turtles are slow.
✏️ بنك التمارين والتطبيقات المكثفة:
ضع الصفة المناسبة للحيوان:
A cheetah is ........ (fast / slow). -> fast
A turtle is ........ (fast / slow). -> slow
أكمل بعكس الصفة المذكورة:
He is not happy, he is ........ . -> sad
My pencil is not long, it is ........ . -> short`,
  },
  {
    idSuffix: "4_3",
    term: TERM_TWO,
    unit: UNIT_4,
    lesson: "الدرس 4.3: الصوتيات والحروف (Phonics: Group 4 - M, N, O, P)",
    content: `الشرح والتحليل القواعدي العميق:
M m: صوته (/m/) كما في: Monkey (قرد), Mouse (فأر), Milk (حليب).
N n: صوته (/n/) كما في: Nest (عش), Nose (أنف), Net (شبكة).
O o: صوته القصير (/ɒ/) كما في: Orange (برتقالة), Octopus (أخطبوط).
P p: صوته (/p/) ينطق بخروج هواء قوي كما في: Pen (قلم), Panda (باندا), Pizza (بيتزا).
✏️ بنك التمارين والتطبيقات المكثفة:
حدد الحرف الأول الصحيح:
🥛 [Milk] -> (M / N / O)
🍕 [Pizza] -> (B / P / M)`,
  },
  {
    idSuffix: "5_1",
    term: TERM_TWO,
    unit: UNIT_5,
    lesson: "الدرس 5.1: تصنيف الحيوانات وأسماء الإشارة للجمع (Animals & Demonstratives for Plural)",
    content: `الشرح والتحليل القواعدي العميق:
تصنيف المفردات:
Farm Animals (حيوانات المزرعة): Cow, Sheep, Goat, Horse, Duck, Chicken, Rooster.
Wild Animals (الحيوانات البرية): Lion, Tiger, Elephant, Monkey, Bear, Giraffe, Snake.
أسماء الإشارة للجمع (Demonstratives for Plural):
These are: تُستخدم للإشارة إلى الجمع القريب.
These are my books (هذه كتبي - القريبة مني).
Those are: تُستخدم للإشارة إلى الجمع البعيد.
Those are birds in the sky (تلك طيور في السماء - بعيدة).
✏️ بنك التمارين والتطبيقات المكثفة:
اختر اسم الإشارة المناسب:
........ are cows (جمع قريب). -> (These / This / That)
........ are lions (جمع بعيد). -> (These / Those / This)
ضع الكلمة في المكان الصحيح (Cow / Lion):
A ........ is a farm animal. -> Cow
A ........ is a wild animal. -> Lion`,
  },
  {
    idSuffix: "5_2",
    term: TERM_TWO,
    unit: UNIT_5,
    lesson: "الدرس 5.2: القدرات والاستطاعة (Abilities with Can / Can't)",
    content: `الشرح والتحليل القواعدي العميق:
قاعدة الإثبات والنفي مع (Can / Can't):
Can (يستطيع): Subject + can + Verb (المصدر المجرد)
A bird can fly (الطائر يستطيع الطيران).
Fish can swim (الأسماك تستطيع السباحة).
Can't / Cannot (لا يستطيع): Subject + can't + Verb (المصدر المجرد)
A kangaroo can't fly (الكنغر لا يستطيع الطيران).
A snake can't run (الثعبان لا يستطيع الركض).
تكوين الأسئلة والإجابة:
السؤال: Can + Subject + Verb?
Can a monkey climb trees?
الإجابة بالموافقة: Yes, it can.
الإجابة بالرفض: No, it can't.
✏️ بنك التمارين والتطبيقات المكثفة:
أكمل بـ (can) أو (can't):
Ducks ........ swim. -> can
Cats ........ fly. -> can't
أجب عن الأسئلة التالية (Yes, it can / No, it can't):
Can a horse run fast? -> Yes, it can.
Can a cow fly? -> No, it can't.`,
  },
  {
    idSuffix: "5_3",
    term: TERM_TWO,
    unit: UNIT_5,
    lesson: "الدرس 5.3: الصوتيات والحروف (Phonics: Group 5 - Q, R, S, T)",
    content: `الشرح والتحليل القواعدي العميق:
Q q: صوته (/kw/) ويكون متبوعاً بالحرف u دائماً مثل: Queen (ملكة), Quiet (هادئ).
R r: صوته (/r/) مثل: Rabbit (أرنب), Red (أحمر), Ring (خاتم).
S s: صوته (/s/) مثل: Sun (شمس), Snake (ثعبان), Star (نجمة).
T t: صوته (/t/) مثل: Tree (شجرة), Tiger (نمر), Tomato (طماطم).
✏️ بنك التمارين والتطبيقات المكثفة:
اختر الحرف الناقص للكلمة:
...un (شمس) -> (R / S / T)
...ree (شجرة) -> (Q / S / T)`,
  },
  {
    idSuffix: "6_1",
    term: TERM_TWO,
    unit: UNIT_6,
    lesson: "الدرس 6.1: الأطعمة والتفضيلات (Food, Drinks & Present Simple with Like)",
    content: `الشرح والتحليل القواعدي العميق:
قائمة الطعام والمشروبات الأكاديمية:
Food: Bread (خبز), Rice (أرز), Chicken (دجاج), Meat (لحم), Cheese (جبن), Fish (سمك), Salad (سلطة), Pizza (بيتزا).
Drinks: Water (ماء), Milk (حليب), Juice (عصير), Tea (شاي).
قواعد التعبير عن التفضيل والمشاعر مع (Like):
الإثبات: I / You / We / They + like [Food]
I like chicken and rice.
النفي: I / You / We / They + don't like [Food]
I don't like cheese.
السؤال والجواب المباشر:
Do you like fish?
Yes, I do (نعم أحبه).
No, I don't (لا لا أحبه).
✏️ بنك التمارين والتطبيقات المكثفة:
أكمل الفراغ بما يناسب المعنى:
A: Do you ........ pizza?
B: Yes, I do.
الإجابة: like
رتب الجمل التالية:
don't / I / milk / like. -> I don't like milk.
like / We / apples. -> We like apples.`,
  },
  {
    idSuffix: "6_2",
    term: TERM_TWO,
    unit: UNIT_6,
    lesson: "الدرس 6.2: الأفعال والأنشطة اليومية (Daily Actions & Simple Present)",
    content: `الشرح والتحليل القواعدي العميق:
أفعال الأنشطة اليومية المتكررة:
Eat breakfast (يأكل الفطور), Drink water (يشرب الماء), Play football (يلعب كرة القدم), Read a book (يقرأ كتاباً), Sleep early (ينام مبكراً), Wash hands (يغسل يديه).
المضارع البسيط للروتين اليومي (Simple Present Rule):
إذا كان الفاعل (I / You / We / They)، يبقى الفعل مجرداً:
I eat breakfast every morning.
إذا كان الفاعل مفرد غائب (He / She / It)، نضيف (s) للفعل:
He eats breakfast every morning.
She drinks milk every day.
✏️ بنك التمارين والتطبيقات المكثفة:
اختر صيغة الفعل الصحيحة:
He (play / plays) football on Friday. -> plays
I (wash / washes) my hands. -> wash
She (read / reads) a book. -> reads`,
  },
  {
    idSuffix: "6_3",
    term: TERM_TWO,
    unit: UNIT_6,
    lesson: "الدرس 6.3: الأصوات المركبة والحروف الأخيرة (Digraphs & Letters U to Z)",
    content: `الشرح والتحليل القواعدي العميق:
الحروف المتبقية:
U u: (/ʌ/) -> Umbrella (مظلة), Up (أعلى).
V v: (/v/) -> Van (شاحنة صغيرة), Vase (مزهرية).
W w: (/w/) -> Water (ماء), Watch (ساعة يد).
X x: (/ks/) -> Box (صندوق), Fox (ثعلب).
Y y: (/j/) -> Yellow (أصفر), Yo-yo (يويو).
Z z: (/z/) -> Zoo (حديقة حيوان), Zebra (حمار وحشي).
الأصوات المركبة (Consonant Digraphs):
sh -> تُنطق مثل حرف "ش" (/ʃ/): Fish, Ship, Shoe, Shop.
ch -> تُنطق مثل "تش" (/tʃ/): Chair, Cheese, Chicken, Teacher.
th -> تُنطق مثل حرف "ث" (/θ/) أو "ذ" (/ð/): Three, Thank you, Father.
✏️ بنك التمارين والتطبيقات المكثفة:
أكمل الحرفين المركبين المناسبين (sh / ch / th):
.....icken (دجاج) -> ch
Fi..... (سمك) -> sh
.....ree (رقم 3) -> th
حدد الكلمة التي تحتوي على صوت (sh):
(Chair / Ship / Three) -> Ship`,
  },
];

/** المنهج بعد تنقية النصوص — وهو ما يُقرأ ويُكتب، لا الخام. */
export const GRADE4_ENGLISH_CURRICULUM = RAW.map((item) => ({
  ...item,
  content: stripMathMarkup(item.content),
}));

/** الفصول ووحداتها ودروسها، بالشكل الذي تقرؤه الشجرة الأكاديمية. */
export function englishTermsForTree() {
  const terms = [];
  for (const item of GRADE4_ENGLISH_CURRICULUM) {
    let term = terms.find((entry) => entry.term === item.term);
    if (!term) {
      term = { term: item.term, units: [], lessons: {} };
      terms.push(term);
    }
    if (!term.units.includes(item.unit)) term.units.push(item.unit);
    if (!term.lessons[item.unit]) term.lessons[item.unit] = [];
    term.lessons[item.unit].push(item.lesson);
  }
  return terms;
}
