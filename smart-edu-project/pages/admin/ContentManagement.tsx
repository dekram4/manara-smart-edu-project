
import React, { useState, useEffect } from 'react';
import { LessonConfig } from '../../types';
import { STORAGE_KEYS } from '../../constants';
import { getRecordTeacherId, normalizeScopeValue } from '../../utils/scope';
import { getTeacherPermissions, isLimitReached } from '../../permissions';
import { deleteUploadedVideo, getVideoSourceType, isMp4VideoUrl, uploadMp4Video, VideoSourceType } from '../../utils/video';

interface ContentManagementProps {
  onUpdate: () => void;
  teacherId?: string;
  teacherName?: string;
  permissionPackageId?: string;
}

const ContentManagement: React.FC<ContentManagementProps> = ({ onUpdate, teacherId, teacherName, permissionPackageId }) => {
  const [lessons, setLessons] = useState<LessonConfig[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [editingLesson, setEditingLesson] = useState<LessonConfig | null>(null);
  
  // للمشرف: اختيار المعلم
  const [teachers, setTeachers] = useState<any[]>([]);
  const [selectedTeacherId, setSelectedTeacherId] = useState<string>(teacherId || '');
  const [selectedTeacherName, setSelectedTeacherName] = useState<string>(teacherName || '');
  
  const [formData, setFormData] = useState({
    grade: '', atram: '', subject: '', term: '', unit: '',
    explanationVideoUrl: '', explanationVideoType: 'embed' as VideoSourceType, explanationVideoFile: null as File | null,
    avatarInteractionUrl: '', liveMeetingUrl: '', lessonContent: ''
  });

  const [options, setOptions] = useState({ grades: [] });
  const [availableAtrams, setAvailableAtrams] = useState<string[]>([]);
  const [availableSubjects, setAvailableSubjects] = useState<string[]>([]);
  const [availableTerms, setAvailableTerms] = useState<string[]>([]);
  const [availableUnits, setAvailableUnits] = useState<string[]>([]);

  useEffect(() => {
    // تحميل المعلمين إذا كان المشرف
    if (!teacherId) {
      const savedTeachers = JSON.parse(localStorage.getItem(STORAGE_KEYS.TEACHERS) || '[]');
      setTeachers(savedTeachers);
    }
    
    loadData();
    loadAcademicOptions();
  }, [teacherId, selectedTeacherId]); // إعادة التحميل عند تغيير teacherId

  const loadData = () => {
    const saved = localStorage.getItem(STORAGE_KEYS.LESSON_CONFIGS);
    if (saved) {
      const allLessons = JSON.parse(saved);
      // إذا كان هناك teacherId أو selectedTeacherId، عرض محتوى هذا المعلم فقط
      const effectiveTeacherId = teacherId || selectedTeacherId;
      const filteredLessons = effectiveTeacherId 
        ? allLessons.filter((l: LessonConfig) => getRecordTeacherId(l) === normalizeScopeValue(effectiveTeacherId))
        : allLessons;
      setLessons(filteredLessons);
    }
  };

  // دالة تغيير المعلم المختار (للمشرف فقط)
  const handleTeacherChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const newTeacherId = e.target.value;
    setSelectedTeacherId(newTeacherId);
    
    if (newTeacherId === 'admin') {
      setSelectedTeacherName('المشرف - محتوى عام');
    } else if (newTeacherId) {
      const teacher = teachers.find(t => t.id === newTeacherId);
      setSelectedTeacherName(teacher?.name || '');
    } else {
      setSelectedTeacherName('');
    }
  };

  // دالة مساعدة للحصول على الإعدادات المفلترة حسب المعلم
  const getFilteredHierarchicalConfigs = () => {
    const allHierarchicalConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    
    // فلترة الإعدادات الأكاديمية حسب المعلم
    const effectiveTeacherId = teacherId || selectedTeacherId;
    let hierarchicalConfigs;
    
    if (effectiveTeacherId && effectiveTeacherId !== 'admin') {
      // للمعلم: إظهار إعداداته + الإعدادات العامة (ولكن تفضيل نسخته على النسخة العامة)
      if (teacherId) {
        const teacherConfigs = allHierarchicalConfigs.filter((c: any) => getRecordTeacherId(c) === normalizeScopeValue(effectiveTeacherId));
        const adminConfigs = allHierarchicalConfigs.filter((c: any) =>
          getRecordTeacherId(c) === 'admin' || !c.createdBy
        );
        
        // دمج: إذا كان للمعلم نسخة من إعداد عام، نستخدم نسخة المعلم
        const mergedConfigs = [...teacherConfigs];
        adminConfigs.forEach(adminConfig => {
          const hasTeacherVersion = teacherConfigs.some(tc => tc.grade === adminConfig.grade);
          if (!hasTeacherVersion) {
            mergedConfigs.push(adminConfig);
          }
        });
        hierarchicalConfigs = mergedConfigs;
      } else {
        // للمشرف عند اختيار معلم معين: إظهار إعدادات هذا المعلم فقط
        hierarchicalConfigs = allHierarchicalConfigs.filter((c: any) =>
          getRecordTeacherId(c) === normalizeScopeValue(effectiveTeacherId)
        );
      }
    } else {
      // للمشرف بدون اختيار معلم أو عند اختيار "محتوى عام": إظهار جميع الإعدادات
      hierarchicalConfigs = allHierarchicalConfigs;
    }
    
    return hierarchicalConfigs;
  };

  const loadAcademicOptions = () => {
    const hierarchicalConfigs = getFilteredHierarchicalConfigs();
    const gradesList = hierarchicalConfigs.map((c: any) => c.grade);
    
    setOptions({
      grades: gradesList
    });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (teacherId && !getTeacherPermissions({ permissionPackageId }).canManageContent) {
      alert('⚠️ ليس لديك صلاحية إدارة المحتوى التعليمي');
      return;
    }
    
    if (!formData.grade || !formData.subject || !formData.atram || !formData.term || !formData.unit) {
      alert('يرجى اختيار جميع التصنيفات الأكاديمية');
      return;
    }

    let explanationVideoUrl = formData.explanationVideoUrl.trim();
    if (formData.explanationVideoType === 'mp4') {
      if (formData.explanationVideoFile) {
        try {
          const uploaded = await uploadMp4Video(formData.explanationVideoFile);
          explanationVideoUrl = uploaded.url;
        } catch (error) {
          alert(`⚠️ ${error instanceof Error ? error.message : 'فشل رفع ملف الفيديو'}`);
          return;
        }
      } else if (isMp4VideoUrl(editingLesson?.explanationVideoUrl)) {
        explanationVideoUrl = editingLesson.explanationVideoUrl || '';
      } else if (!isMp4VideoUrl(editingLesson?.explanationVideoUrl)) {
        alert('يرجى اختيار ملف MP4');
        return;
      }
    } else if (!explanationVideoUrl && editingLesson?.explanationVideoUrl && isMp4VideoUrl(editingLesson.explanationVideoUrl)) {
      void deleteUploadedVideo(editingLesson.explanationVideoUrl);
    }

    const ownerId = editingLesson?.createdBy ||
      teacherId ||
      (selectedTeacherId === 'admin' ? 'admin' : selectedTeacherId) ||
      'admin';
    const ownerName = editingLesson?.createdByName ||
      teacherName ||
      (selectedTeacherId === 'admin' ? 'المشرف - محتوى عام' : selectedTeacherName) ||
      'المشرف';

    const lesson: LessonConfig = {
      id: editingLesson?.id || Date.now().toString(),
      grade: formData.grade.trim(),
      subject: formData.subject.trim(),
      atram: formData.atram.trim(),
      term: formData.term.trim(),
      unit: formData.unit.trim(),
      explanationVideoUrl,
      explanationVideoType: formData.explanationVideoType,
      avatarInteractionUrl: formData.avatarInteractionUrl ? formData.avatarInteractionUrl.trim() : '',
      liveMeetingUrl: formData.liveMeetingUrl ? formData.liveMeetingUrl.trim() : '',
      lessonContent: formData.lessonContent.trim(),
      createdAt: editingLesson?.createdAt || new Date().toISOString(),
      createdBy: ownerId,
      createdByName: ownerName
    };

    const allLessons: LessonConfig[] = JSON.parse(
      localStorage.getItem(STORAGE_KEYS.LESSON_CONFIGS) || '[]',
    );
    if (teacherId && !editingLesson) {
      const permissions = getTeacherPermissions({ permissionPackageId });
      const teacherLessonCount = allLessons.filter(
        lesson => getRecordTeacherId(lesson) === normalizeScopeValue(teacherId),
      ).length;
      if (!isLimitReached(teacherLessonCount, permissions.maxContent)) {
        // The limit allows this new lesson.
      } else {
        alert(`⚠️ وصلت إلى الحد الأقصى المسموح به (${permissions.maxContent}) من المحتوى التعليمي`);
        return;
      }
    }
    let updated: LessonConfig[];
    if (editingLesson) {
      updated = allLessons.map(l => l.id === editingLesson.id ? lesson : l);
    } else {
      updated = [...allLessons, lesson];
    }

    localStorage.setItem(STORAGE_KEYS.LESSON_CONFIGS, JSON.stringify(updated));
    if (
      editingLesson?.explanationVideoUrl
      && editingLesson.explanationVideoUrl !== explanationVideoUrl
      && isMp4VideoUrl(editingLesson.explanationVideoUrl)
    ) {
      void deleteUploadedVideo(editingLesson.explanationVideoUrl);
    }
    
    setShowForm(false);
    setEditingLesson(null);
    setFormData({ grade: '', atram: '', subject: '', term: '', unit: '', explanationVideoUrl: '', explanationVideoType: 'embed', explanationVideoFile: null, avatarInteractionUrl: '', liveMeetingUrl: '', lessonContent: '' });
    loadData();
    onUpdate();
  };

  const handleEdit = (lesson: LessonConfig) => {
    setEditingLesson(lesson);
    setFormData({
      grade: lesson.grade,
      atram: lesson.atram,
      subject: lesson.subject,
      term: lesson.term,
      unit: lesson.unit,
      explanationVideoUrl: lesson.explanationVideoUrl || '',
      explanationVideoType: getVideoSourceType(lesson.explanationVideoType, lesson.explanationVideoUrl),
      explanationVideoFile: null,
      avatarInteractionUrl: lesson.avatarInteractionUrl || '',
      liveMeetingUrl: lesson.liveMeetingUrl || '',
      lessonContent: lesson.lessonContent
    });
    
    // تحميل القوائم المترابطة بناءً على البيانات الموجودة - البنية الجديدة: Grade → Atram → Subject → Term → Unit
    const hierarchicalConfigs = getFilteredHierarchicalConfigs();
    const gradeConfig = hierarchicalConfigs.find((c: any) => c.grade === lesson.grade);
    if (gradeConfig) {
      setAvailableAtrams(gradeConfig.atrams.map((a: any) => a.atram));
      
      const atramConfig = gradeConfig.atrams.find((a: any) => a.atram === lesson.atram);
      if (atramConfig) {
        setAvailableSubjects(atramConfig.subjects.map((s: any) => s.subject));
        
        const subjectConfig = atramConfig.subjects.find((s: any) => s.subject === lesson.subject);
        if (subjectConfig) {
          setAvailableTerms(subjectConfig.terms.map((t: any) => t.term));
          
          const termConfig = subjectConfig.terms.find((t: any) => t.term === lesson.term);
          if (termConfig) {
            setAvailableUnits(termConfig.units);
          }
        }
      }
    }
    
    setShowForm(true);
  };

  const handleDelete = (id: string) => {
    if (confirm('حذف الدرس؟')) {
      const allLessons: LessonConfig[] = JSON.parse(
        localStorage.getItem(STORAGE_KEYS.LESSON_CONFIGS) || '[]',
      );
      const updated = allLessons.filter(l => l.id !== id);
      localStorage.setItem(STORAGE_KEYS.LESSON_CONFIGS, JSON.stringify(updated));
      loadData();
      onUpdate();
    }
  };

  return (
    <div className="space-y-6">
      {/* للمشرف فقط: اختيار المعلم */}
      {!teacherId && (
        <div style={{ 
          backgroundColor: 'white', 
          padding: '25px', 
          borderRadius: '16px', 
          border: '2px solid #818cf8',
          marginBottom: '25px',
          boxShadow: '0 4px 6px rgba(99, 102, 241, 0.1)'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '15px', marginBottom: '15px' }}>
            <span style={{ fontSize: '2rem' }}>📚</span>
            <div>
              <h3 style={{ fontWeight: 'bold', fontSize: '1.3rem', color: '#4338ca', marginBottom: '5px' }}>
                اختر المعلم لإدارة المحتوى
              </h3>
              <p style={{ color: '#6b7280', fontSize: '0.9rem' }}>
                كل معلم له محتوى تعليمي مستقل مرتبط بإعداداته الأكاديمية
              </p>
            </div>
          </div>
          
          <select 
            value={selectedTeacherId} 
            onChange={handleTeacherChange}
            style={{ 
              width: '100%', 
              padding: '15px', 
              fontSize: '1.1rem',
              fontWeight: 'bold',
              border: '2px solid #c7d2fe',
              borderRadius: '12px',
              backgroundColor: '#f5f3ff',
              color: '#4338ca',
              outline: 'none',
              cursor: 'pointer'
            }}
          >
            <option value="">🌐 عرض الكل (جميع المعلمين)</option>
            <option value="admin">📚 محتوى عام (يظهر لجميع المعلمين)</option>
            {teachers.map(teacher => (
              <option key={teacher.id} value={teacher.id}>
                👨‍🏫 {teacher.name} - {teacher.subject || 'معلم'}
              </option>
            ))}
          </select>
          
          {selectedTeacherId === 'admin' && (
            <div style={{ 
              marginTop: '15px', 
              padding: '12px', 
              backgroundColor: '#dcfce7',
              borderRadius: '8px',
              borderRight: '4px solid #22c55e'
            }}>
              <span style={{ fontWeight: 'bold', color: '#15803d' }}>
                ✅ تقوم الآن بإنشاء محتوى عام - سيظهر لجميع المعلمين
              </span>
            </div>
          )}
          {selectedTeacherName && selectedTeacherId !== 'admin' && (
            <div style={{ 
              marginTop: '15px', 
              padding: '12px', 
              backgroundColor: '#eef2ff',
              borderRadius: '8px',
              borderRight: '4px solid #818cf8'
            }}>
              <span style={{ fontWeight: 'bold', color: '#4338ca' }}>
                ✅ تقوم الآن بإدارة محتوى المعلم: {selectedTeacherName}
              </span>
            </div>
          )}
          {!selectedTeacherId && (
            <div style={{ 
              marginTop: '15px', 
              padding: '12px', 
              backgroundColor: '#fef3c7',
              borderRadius: '8px',
              borderRight: '4px solid #f59e0b'
            }}>
              <span style={{ fontWeight: 'bold', color: '#92400e' }}>
                ℹ️ وضع العرض فقط - لإضافة محتوى، اختر "محتوى عام" أو معلم معين
              </span>
            </div>
          )}
        </div>
      )}
      
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold">إدارة المحتوى التعليمي</h1>
          <p className="text-gray-500">اربط الروابط التعليمية بالصفوف والمواد</p>
        </div>
        <button
          onClick={() => setShowForm(!showForm)}
          disabled={!teacherId && !selectedTeacherId}
          className={`px-6 py-2 rounded-xl font-bold ${
            !teacherId && !selectedTeacherId 
              ? 'bg-gray-400 text-gray-200 cursor-not-allowed' 
              : 'bg-purple-500 text-white hover:bg-purple-600'
          }`}
          title={!teacherId && !selectedTeacherId ? 'اختر معلماً أو محتوى عام لإضافة محتوى جديد' : ''}
        >
          {showForm ? 'إلغاء' : '➕ إضافة محتوى جديد'}
        </button>
      </div>

      {showForm && (
        <div className="bg-white p-8 rounded-[40px] shadow-lg border animate-fadeIn border-purple-100">
          <h2 className="text-xl font-black text-purple-800 mb-6">{editingLesson ? 'تعديل المحتوى' : 'إضافة محتوى جديد'}</h2>
          <form onSubmit={handleSubmit} className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-5 gap-4">
              {/* الصف - Grade */}
              <select value={formData.grade} onChange={e => {
                const newGrade = e.target.value;
                setFormData({...formData, grade: newGrade, atram: '', subject: '', term: '', unit: ''});
                
                // تحديث الأترام المتاحة بناءً على الصف المختار
                const hierarchicalConfigs = getFilteredHierarchicalConfigs();
                const gradeConfig = hierarchicalConfigs.find((c: any) => c.grade === newGrade);
                if (gradeConfig) {
                  setAvailableAtrams(gradeConfig.atrams.map((a: any) => a.atram));
                } else {
                  setAvailableAtrams([]);
                }
                setAvailableSubjects([]);
                setAvailableTerms([]);
                setAvailableUnits([]);
              }} className="p-3 border-2 rounded-2xl outline-none focus:border-purple-400 focus:ring-4 focus:ring-purple-100 bg-purple-50" required>
                <option value="">الصف</option>
                {options.grades.map((o,i) => <option key={i} value={o}>{o}</option>)}
              </select>

              {/* الترم - Atram */}
              <select value={formData.atram} onChange={e => {
                const newAtram = e.target.value;
                setFormData({...formData, atram: newAtram, subject: '', term: '', unit: ''});
                
                // تحديث المواد المتاحة بناءً على الترم المختار
                const hierarchicalConfigs = getFilteredHierarchicalConfigs();
                const gradeConfig = hierarchicalConfigs.find((c: any) => c.grade === formData.grade);
                if (gradeConfig) {
                  const atramConfig = gradeConfig.atrams.find((a: any) => a.atram === newAtram);
                  if (atramConfig) {
                    setAvailableSubjects(atramConfig.subjects.map((s: any) => s.subject));
                  } else {
                    setAvailableSubjects([]);
                  }
                }
                setAvailableTerms([]);
                setAvailableUnits([]);
              }} className="p-3 border-2 rounded-2xl outline-none focus:border-purple-400 focus:ring-4 focus:ring-purple-100 bg-purple-50" required disabled={!formData.grade}>
                <option value="">الترم</option>
                {availableAtrams.map((o,i) => <option key={i} value={o}>{o}</option>)}
              </select>

              {/* المادة - Subject */}
              <select value={formData.subject} onChange={e => {
                const newSubject = e.target.value;
                setFormData({...formData, subject: newSubject, term: '', unit: ''});
                
                // تحديث الفصول المتاحة بناءً على المادة المختارة
                const hierarchicalConfigs = getFilteredHierarchicalConfigs();
                const gradeConfig = hierarchicalConfigs.find((c: any) => c.grade === formData.grade);
                if (gradeConfig) {
                  const atramConfig = gradeConfig.atrams.find((a: any) => a.atram === formData.atram);
                  if (atramConfig) {
                    const subjectConfig = atramConfig.subjects.find((s: any) => s.subject === newSubject);
                    if (subjectConfig) {
                      setAvailableTerms(subjectConfig.terms.map((t: any) => t.term));
                    } else {
                      setAvailableTerms([]);
                    }
                  }
                }
                setAvailableUnits([]);
              }} className="p-3 border-2 rounded-2xl outline-none focus:border-purple-400 focus:ring-4 focus:ring-purple-100 bg-purple-50" required disabled={!formData.atram}>
                <option value="">المادة</option>
                {availableSubjects.map((o,i) => <option key={i} value={o}>{o}</option>)}
              </select>

              {/* الفصل - Term */}
              <select value={formData.term} onChange={e => {
                const newTerm = e.target.value;
                setFormData({...formData, term: newTerm, unit: ''});
                
                // تحديث الوحدات المتاحة بناءً على الفصل المختار
                const hierarchicalConfigs = getFilteredHierarchicalConfigs();
                const gradeConfig = hierarchicalConfigs.find((c: any) => c.grade === formData.grade);
                if (gradeConfig) {
                  const atramConfig = gradeConfig.atrams.find((a: any) => a.atram === formData.atram);
                  if (atramConfig) {
                    const subjectConfig = atramConfig.subjects.find((s: any) => s.subject === formData.subject);
                    if (subjectConfig) {
                      const termConfig = subjectConfig.terms.find((t: any) => t.term === newTerm);
                      if (termConfig) {
                        setAvailableUnits(termConfig.units);
                      } else {
                        setAvailableUnits([]);
                      }
                    }
                  }
                }
              }} className="p-3 border-2 rounded-2xl outline-none focus:border-purple-400 focus:ring-4 focus:ring-purple-100 bg-purple-50" required disabled={!formData.subject}>
                <option value="">الفصل</option>
                {availableTerms.map((o,i) => <option key={i} value={o}>{o}</option>)}
              </select>

              {/* الوحدة - Unit */}
              <select value={formData.unit} onChange={e => {
                const newUnit = e.target.value;
                setFormData({...formData, unit: newUnit});
              }} className="p-3 border-2 rounded-2xl outline-none focus:border-purple-400 focus:ring-4 focus:ring-purple-100 bg-purple-50" required disabled={!formData.term}>
                <option value="">الوحدة</option>
                {availableUnits.map((o,i) => <option key={i} value={o}>{o}</option>)}
              </select>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label className="block text-sm font-bold mb-1 text-purple-700">فيديو شرح الدرس</label>
                <div className="mb-2 flex gap-2 rounded-2xl bg-purple-50 p-2">
                  <button type="button" onClick={() => setFormData({ ...formData, explanationVideoType: 'embed', explanationVideoUrl: formData.explanationVideoType === 'mp4' && isMp4VideoUrl(formData.explanationVideoUrl) ? '' : formData.explanationVideoUrl, explanationVideoFile: null })} className={`flex-1 rounded-xl px-3 py-2 text-sm font-black ${formData.explanationVideoType === 'embed' ? 'bg-purple-500 text-white' : 'text-purple-700'}`}>🔗 رابط مضمن</button>
                  <button type="button" onClick={() => setFormData({ ...formData, explanationVideoType: 'mp4' })} className={`flex-1 rounded-xl px-3 py-2 text-sm font-black ${formData.explanationVideoType === 'mp4' ? 'bg-purple-500 text-white' : 'text-purple-700'}`}>📁 رفع MP4</button>
                </div>
                {formData.explanationVideoType === 'embed' ? (
                  <input type="url" value={formData.explanationVideoUrl} onChange={e => setFormData({...formData, explanationVideoUrl: e.target.value})} className="w-full p-4 border-2 rounded-2xl outline-none focus:border-purple-400 focus:ring-4 focus:ring-purple-100 bg-purple-50" placeholder="https://..." />
                ) : (
                  <label className="block cursor-pointer rounded-2xl border-2 border-dashed border-purple-300 bg-purple-50 p-4 text-center font-bold text-purple-700">
                    <span>{formData.explanationVideoFile?.name || (editingLesson?.explanationVideoUrl ? 'استبدال ملف MP4 (اختياري)' : 'اختر ملف MP4 بحد أقصى 500MB')}</span>
                    <input type="file" accept="video/mp4,.mp4" className="hidden" onChange={e => setFormData({ ...formData, explanationVideoFile: e.target.files?.[0] || null })} />
                  </label>
                )}
              </div>
              <div>
                <label className="block text-sm font-bold mb-1 text-purple-700">رابط الأفاتار التفاعلي</label>
                <input type="url" value={formData.avatarInteractionUrl} onChange={e => setFormData({...formData, avatarInteractionUrl: e.target.value})} className="w-full p-4 border-2 rounded-2xl outline-none focus:border-purple-400 focus:ring-4 focus:ring-purple-100 bg-purple-50" placeholder="https://..." />
              </div>
              <div>
                <label className="block text-sm font-bold mb-1 text-purple-700">رابط الاجتماع المباشر</label>
                <input type="url" value={formData.liveMeetingUrl} onChange={e => setFormData({...formData, liveMeetingUrl: e.target.value})} className="w-full p-4 border-2 rounded-2xl outline-none focus:border-purple-400 focus:ring-4 focus:ring-purple-100 bg-purple-50" placeholder="https://..." />
              </div>
            </div>

            <div>
              <label className="block text-sm font-bold mb-1 text-purple-800">نص الشرح الكامل (سياق المعلم الذكي)</label>
              <textarea
                value={formData.lessonContent}
                onChange={e => setFormData({...formData, lessonContent: e.target.value})}
                className="w-full p-5 border-2 rounded-3xl min-h-[180px] outline-none focus:border-purple-400 focus:ring-4 focus:ring-purple-100 bg-purple-50 font-medium"
                placeholder="أدخل النص الكامل للدرس هنا أو ارفع ملف نصي/بي دي إف. سيستخدمه النظام كمرجع للإجابة على أسئلة الطالب في قسم حل المسائل. هذا النص مخفي عن الطالب."
              />
              <input
                type="file"
                accept=".txt,application/pdf"
                className="mt-3"
                onChange={async (e) => {
                  const file = e.target.files?.[0];
                  if (!file) return;
                  if (file.type === 'text/plain') {
                    // قراءة ملف نصي
                    const text = await file.text();
                    setFormData(f => ({ ...f, lessonContent: text }));
                  } else if (file.type === 'application/pdf') {
                    // قراءة PDF (باستخدام pdfjs-dist)
                    try {
                      const pdfjsLib = await import('pdfjs-dist/build/pdf');
                      // @ts-ignore
                      pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/4.2.67/pdf.worker.min.js';
                      const arrayBuffer = await file.arrayBuffer();
                      const pdf = await pdfjsLib.getDocument({ data: arrayBuffer }).promise;
                      let text = '';
                      for (let i = 1; i <= pdf.numPages; i++) {
                        const page = await pdf.getPage(i);
                        const content = await page.getTextContent();
                        text += content.items.map((item: any) => item.str).join(' ') + '\n';
                      }
                      setFormData(f => ({ ...f, lessonContent: text }));
                    } catch (err) {
                      alert('تعذر قراءة ملف PDF. جرب رفع ملف نصي أو الصق النص يدوياً.');
                    }
                  } else {
                    alert('يرجى رفع ملف نصي (.txt) أو PDF فقط.');
                  }
                }}
              />
              <p className="text-xs text-orange-600 mt-2 font-bold flex items-center gap-1">
                <span>⚠️</span> يمكنك رفع ملف نصي أو PDF وسيتم استخراج النص تلقائياً.
              </p>
            </div>

            <button 
              type="submit" 
              className="w-full bg-purple-500 hover:bg-purple-600 text-white py-5 rounded-[24px] font-black text-xl shadow-xl shadow-purple-100 transition-all"
            >
              💾 حفظ ونشر المحتوى
            </button>
          </form>
        </div>
      )}

      <div className="bg-white rounded-[40px] border border-purple-100 overflow-hidden shadow-sm">
        <table className="w-full text-right">
          <thead className="bg-purple-50 border-b">
            <tr>
              <th className="px-6 py-5">الصف</th>
              <th className="px-6 py-5">المادة</th>
              <th className="px-6 py-5">الترم</th>
              <th className="px-6 py-5">الوحدة</th>
              {!teacherId && <th className="px-6 py-5">👨‍🏫 المنشئ</th>}
              <th className="px-6 py-5">الفيديو</th>
              <th className="px-6 py-5">الأفاتار</th>
              <th className="px-6 py-5">الاجتماع</th>
              <th className="px-6 py-5">الإجراءات</th>
            </tr>
          </thead>
          <tbody>
            {lessons.map(l => (
              <tr key={l.id} className="border-b hover:bg-purple-50/30 transition-colors">
                <td className="px-6 py-5 font-black text-purple-800">{l.grade}</td>
                <td className="px-6 py-5 font-bold text-purple-600">{l.subject}</td>
                <td className="px-6 py-5 font-black text-purple-700">{l.atram}</td>
                <td className="px-6 py-5 text-purple-500">{l.unit}</td>
                {!teacherId && (
                  <td className="px-6 py-5">
                    <span className="bg-gradient-to-r from-purple-500 to-purple-500 text-white px-4 py-2 rounded-xl text-sm font-black inline-flex items-center gap-2">
                      👨‍🏫 {l.createdByName || 'المشرف'}
                    </span>
                  </td>
                )}
                <td className="px-6 py-5">
                  {l.explanationVideoUrl ? <span className="bg-blue-100 text-blue-600 px-3 py-1 rounded-lg text-xs font-black">✅ موجود</span> : <span className="bg-purple-100 text-purple-400 px-3 py-1 rounded-lg text-xs font-black">❌ غير موجود</span>}
                </td>
                <td className="px-6 py-5">
                  {l.avatarInteractionUrl ? <span className="bg-emerald-100 text-emerald-600 px-3 py-1 rounded-lg text-xs font-black">✅ موجود</span> : <span className="bg-purple-100 text-purple-400 px-3 py-1 rounded-lg text-xs font-black">❌ غير موجود</span>}
                </td>
                <td className="px-6 py-5">
                  {l.liveMeetingUrl ? <span className="bg-purple-100 text-purple-600 px-3 py-1 rounded-lg text-xs font-black">✅ موجود</span> : <span className="bg-purple-100 text-purple-400 px-3 py-1 rounded-lg text-xs font-black">❌ غير موجود</span>}
                </td>
                <td className="px-6 py-5 space-x-2 space-x-reverse">
                  <button onClick={() => handleEdit(l)} className="text-purple-500 font-bold hover:underline">تعديل</button>
                  <button onClick={() => handleDelete(l.id)} className="text-red-500 font-bold hover:underline">حذف</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {lessons.length === 0 && <div className="p-32 text-center text-purple-400 font-bold">لا يوجد محتوى تعليمي مضاف حالياً</div>}
      </div>
    </div>
  );
};

export default ContentManagement;
