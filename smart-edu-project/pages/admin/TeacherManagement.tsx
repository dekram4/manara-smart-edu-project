
import React, { useState, useEffect } from 'react';
import { TeacherInfo } from '../../types';
import { STORAGE_KEYS, DEFAULT_PASSWORD } from '../../constants';
import { hashPassword, ensureHashed } from '../../utils/password';
import { normalizeScopeValue } from '../../utils/scope';
import { getPermissionPackages } from '../../permissions';

interface TeacherManagementProps {
  onUpdate: () => void;
}

const TeacherManagement: React.FC<TeacherManagementProps> = ({ onUpdate }) => {
  const [teachers, setTeachers] = useState<TeacherInfo[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [editingTeacher, setEditingTeacher] = useState<TeacherInfo | null>(null);
  const [teacherPackages, setTeacherPackages] = useState<any[]>([]);
  const [formData, setFormData] = useState({
    name: '',
    username: '',
    password: DEFAULT_PASSWORD,
    teacherId: '',
    subject: '',
    permissionPackageId: ''
  });

  useEffect(() => {
    loadTeachers();
  }, []);

  const loadTeachers = () => {
    const saved = localStorage.getItem(STORAGE_KEYS.TEACHERS);
    if (saved) setTeachers(JSON.parse(saved));
    setTeacherPackages(getPermissionPackages().filter(pkg => pkg.role === 'teacher'));
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    if (!formData.name.trim() || !formData.username.trim() || !formData.teacherId.trim()) {
      alert('⚠️ يرجى ملء جميع الحقول المطلوبة');
      return;
    }

    // التحقق من عدم تكرار اسم المستخدم
    const existingTeacher = teachers.find(t => t.username === formData.username && t.id !== editingTeacher?.id);
    if (existingTeacher) {
      alert('❌ اسم المستخدم موجود مسبقاً');
      return;
    }
    
    // التحقق من عدم تكرار رقم الهوية (teacherId) عبر جميع المستخدمين
    if (formData.teacherId && formData.teacherId.trim()) {
      const teacherId = formData.teacherId.trim();
      
      // التحقق من المعلمين (تكرار teacherId)
      const duplicateTeacher = teachers.find(t => 
        t.teacherId === teacherId && t.id !== editingTeacher?.id
      );
      if (duplicateTeacher) {
        alert(`⚠️ رقم الهوية ${teacherId} مستخدم بالفعل من قبل المعلم: ${duplicateTeacher.name}`);
        return;
      }
      
      // التحقق من أولياء الأمور
      const allParents = JSON.parse(localStorage.getItem(STORAGE_KEYS.PARENTS) || '[]');
      const duplicateParent = allParents.find((p: any) => p.nationalId === teacherId);
      if (duplicateParent) {
        alert(`⚠️ رقم الهوية ${teacherId} مستخدم بالفعل من قبل ولي الأمر: ${duplicateParent.name}`);
        return;
      }
      
      // التحقق من الطلاب
      const allStudents = JSON.parse(localStorage.getItem(STORAGE_KEYS.STUDENTS) || '[]');
      const duplicateStudent = allStudents.find((s: any) => s.nationalId === teacherId);
      if (duplicateStudent) {
        alert(`⚠️ رقم الهوية ${teacherId} مستخدم بالفعل من قبل الطالب: ${duplicateStudent.name}`);
        return;
      }
    }

    const teacher: TeacherInfo = {
      id: editingTeacher?.id || `teacher_${Date.now()}`,
      name: formData.name.trim(),
      username: formData.username.trim(),
      password: ensureHashed(formData.password || editingTeacher?.password || DEFAULT_PASSWORD),
      teacherId: formData.teacherId.trim(),
      subject: formData.subject?.trim() || '',
      createdAt: editingTeacher?.createdAt || new Date().toISOString(),
      createdBy: 'admin',
      lastActivity: new Date().toISOString(),
      mustChangePassword: !editingTeacher // يجب تغيير كلمة المرور عند أول دخول
      ,permissionPackageId: formData.permissionPackageId || editingTeacher?.permissionPackageId || undefined
    };

    let updated;
    if (editingTeacher) {
      updated = teachers.map(t => t.id === editingTeacher.id ? teacher : t);
    } else {
      updated = [...teachers, teacher];
    }

    localStorage.setItem(STORAGE_KEYS.TEACHERS, JSON.stringify(updated));
    setTeachers(updated);
    setShowForm(false);
    setEditingTeacher(null);
    resetForm();
    alert(`✅ تم ${editingTeacher ? 'تحديث' : 'إضافة'} المعلم بنجاح`);
  };

  const handleEdit = (teacher: TeacherInfo) => {
    setEditingTeacher(teacher);
    setFormData({
      name: teacher.name,
      username: teacher.username,
      password: '',
      teacherId: teacher.teacherId,
      subject: teacher.subject || ''
      ,permissionPackageId: teacher.permissionPackageId || ''
    });
    setShowForm(true);
  };

  const handleDelete = (id: string) => {
    if (!confirm('🗑️ حذف المعلم نهائياً؟ سيتم حذف جميع البيانات المرتبطة به.')) return;
    
    const updated = teachers.filter(t => t.id !== id);
    localStorage.setItem(STORAGE_KEYS.TEACHERS, JSON.stringify(updated));
    setTeachers(updated);
    
    // حذف أولياء الأمور المرتبطين بهذا المعلم
    const parents = JSON.parse(localStorage.getItem(STORAGE_KEYS.PARENTS) || '[]');
    const updatedParents = parents.filter((p: any) =>
      normalizeScopeValue(p.createdBy) !== normalizeScopeValue(id)
    );
    localStorage.setItem(STORAGE_KEYS.PARENTS, JSON.stringify(updatedParents));
    
    alert('✅ تم حذف المعلم وجميع البيانات المرتبطة به');
  };

  const resetForm = () => {
    setFormData({
      name: '',
      username: '',
      password: DEFAULT_PASSWORD,
      teacherId: '',
      subject: ''
      ,permissionPackageId: ''
    });
  };

  const resetPassword = (id: string) => {
    if (!confirm('🔄 إعادة تعيين كلمة المرور إلى 123456؟')) return;
    
    const updated = teachers.map(t => 
      t.id === id ? { ...t, password: hashPassword(DEFAULT_PASSWORD), mustChangePassword: true } : t
    );
    
    localStorage.setItem(STORAGE_KEYS.TEACHERS, JSON.stringify(updated));
    setTeachers(updated);
    alert('✅ تم إعادة تعيين كلمة المرور');
  };

  return (
    <div className="space-y-6">
      {/* 📊 Header */}
      <div className="flex flex-col items-stretch justify-between gap-4 sm:flex-row sm:items-center">
        <div className="min-w-0">
          <h1 className="text-2xl font-black text-purple-900 sm:text-3xl">👨‍🏫 إدارة المعلمين</h1>
          <p className="text-purple-500 font-medium">إضافة وإدارة حسابات المعلمين</p>
        </div>
        <button
          onClick={() => {
            setShowForm(!showForm);
            setEditingTeacher(null);
            resetForm();
            setTeacherPackages(getPermissionPackages().filter(pkg => pkg.role === 'teacher'));
          }}
          className="min-h-11 bg-gradient-to-r from-purple-500 to-violet-500 text-white px-5 py-3 rounded-[20px] font-black text-base hover:shadow-2xl transition-all sm:px-8 sm:py-4 sm:rounded-[25px] sm:text-lg"
        >
          {showForm ? '❌ إلغاء' : '➕ إضافة معلم جديد'}
        </button>
      </div>

      {/* 📝 نموذج الإضافة/التعديل */}
      {showForm && (
        <div className="mobile-modal-panel bg-gradient-to-br from-blue-50 to-violet-50 p-4 rounded-[28px] border-2 border-blue-300 shadow-2xl sm:p-8 sm:rounded-[40px]">
          <h2 className="text-2xl font-black text-blue-900 mb-8">
            {editingTeacher ? '✏️ تعديل بيانات المعلم' : '✨ إضافة معلم جديد'}
          </h2>

          <form onSubmit={handleSubmit} className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* اسم المعلم */}
              <div>
                <label className="block font-black text-blue-900 mb-2">👤 اسم المعلم</label>
                <input
                  type="text"
                  value={formData.name}
                  onChange={e => setFormData({ ...formData, name: e.target.value })}
                  className="w-full p-4 border-2 border-blue-300 rounded-2xl outline-none focus:border-blue-600 bg-white font-bold text-lg"
                  placeholder="أحمد محمد"
                  required
                />
              </div>

              {/* هوية المعلم */}
              <div>
                <label className="block font-black text-blue-900 mb-2">🆔 هوية المعلم</label>
                <input
                  type="text"
                  value={formData.teacherId}
                  onChange={e => setFormData({ ...formData, teacherId: e.target.value })}
                  className="w-full p-4 border-2 border-blue-300 rounded-2xl outline-none focus:border-blue-600 bg-white font-bold text-lg"
                  placeholder="1234567890"
                  required
                />
              </div>

              {/* اسم المستخدم */}
              <div>
                <label className="block font-black text-blue-900 mb-2">🔐 اسم المستخدم</label>
                <input
                  type="text"
                  value={formData.username}
                  onChange={e => setFormData({ ...formData, username: e.target.value })}
                  className="w-full p-4 border-2 border-blue-300 rounded-2xl outline-none focus:border-blue-600 bg-white font-bold text-lg"
                  placeholder="teacher123"
                  required
                />
              </div>

              {/* كلمة المرور */}
              <div>
                <label className="block font-black text-blue-900 mb-2">🔑 كلمة المرور</label>
                <input
                  type="text"
                  value={formData.password}
                  onChange={e => setFormData({ ...formData, password: e.target.value })}
                  className="w-full p-4 border-2 border-blue-300 rounded-2xl outline-none focus:border-blue-600 bg-white font-bold text-lg"
                  placeholder={editingTeacher ? 'اتركه فارغاً للإبقاء على كلمة المرور الحالية' : '123456'}
                  required={!editingTeacher}
                />
                <p className="text-xs text-blue-600 mt-1">
                  سيُطلب من المعلم تغيير كلمة المرور عند أول دخول
                </p>
              </div>

              {/* المادة */}
              <div>
                <label className="block font-black text-blue-900 mb-2">📚 المادة/التخصص</label>
                <input
                  type="text"
                  value={formData.subject}
                  onChange={e => setFormData({ ...formData, subject: e.target.value })}
                  className="w-full p-4 border-2 border-blue-300 rounded-2xl outline-none focus:border-blue-600 bg-white font-bold text-lg"
                  placeholder="الرياضيات، العلوم، إلخ... (اختياري)"
                />
              </div>

              <div>
                <label className="block font-black text-blue-900 mb-2">🔐 إدارة صلاحيات المعلم</label>
                <select
                  value={formData.permissionPackageId}
                  onChange={e => setFormData({ ...formData, permissionPackageId: e.target.value })}
                  className="w-full p-4 border-2 border-blue-300 rounded-2xl outline-none focus:border-blue-600 bg-white font-bold text-lg"
                >
                  <option value="">الصلاحيات العامة الحالية</option>
                  {teacherPackages.map(pkg => (
                    <option key={pkg.id} value={pkg.id}>{pkg.name}</option>
                  ))}
                </select>
              </div>
            </div>

            <button
              type="submit"
              className="w-full bg-gradient-to-r from-purple-400 to-violet-500 text-white py-5 rounded-[24px] font-black text-xl shadow-xl hover:shadow-2xl transition-all"
            >
              {editingTeacher ? '💾 حفظ التعديلات' : '➕ إضافة المعلم'}
            </button>
          </form>
        </div>
      )}

      {/* 📋 قائمة المعلمين */}
      <div className="space-y-4">
        <h2 className="text-2xl font-black text-purple-900">
          📚 المعلمون المسجلون ({teachers.length})
        </h2>

        {teachers.length === 0 ? (
          <div className="p-32 text-center bg-white rounded-[40px] border-2 border-dashed border-purple-200">
            <div className="text-6xl mb-4">👨‍🏫</div>
            <h3 className="text-2xl font-black text-purple-300 mb-2">لا يوجد معلمون حتى الآن</h3>
            <p className="text-purple-400">ابدأ بإضافة معلم جديد</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-4">
            {teachers.map(teacher => (
              <div key={teacher.id} className="bg-white p-6 rounded-[30px] border-2 border-purple-100 shadow-sm hover:shadow-lg transition-all">
                <div className="flex justify-between items-start">
                  <div className="flex-1">
                    <div className="flex items-center gap-3 mb-3">
                      <div className="w-14 h-14 bg-gradient-to-br from-purple-500 to-violet-600 rounded-full flex items-center justify-center text-2xl">
                        👨‍🏫
                      </div>
                      <div>
                        <h3 className="text-xl font-black text-purple-900">{teacher.name}</h3>
                        <p className="text-purple-500 text-sm">@{teacher.username}</p>
                      </div>
                    </div>

                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-4">
                      <div className="bg-blue-50 p-3 rounded-xl">
                        <p className="text-xs text-blue-600 font-bold">هوية المعلم</p>
                        <p className="font-black text-blue-900">{teacher.teacherId}</p>
                      </div>
                      <div className="bg-green-50 p-3 rounded-xl">
                        <p className="text-xs text-green-600 font-bold">تاريخ الإنشاء</p>
                        <p className="font-black text-green-900">
                          {new Date(teacher.createdAt).toLocaleDateString('ar-SA')}
                        </p>
                      </div>
                      <div className="bg-purple-50 p-3 rounded-xl">
                        <p className="text-xs text-purple-600 font-bold">آخر نشاط</p>
                        <p className="font-black text-purple-900">
                          {new Date(teacher.lastActivity).toLocaleDateString('ar-SA')}
                        </p>
                      </div>
                      <div className="bg-orange-50 p-3 rounded-xl">
                        <p className="text-xs text-orange-600 font-bold">الحالة</p>
                        <p className="font-black text-orange-900">
                          {teacher.mustChangePassword ? '⚠️ يجب تغيير كلمة المرور' : '✅ نشط'}
                        </p>
                      </div>
                    </div>
                  </div>

                  <div className="flex gap-2 mr-4">
                    <button
                      onClick={() => handleEdit(teacher)}
                      className="p-3 bg-blue-100 text-blue-600 rounded-xl hover:bg-blue-200 transition-all"
                      title="تعديل"
                    >
                      ✏️
                    </button>
                    <button
                      onClick={() => resetPassword(teacher.id)}
                      className="p-3 bg-orange-100 text-orange-600 rounded-xl hover:bg-orange-200 transition-all"
                      title="إعادة تعيين كلمة المرور"
                    >
                      🔄
                    </button>
                    <button
                      onClick={() => handleDelete(teacher.id)}
                      className="p-3 bg-red-100 text-red-600 rounded-xl hover:bg-red-200 transition-all"
                      title="حذف"
                    >
                      🗑️
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

export default TeacherManagement;
