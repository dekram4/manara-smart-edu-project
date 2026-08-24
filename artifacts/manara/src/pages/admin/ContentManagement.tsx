
import React, { useState, useEffect } from 'react';
import { LessonConfig } from '../../types';
import { STORAGE_KEYS } from '../../constants';
import { getRecordTeacherId, normalizeScopeValue } from '../../utils/scope';
import { getTeacherPermissions, isLimitReached } from '../../permissions';
import {
  deleteUploadedVideo,
  getLessonExplanationVideos,
  isMp4VideoUrl,
  showVideoStorageNotice,
  uploadMp4Video,
  VideoSourceType,
  LessonVideoEntry,
} from '../../utils/video';

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
    explanationVideos: [] as LessonVideoEntry[],
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

  const addExplanationVideo = async () => {
    if (formData.explanationVideoType === 'embed') {
      const url = formData.explanationVideoUrl.trim();
      if (!url) {
        alert('يرجى إدخال الرابط المضمن أولاً');
        return;
      }
      setFormData(current => ({
        ...current,
        explanationVideos: [
          ...current.explanationVideos,
          {
            id: `lesson-video-${crypto.randomUUID()}`,
            url,
            sourceType: 'embed',
            title: `فيديو الشرح ${current.explanationVideos.length + 1}`,
            createdAt: new Date().toISOString(),
          },
        ],
        explanationVideoUrl: '',
      }));
      return;
    }

    if (!formData.explanationVideoFile) {
      alert('يرجى اختيار ملف MP4 أولاً');
      return;
    }

    try {
      const file = formData.explanationVideoFile;
      const uploaded = await uploadMp4Video(file);
      showVideoStorageNotice(uploaded);
      setFormData(current => ({
        ...current,
        explanationVideos: [
          ...current.explanationVideos,
          {
            id: `lesson-video-${crypto.randomUUID()}`,
            url: uploaded.url,
            sourceType: 'mp4',
            title: file.name,
            createdAt: new Date().toISOString(),
          },
        ],
        explanationVideoFile: null,
      }));
    } catch (error) {
      alert(`⚠️ ${error instanceof Error ? error.message : 'فشل رفع ملف الفيديو'}`);
    }
  };

  const removeExplanationVideo = (video: LessonVideoEntry) => {
    setFormData(current => ({
      ...current,
      explanationVideos: current.explanationVideos.filter(item => item.id !== video.id),
    }));
    // لا نحذف ملفًا محفوظًا قبل الضغط على «حفظ»؛ حتى يبقى الإلغاء آمنًا.
    const persistedVideo = editingLesson
      ? getLessonExplanationVideos(editingLesson).some(item => item.url === video.url)
      : false;
    if (video.sourceType === 'mp4' && !persistedVideo) {
      void deleteUploadedVideo(video.url);
    }
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

    const ownerId = editingLesson?.createdBy ||
      teacherId ||
      (selectedTeacherId === 'admin' ? 'admin' : selectedTeacherId) ||
      'admin';
    const ownerName = editingLesson?.createdByName ||
      teacherName ||
      (selectedTeacherId === 'admin' ? 'المشرف - محتوى عام' : selectedTeacherName) ||
      'المشرف';

    const allLessons: LessonConfig[] = JSON.parse(
      localStorage.getItem(STORAGE_KEYS.LESSON_CONFIGS) || '[]',
    );
    const scopeMatches = (lesson: LessonConfig) =>
      ['grade', 'atram', 'subject', 'term', 'unit'].every(field =>
        normalizeScopeValue(lesson[field as keyof LessonConfig])
        === normalizeScopeValue(formData[field as keyof typeof formData] as string),
      );
    const matchingLesson = !editingLesson
      ? allLessons.find(lesson =>
        (getRecordTeacherId(lesson) || 'admin') === normalizeScopeValue(ownerId)
        && scopeMatches(lesson),
      )
      : null;

    if (teacherId && !editingLesson && !matchingLesson) {
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

    let currentVideos = [...formData.explanationVideos];
    if (formData.explanationVideoType === 'embed' && formData.explanationVideoUrl.trim()) {
      currentVideos = [
        ...currentVideos,
        {
          id: `lesson-video-${crypto.randomUUID()}`,
          url: formData.explanationVideoUrl.trim(),
          sourceType: 'embed',
          title: `فيديو الشرح ${currentVideos.length + 1}`,
          createdAt: new Date().toISOString(),
        },
      ];
    } else if (formData.explanationVideoType === 'mp4' && formData.explanationVideoFile) {
      try {
        const file = formData.explanationVideoFile;
        const uploaded = await uploadMp4Video(file);
        showVideoStorageNotice(uploaded);
        currentVideos = [
          ...currentVideos,
          {
            id: `lesson-video-${crypto.randomUUID()}`,
            url: uploaded.url,
            sourceType: 'mp4',
            title: file.name,
            createdAt: new Date().toISOString(),
          },
        ];
      } catch (error) {
        alert(`⚠️ ${error instanceof Error ? error.message : 'فشل رفع ملف الفيديو'}`);
        return;
      }
    }

    const previousVideos = editingLesson
      ? getLessonExplanationVideos(editingLesson)
      : matchingLesson
        ? getLessonExplanationVideos(matchingLesson)
        : [];
    const videosToSave = editingLesson
      ? currentVideos
      : [...previousVideos, ...currentVideos];
    const nextVideos = videosToSave.filter((video, index, all) =>
      all.findIndex(item => item.url === video.url) === index,
    );
    // The latest selected/uploaded video is the legacy single-video fallback.
    // The structured explanationVideos list remains the source of truth.
    const primaryVideo = nextVideos.at(-1);
    const preservedLesson = matchingLesson || editingLesson;
    const lesson: LessonConfig = {
      id: editingLesson?.id || matchingLesson?.id || Date.now().toString(),
      grade: formData.grade.trim(),
      subject: formData.subject.trim(),
      atram: formData.atram.trim(),
      term: formData.term.trim(),
      unit: formData.unit.trim(),
      explanationVideoUrl: primaryVideo?.url || '',
      explanationVideoType: primaryVideo?.sourceType || 'embed',
      explanationVideos: nextVideos,
      avatarInteractionUrl: formData.avatarInteractionUrl.trim() || preservedLesson?.avatarInteractionUrl || '',
      liveMeetingUrl: formData.liveMeetingUrl.trim() || preservedLesson?.liveMeetingUrl || '',
      lessonContent: formData.lessonContent.trim() || preservedLesson?.lessonContent || '',
      createdAt: preservedLesson?.createdAt || new Date().toISOString(),
      createdBy: ownerId,
      createdByName: ownerName
    };

    let updated: LessonConfig[];
    if (editingLesson) {
      updated = allLessons.map(l => l.id === editingLesson.id ? lesson : l);
    } else if (matchingLesson) {
      updated = allLessons.map(l => l.id === matchingLesson.id ? lesson : l);
    } else {
      updated = [...allLessons, lesson];
    }

    localStorage.setItem(STORAGE_KEYS.LESSON_CONFIGS, JSON.stringify(updated));
    const removedVideos = previousVideos.filter(video =>
      !nextVideos.some(next => next.url === video.url),
    );
    removedVideos.forEach(video => {
      if (isMp4VideoUrl(video.url)) void deleteUploadedVideo(video.url);
    });
    
    setShowForm(false);
    setEditingLesson(null);
    setFormData({ grade: '', atram: '', subject: '', term: '', unit: '', explanationVideoUrl: '', explanationVideoType: 'embed', explanationVideoFile: null, explanationVideos: [], avatarInteractionUrl: '', liveMeetingUrl: '', lessonContent: '' });
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
      explanationVideoUrl: '',
      explanationVideoType: 'embed',
      explanationVideoFile: null,
      explanationVideos: getLessonExplanationVideos(lesson),
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
      const deletedLesson = allLessons.find(lesson => lesson.id === id);
      const deletedIds = JSON.parse(
        localStorage.getItem(STORAGE_KEYS.DELETED_LESSONS) || '[]',
      );
      const nextDeletedIds = Array.from(
        new Set([
          ...deletedIds
            .filter((value: unknown) => value != null)
            .map(String),
          String(id),
        ]),
      );
      // احفظ علامة الحذف قبل إزالة السجل حتى لا تعيده hydrate من Supabase.
      localStorage.setItem(
        STORAGE_KEYS.DELETED_LESSONS,
        JSON.stringify(nextDeletedIds),
      );
      const updated = allLessons.filter(l => l.id !== id);
      localStorage.setItem(STORAGE_KEYS.LESSON_CONFIGS, JSON.stringify(updated));
      if (deletedLesson) {
        getLessonExplanationVideos(deletedLesson)
          .filter(video => isMp4VideoUrl(video.url))
          .forEach(video => void deleteUploadedVideo(video.url));
      }
      loadData();
      onUpdate();
    }
  };

  return (
    <div className="dashboard-page dashboard-consistent-page dashboard-content-management animate-fadeIn">
      {/* للمشرف فقط: اختيار المعلم */}
      {!teacherId && (
        <div className="dashboard-surface dashboard-content-scope">
          <div className="dashboard-content-scope-header">
            <span className="dashboard-content-scope-icon">📚</span>
            <div>
              <h3>
                اختر المعلم لإدارة المحتوى
              </h3>
              <p>
                كل معلم له محتوى تعليمي مستقل مرتبط بإعداداته الأكاديمية
              </p>
            </div>
          </div>
          
          <select className="dashboard-form-control dashboard-content-select"
            value={selectedTeacherId} 
            onChange={handleTeacherChange}
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
            <div className="dashboard-notice dashboard-content-notice dashboard-content-notice-success">
              <span>
                ✅ تقوم الآن بإنشاء محتوى عام - سيظهر لجميع المعلمين
              </span>
            </div>
          )}
          {selectedTeacherName && selectedTeacherId !== 'admin' && (
            <div className="dashboard-notice dashboard-content-notice dashboard-content-notice-info">
              <span>
                ✅ تقوم الآن بإدارة محتوى المعلم: {selectedTeacherName}
              </span>
            </div>
          )}
          {!selectedTeacherId && (
            <div className="dashboard-notice dashboard-content-notice dashboard-content-notice-warning">
              <span>
                ℹ️ وضع العرض فقط - لإضافة محتوى، اختر "محتوى عام" أو معلم معين
              </span>
            </div>
          )}
        </div>
      )}
      
      <div className="dashboard-section-header dashboard-content-header">
        <div>
          <span className="dashboard-content-eyebrow">المكتبة التعليمية</span>
          <h1>إدارة المحتوى التعليمي</h1>
          <p>اربط الروابط التعليمية بالصفوف والمواد والوحدات من مكان واحد.</p>
        </div>
        <button
          onClick={() => setShowForm(!showForm)}
          disabled={!teacherId && !selectedTeacherId}
          className={`dashboard-content-primary-action ${
            !teacherId && !selectedTeacherId 
              ? 'is-disabled'
              : ''
          }`}
          title={!teacherId && !selectedTeacherId ? 'اختر معلماً أو محتوى عام لإضافة محتوى جديد' : ''}
        >
          {showForm ? 'إلغاء' : '➕ إضافة محتوى جديد'}
        </button>
      </div>

      {showForm && (
         <div className="dashboard-surface dashboard-content-form-surface animate-fadeIn">
           <div className="dashboard-content-form-heading">
             <div>
               <span>الخطوة 01</span>
               <h2>{editingLesson ? 'تعديل المحتوى' : 'إضافة محتوى جديد'}</h2>
             </div>
             <p>حدد المسار الأكاديمي ثم أضف مصادر الدرس وشرح المعلم.</p>
           </div>
           <form onSubmit={handleSubmit} className="dashboard-content-form">
             <div className="dashboard-content-form-section">
               <div className="dashboard-content-form-section-heading">
                 <span>01</span>
                 <div>
                   <h3>المسار الأكاديمي</h3>
                   <p>اختر المكان الذي سيظهر فيه المحتوى للطلاب.</p>
                 </div>
               </div>
             <div className="dashboard-filter-grid dashboard-filter-grid-wide dashboard-content-academic-grid">
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
               }} className="dashboard-content-control" required>
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
               }} className="dashboard-content-control" required disabled={!formData.grade}>
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
               }} className="dashboard-content-control" required disabled={!formData.atram}>
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
               }} className="dashboard-content-control" required disabled={!formData.subject}>
                <option value="">الفصل</option>
                {availableTerms.map((o,i) => <option key={i} value={o}>{o}</option>)}
              </select>

              {/* الوحدة - Unit */}
              <select value={formData.unit} onChange={e => {
                const newUnit = e.target.value;
                setFormData({...formData, unit: newUnit});
               }} className="dashboard-content-control" required disabled={!formData.term}>
                <option value="">الوحدة</option>
                {availableUnits.map((o,i) => <option key={i} value={o}>{o}</option>)}
              </select>
             </div>
             </div>

             <div className="dashboard-content-form-section">
               <div className="dashboard-content-form-section-heading">
                 <span>02</span>
                 <div>
                   <h3>مصادر الدرس</h3>
                   <p>أضف الفيديو أو الروابط التي يحتاجها الطالب.</p>
                 </div>
               </div>
             <div className="dashboard-content-resource-grid">
               <div className="dashboard-content-resource-card dashboard-content-video-card">
                 <label>فيديو شرح الدرس</label>
                 <div className="dashboard-content-toggle">
                  <button type="button" onClick={() => setFormData({ ...formData, explanationVideoType: 'embed', explanationVideoUrl: formData.explanationVideoType === 'mp4' && isMp4VideoUrl(formData.explanationVideoUrl) ? '' : formData.explanationVideoUrl, explanationVideoFile: null })} className={`flex-1 rounded-xl px-3 py-2 text-sm font-black ${formData.explanationVideoType === 'embed' ? 'bg-purple-500 text-white' : 'text-purple-700'}`}>🔗 رابط مضمن</button>
                  <button type="button" onClick={() => setFormData({ ...formData, explanationVideoType: 'mp4' })} className={`flex-1 rounded-xl px-3 py-2 text-sm font-black ${formData.explanationVideoType === 'mp4' ? 'bg-purple-500 text-white' : 'text-purple-700'}`}>📁 رفع MP4</button>
                </div>
                {formData.explanationVideoType === 'embed' ? (
                   <input type="url" value={formData.explanationVideoUrl} onChange={e => setFormData({...formData, explanationVideoUrl: e.target.value})} className="dashboard-content-control" placeholder="https://..." />
                ) : (
                   <label className="dashboard-content-upload">
                    <span>{formData.explanationVideoFile?.name || (editingLesson?.explanationVideoUrl ? 'استبدال ملف MP4 (اختياري)' : 'اختر ملف MP4 بحد أقصى 500MB')}</span>
                    <input type="file" accept="video/mp4,.mp4" className="hidden" onChange={e => setFormData({ ...formData, explanationVideoFile: e.target.files?.[0] || null })} />
                  </label>
                )}
                <button
                  type="button"
                  onClick={addExplanationVideo}
                   className="dashboard-content-secondary-action"
                >
                  ➕ إضافة هذا الفيديو إلى شرح الدرس
                </button>
                {formData.explanationVideos.length > 0 && (
                   <div className="dashboard-content-video-list">
                     <p>
                      🎬 فيديوهات هذا الدرس ({formData.explanationVideos.length})
                    </p>
                    {formData.explanationVideos.map((video, index) => (
                       <div key={video.id} className="dashboard-content-video-row">
                         <span>
                          {index + 1}. {video.title || video.url}
                        </span>
                         <span className="dashboard-content-video-type">
                          {video.sourceType === 'mp4' ? 'MP4' : 'رابط'}
                        </span>
                         <button
                          type="button"
                          onClick={() => removeExplanationVideo(video)}
                           className="dashboard-content-video-remove"
                        >
                          حذف
                        </button>
                      </div>
                    ))}
                  </div>
                )}
              </div>
               <div className="dashboard-content-resource-card">
                 <label>رابط الأفاتار التفاعلي</label>
                 <input type="url" value={formData.avatarInteractionUrl} onChange={e => setFormData({...formData, avatarInteractionUrl: e.target.value})} className="dashboard-content-control" placeholder="https://..." />
              </div>
               <div className="dashboard-content-resource-card">
                 <label>رابط الاجتماع المباشر</label>
                 <input type="url" value={formData.liveMeetingUrl} onChange={e => setFormData({...formData, liveMeetingUrl: e.target.value})} className="dashboard-content-control" placeholder="https://..." />
              </div>
            </div>
             </div>

             <div className="dashboard-content-form-section">
               <div className="dashboard-content-form-section-heading">
                 <span>03</span>
                 <div>
                   <h3>المادة التعليمية</h3>
                   <p>هذا النص يستخدمه المساعد الذكي لمساعدة الطالب.</p>
                 </div>
               </div>
               <label className="dashboard-content-textarea-label">نص الشرح الكامل (سياق المعلم الذكي)</label>
              <textarea
                value={formData.lessonContent}
                onChange={e => setFormData({...formData, lessonContent: e.target.value})}
                 className="dashboard-content-textarea"
                placeholder="أدخل النص الكامل للدرس هنا أو ارفع ملف نصي/بي دي إف. سيستخدمه النظام كمرجع للإجابة على أسئلة الطالب في قسم حل المسائل. هذا النص مخفي عن الطالب."
              />
              <input
                type="file"
                accept=".txt,application/pdf"
                 className="dashboard-content-file-input"
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
               <p className="dashboard-content-hint">
                <span>⚠️</span> يمكنك رفع ملف نصي أو PDF وسيتم استخراج النص تلقائياً.
              </p>
            </div>

            <button 
              type="submit" 
               className="dashboard-content-submit"
            >
              💾 حفظ ونشر المحتوى
            </button>
          </form>
        </div>
      )}

      <div className="dashboard-table-surface dashboard-content-records dashboard-content-table-surface">
        <div className="dashboard-content-table-heading">
          <div>
            <span>المحتوى المنشور</span>
            <h2>دروس المنصة</h2>
          </div>
          <strong>{lessons.length} محتوى</strong>
        </div>
        <table className="dashboard-content-table text-right">
          <thead className="dashboard-content-table-head">
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
              <tr key={l.id}>
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
                   <button onClick={() => handleEdit(l)} className="dashboard-content-table-edit">تعديل</button>
                   <button onClick={() => handleDelete(l.id)} className="dashboard-content-table-delete">حذف</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {lessons.length === 0 && <div className="dashboard-content-empty">لا يوجد محتوى تعليمي مضاف حالياً</div>}
      </div>
    </div>
  );
};

export default ContentManagement;
