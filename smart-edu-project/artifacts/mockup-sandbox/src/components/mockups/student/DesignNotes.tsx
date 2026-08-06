import './_group.css';

export function DesignNotes() {
  const principles = [
    { icon: '🌟', title: 'ألوان فاتحة وسارية', desc: 'باستخدام الأصفر والأبيض والأصفر والوردي للطاقة والحماس' },
    { icon: '✨', title: 'تأثيرات وحركات', desc: 'رموز متحركة تطفو للطفل وتشجعه على التعامل' },
    { icon: '🎮', title: 'التحويل لعبة', desc: 'إضافة نقاط ومستويات وجواهر وتشجيع وأصوات تشجيع' },
    { icon: '🎉', title: 'التشجيع والمكافآت', desc: 'الإشارات البصرية والصوتية ورموز تشجيع في كل انجاز' },
    { icon: '👤', title: 'شخصيات كرتونية', desc: 'شخصيات مفرحة مع انفعالات تفاعلية ومشاهدات صوتية' },
    { icon: '🎨', title: 'رسومات متحركة', desc: 'نجمات تعليق ورسومات ديكوراتية متحركة في الخلفية' },
  ];

  return (
    <div className="lamsa-root min-h-screen bg-gradient-to-br from-purple-50 via-pink-50 to-orange-50 p-6">
      <div className="max-w-md mx-auto">
        <div className="text-center mb-8">
          <div className="text-6xl mb-4 lamsa-bounce">🎨</div>
          <h1 className="text-3xl font-black text-gray-800">مبادئ التصميم</h1>
          <p className="text-gray-600 mt-2 font-bold">تصميم مستوحى من تطبيق لمسة</p>
        </div>

        <div className="space-y-4">
          {principles.map((p, i) => (
            <div
              key={i}
              className="bg-white rounded-2xl p-5 shadow-md border-2 border-gray-100 lamsa-bounce hover:shadow-lg hover:border-orange-300 transition-all duration-300"
              style={{ animationDelay: `${i * 0.1}s` }}
            >
              <div className="flex items-start gap-4">
                <div className="text-4xl lamsa-float" style={{ animationDelay: `${i * 0.3}s` }}>{p.icon}</div>
                <div>
                  <h3 className="font-black text-gray-800 text-lg">{p.title}</h3>
                  <p className="text-gray-600 text-sm font-semibold mt-1">{p.desc}</p>
                </div>
              </div>
            </div>
          ))}
        </div>

        <div className="mt-8 bg-gradient-to-r from-orange-400 to-pink-500 rounded-2xl p-5 text-white text-center shadow-lg">
          <div className="text-4xl mb-2">🚀</div>
          <p className="font-black text-lg">خلنا منصة تعليمية تفاعلية تفوق لمسة!</p>
        </div>
      </div>
    </div>
  );
}
