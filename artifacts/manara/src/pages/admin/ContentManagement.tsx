
import React, { useState, useEffect } from 'react';
import { readHierarchicalConfigs } from '../../utils/academic';
import { useSyncHydrating } from '../../hooks/useSyncHydrating';
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
  /// هل ما زالت الشجرة الأكاديمية في طريقها من الخادم؟
  const hydrating = useSyncHydrating();

  // 🔎 فلاتر قائمة المحتوى المنشور
  const [listSearch, setListSearch] = useState('');
  const [listSubject, setListSubject] = useState('all');
  const [listGrade, setListGrade] = useState('all');
  const [listKind, setListKind] = useState<'all' | 'video' | 'avatar' | 'meeting' | 'text'>('all');
  const [listPublish, setListPublish] = useState<'all' | 'published' | 'empty'>('all');
  const [showForm, setShowForm] = useState(false);
  const [editingLesson, setEditingLesson] = useState<LessonConfig | null>(null);
  
  // للمشرف: اختيار المعلم
  const [teachers, setTeachers] = useState<any[]>([]);
  const [selectedTeacherId, setSelectedTeacherId] = useState<string>(teacherId || '');
  const [selectedTeacherName, setSelectedTeacherName] = useState<string>(teacherName || '');
  
  const [formData, setFormData] = useState({
    grade: '', subject: '', term: '', unit: '', lesson: '',
    explanationVideoUrl: '', explanationVideoType: 'embed' as VideoSourceType, explanationVideoFile: null as File | null,
    explanationVideos: [] as LessonVideoEntry[],
    avatarInteractionUrl: '', liveMeetingUrl: '', lessonContent: ''
  });

  const [options, setOptions] = useState<{ grades: string[] }>({ grades: [] });
  const [availableSubjects, setAvailableSubjects] = useState<string[]>([]);
  const [availableTerms, setAvailableTerms] = useState<string[]>([]);
  const [availableUnits, setAvailableUnits] = useState<string[]>([]);
  /// أسماء الدروس المعرّفة للوحدة المختارة في الإعدادات الأكاديمية.
  const [availableLessons, setAvailableLessons] = useState<string[]>([]);

  /// يقرأ دروس وحدة من الشجرة الهرمية. خريطة `term.lessons` اختيارية،
  /// فالوحدات التي لم تُعرَّف لها دروس تعيد قائمة فارغة.
  ///
  /// المسار يُمرَّر صراحةً عند الحاجة لأن `setFormData` غير متزامن: عند فتح
  /// محتوى للتعديل تكون `formData` ما زالت تحمل المسار السابق، فالقراءة منها
  /// تعطي دروس وحدة أخرى.
  const getLessonsFor = (
    unit: string,
    path?: { grade: string; subject: string; term: string },
  ): string[] => {
    if (!unit) return [];
    const scope = path ?? formData;
    const configs = getFilteredHierarchicalConfigs();
    const grade = configs.find((c: any) => c.grade === scope.grade);
    const subject = grade?.subjects?.find((s: any) => s.subject === scope.subject);
    const term = subject?.terms?.find((t: any) => t.term === scope.term);
    const lessons = term?.lessons?.[unit];
    return Array.isArray(lessons) ? lessons : [];
  };

  /// يضمّ القيمة المحفوظة إلى الخيارات إن غابت عن الشجرة.
  ///
  /// محتوى نُشر قبل أن يصبح الدرس إلزامياً قد يحمل اسماً حُذف من الإعدادات
  /// لاحقاً؛ بدون هذا يفتح النموذج على قائمة فارغة فيبدو أن الدرس ضاع، وأي
  /// حفظ يمحوه فعلاً.
  const withCurrentValue = (options: string[], current: string): string[] =>
    current && !options.includes(current) ? [current, ...options] : options;

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
    // مدموجة عند القراءة: المصفوفة الخام قد تحمل أكثر من مدخل لنفس الصف،
    // و`.find()` أدناه تقع على أوّلها — فإن كانت الدروس على الثاني عادت
    // القائمة فارغة حتى تُزار شاشة الإعدادات التي تدمج وتعيد الكتابة.
    const allHierarchicalConfigs: any[] = readHierarchicalConfigs(STORAGE_KEYS.HIERARCHICAL_CONFIGS);
    
    // فلترة الإعدادات الأكاديمية حسب المعلم
    const effectiveTeacherId = teacherId || selectedTeacherId;
    let hierarchicalConfigs: any[] = [];
    
    if (effectiveTeacherId && effectiveTeacherId !== 'admin') {
      // للمعلم: إظهار إعداداته + الإعدادات العامة (ولكن تفضيل نسخته على النسخة العامة)
      if (teacherId) {
        const teacherConfigs = allHierarchicalConfigs.filter((c: any) => getRecordTeacherId(c) === normalizeScopeValue(effectiveTeacherId));
        const adminConfigs = allHierarchicalConfigs.filter((c: any) =>
          getRecordTeacherId(c) === 'admin' || !c.createdBy
        );
        
        // دمج: إذا كان للمعلم نسخة من إعداد عام، نستخدم نسخة المعلم
        const mergedConfigs = [...teacherConfigs];
        adminConfigs.forEach((adminConfig: any) => {
          const hasTeacherVersion = teacherConfigs.some((tc: any) => tc.grade === adminConfig.grade);
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

  /// معرّف جديد لا يحمله سجلّ قائم.
  ///
  /// `Date.now()` وحده يتكرّر حين يُحفظ سجلّان في الملّي ثانية نفسها —
  /// وارد عند الحفظ المتتابع أو استيراد دفعة — والمعرّف مفتاح الصفّ في
  /// Supabase، فتصادمه يكتب أحدهما فوق الآخر بلا أثر يُرى.
  const freshLessonId = (existing: LessonConfig[]): string => {
    const taken = new Set(existing.map(item => String(item.id)));
    let candidate = Date.now().toString();
    while (taken.has(candidate)) {
      candidate = `${candidate}-${Math.random().toString(36).slice(2, 7)}`;
    }
    return candidate;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (teacherId && !getTeacherPermissions({ permissionPackageId }).canManageContent) {
      alert('⚠️ ليس لديك صلاحية إدارة المحتوى التعليمي');
      return;
    }
    
    if (!formData.grade || !formData.subject || !formData.term || !formData.unit) {
      alert('يرجى اختيار جميع التصنيفات الأكاديمية');
      return;
    }

    // الدرس مستوى إلزامي كبقية الخمسة: محتوى بلا درس يصل الطالب على مستوى
    // الوحدة فيختلط بدروس أخرى، وهو بالضبط ما يمنعه هذا الشرط.
    if (!formData.lesson.trim()) {
      alert('يرجى اختيار الدرس التابع للوحدة');
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
    // ‏المسار الذي يُعرّف المحتوى: خمسة مستويات، آخرها الدرس.
    //
    // ‏كان يقف عند الوحدة. فالدرس الثاني في الوحدة نفسها كان يجد سجلّ
    // ‏الأول «مطابقاً» فيحلّ محلّه — يُضاف درسٌ فيُمحى آخر، ويبقى الجدول
    // ‏يعرض محتوًى واحداً مهما أُضيف. المستوى الخامس أُضيف إلى النموذج
    // ‏لاحقاً ولم يُضَف إلى هذه المقارنة معه.
    const scopeMatches = (lesson: LessonConfig) =>
      ['grade', 'subject', 'term', 'unit', 'lesson'].every(field =>
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
      id: editingLesson?.id || matchingLesson?.id || freshLessonId(allLessons),
      grade: formData.grade.trim(),
      subject: formData.subject.trim(),
      term: formData.term.trim(),
      unit: formData.unit.trim(),
      lesson: formData.lesson.trim(),
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
    setFormData({ grade: '', subject: '', term: '', unit: '', lesson: '', explanationVideoUrl: '', explanationVideoType: 'embed', explanationVideoFile: null, explanationVideos: [], avatarInteractionUrl: '', liveMeetingUrl: '', lessonContent: '' });
    loadData();
    onUpdate();
  };

  /// نوع المحتوى ليس حقلاً مخزّناً بل صفة مشتقّة مما عُبّئ فعلاً في السجل،
  /// فالفلتر يسأل «ما الذي فيه» لا «كيف صُنّف».
  const hasVideo = (l: LessonConfig) =>
    Boolean(l.explanationVideoUrl) || getLessonExplanationVideos(l).length > 0;
  const isPublished = (l: LessonConfig) =>
    hasVideo(l) || Boolean(l.avatarInteractionUrl) || Boolean(l.liveMeetingUrl) || Boolean(l.lessonContent);

  const listFilterOptions = {
    subjects: Array.from(new Set(lessons.map(l => l.subject).filter(Boolean))),
    grades: Array.from(new Set(lessons.map(l => l.grade).filter(Boolean))),
  };

  const visibleLessons = lessons.filter(l => {
    const needle = listSearch.trim().toLowerCase();
    if (needle) {
      const haystack = [l.grade, l.subject, l.term, l.unit, l.lesson, l.createdByName]
        .filter(Boolean).join(' ').toLowerCase();
      if (!haystack.includes(needle)) return false;
    }
    if (listSubject !== 'all' && l.subject !== listSubject) return false;
    if (listGrade !== 'all' && l.grade !== listGrade) return false;
    if (listKind === 'video' && !hasVideo(l)) return false;
    if (listKind === 'avatar' && !l.avatarInteractionUrl) return false;
    if (listKind === 'meeting' && !l.liveMeetingUrl) return false;
    if (listKind === 'text' && !l.lessonContent) return false;
    if (listPublish === 'published' && !isPublished(l)) return false;
    if (listPublish === 'empty' && isPublished(l)) return false;
    return true;
  });

  const listFiltersActive = Boolean(listSearch.trim()) || listSubject !== 'all'
    || listGrade !== 'all' || listKind !== 'all' || listPublish !== 'all';

  const handleEdit = (lesson: LessonConfig) => {
    setEditingLesson(lesson);
    setFormData({
      grade: lesson.grade,
      subject: lesson.subject,
      term: lesson.term,
      unit: lesson.unit,
      lesson: lesson.lesson || '',
      explanationVideoUrl: '',
      explanationVideoType: 'embed',
      explanationVideoFile: null,
      explanationVideos: getLessonExplanationVideos(lesson),
      avatarInteractionUrl: lesson.avatarInteractionUrl || '',
      liveMeetingUrl: lesson.liveMeetingUrl || '',
      lessonContent: lesson.lessonContent
    });
    
    // تحميل القوائم المترابطة بناءً على البيانات الموجودة - البنية: Grade → Subject → Term → Unit
    const hierarchicalConfigs = getFilteredHierarchicalConfigs();
    const gradeConfig = hierarchicalConfigs.find((c: any) => c.grade === lesson.grade);
    if (gradeConfig) {
      
        setAvailableSubjects(gradeConfig.subjects.map((s: any) => s.subject));
        
        const subjectConfig = gradeConfig.subjects.find((s: any) => s.subject === lesson.subject);
        if (subjectConfig) {
          setAvailableTerms(subjectConfig.terms.map((t: any) => t.term));
          
          const termConfig = subjectConfig.terms.find((t: any) => t.term === lesson.term);
          if (termConfig) {
            setAvailableUnits(termConfig.units);
            setAvailableLessons(
              withCurrentValue(
                getLessonsFor(lesson.unit, {
                  grade: lesson.grade,
                  subject: lesson.subject,
                  term: lesson.term,
                }),
                lesson.lesson || '',
              ),
            );
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
                setFormData({...formData, grade: newGrade, subject: '', term: '', unit: '', lesson: ''});

                // تحديث المواد المتاحة بناءً على الصف المختار
                const hierarchicalConfigs = getFilteredHierarchicalConfigs();
                const gradeConfig = hierarchicalConfigs.find((c: any) => c.grade === newGrade);
                setAvailableSubjects(
                  gradeConfig ? gradeConfig.subjects.map((s: any) => s.subject) : [],
                );
                setAvailableTerms([]);
                setAvailableUnits([]);
               }} className="dashboard-content-control" required>
                <option value="">الصف</option>
                {options.grades.map((o,i) => <option key={i} value={o}>{o}</option>)}
              </select>


              {/* المادة - Subject */}
              <select value={formData.subject} onChange={e => {
                const newSubject = e.target.value;
                setFormData({...formData, subject: newSubject, term: '', unit: '', lesson: ''});
                
                // تحديث الفصول المتاحة بناءً على المادة المختارة
                const hierarchicalConfigs = getFilteredHierarchicalConfigs();
                const gradeConfig = hierarchicalConfigs.find((c: any) => c.grade === formData.grade);
                if (gradeConfig) {
                    const subjectConfig = gradeConfig.subjects.find((s: any) => s.subject === newSubject);
                    if (subjectConfig) {
                      setAvailableTerms(subjectConfig.terms.map((t: any) => t.term));
                    } else {
                      setAvailableTerms([]);
                    }
                  }
                setAvailableUnits([]);
               }} className="dashboard-content-control" required disabled={!formData.grade}>
                <option value="">المادة</option>
                {availableSubjects.map((o,i) => <option key={i} value={o}>{o}</option>)}
              </select>

              {/* الفصل - Term */}
              <select value={formData.term} onChange={e => {
                const newTerm = e.target.value;
                setFormData({...formData, term: newTerm, unit: '', lesson: ''});
                
                // تحديث الوحدات المتاحة بناءً على الفصل المختار
                const hierarchicalConfigs = getFilteredHierarchicalConfigs();
                const gradeConfig = hierarchicalConfigs.find((c: any) => c.grade === formData.grade);
                if (gradeConfig) {
                    const subjectConfig = gradeConfig.subjects.find((s: any) => s.subject === formData.subject);
                    if (subjectConfig) {
                      const termConfig = subjectConfig.terms.find((t: any) => t.term === newTerm);
                      if (termConfig) {
                        setAvailableUnits(termConfig.units);
                      } else {
                        setAvailableUnits([]);
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
                setFormData({...formData, unit: newUnit, lesson: ''});
                setAvailableLessons(getLessonsFor(newUnit));
               }} className="dashboard-content-control" required disabled={!formData.term}>
                <option value="">الوحدة</option>
                {availableUnits.map((o,i) => <option key={i} value={o}>{o}</option>)}
              </select>

              {/* الدرس - Lesson.
                  يكمل التسلسل الخماسي: الصف ← المادة ← الفصل الدراسي ←
                  الوحدة ← الدرس. قبل هذا الحقل كانت الوحدة تحمل درساً
                  واحداً فقط، فلا يمكن وضع درسين في وحدة واحدة إطلاقاً.

                  قائمة مغلقة كبقية المستويات الأربعة ومصدرها الوحيد شجرة
                  الإعدادات الأكاديمية: اسم مكتوب بحرية لا يطابق ما في
                  الشجرة يُنتج درساً لا يظهر للطالب في شاشة المسار، وهو
                  عطل صامت. من لم يعرّف دروساً بعد يراه فارغاً مع تنبيه
                  يدله على مكان الإضافة. */}
              <select
                value={formData.lesson}
                onChange={e => {
                  // مسح رسالة الخطأ المخصّصة، وإلا بقي الحقل غير صالح في
                  // نظر المتصفح حتى بعد اختيار درس صحيح.
                  e.currentTarget.setCustomValidity('');
                  setFormData({ ...formData, lesson: e.target.value });
                }}
                // تحقّق المتصفح يسبق `handleSubmit` فلا تظهر رسالتنا أبداً؛
                // رسالته العامة «يُرجى اختيار عنصر من القائمة» لا تقول أي
                // حقل ولا لماذا. هذه تستبدلها بالنص المطلوب حرفياً.
                onInvalid={e => e.currentTarget.setCustomValidity('يرجى اختيار الدرس التابع للوحدة')}
                className="dashboard-content-control"
                required
                disabled={!formData.unit}
              >
                <option value="">{hydrating && availableLessons.length === 0 ? '⏳ جارٍ تحميل الدروس…' : 'الدرس'}</option>
                {availableLessons.map((o, i) => <option key={i} value={o}>{o}</option>)}
              </select>
             </div>
             {formData.unit && availableLessons.length === 0 && !hydrating && (
               <p className="dashboard-content-hint dashboard-content-hint-warning">
                 ⚠️ لا توجد دروس معرّفة في هذه الوحدة. أضفها أولاً من «الإعدادات
                 الأكاديمية ← الخطوة 6: اختر وحدة وأضف درساً»، ثم عد إلى هنا.
               </p>
             )}
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

      {/* 🔎 شريط فلاتر المحتوى */}
      {lessons.length > 0 && (
        <div className="dashboard-filter-surface" style={{ marginBottom: '1.5rem' }}>
          <div className="dashboard-filter-grid dashboard-filter-grid-wide">
            <input
              type="search"
              value={listSearch}
              onChange={e => setListSearch(e.target.value)}
              placeholder="🔎 ابحث في المسار الأكاديمي"
              className="dashboard-form-control rounded-xl border-2 border-slate-200 px-4 font-bold outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20"
            />
            <select value={listGrade} onChange={e => setListGrade(e.target.value)}
              className="dashboard-form-control rounded-xl border-2 border-slate-200 px-4 font-bold outline-none focus:border-blue-500">
              <option value="all">🎓 كل الصفوف</option>
              {listFilterOptions.grades.map(v => <option key={v} value={v}>{v}</option>)}
            </select>
            <select value={listSubject} onChange={e => setListSubject(e.target.value)}
              className="dashboard-form-control rounded-xl border-2 border-slate-200 px-4 font-bold outline-none focus:border-blue-500">
              <option value="all">📖 كل المواد</option>
              {listFilterOptions.subjects.map(v => <option key={v} value={v}>{v}</option>)}
            </select>
            <select value={listKind} onChange={e => setListKind(e.target.value as typeof listKind)}
              className="dashboard-form-control rounded-xl border-2 border-slate-200 px-4 font-bold outline-none focus:border-blue-500">
              <option value="all">🗂️ كل الأنواع</option>
              <option value="video">🎬 فيديو شرح</option>
              <option value="avatar">🤖 معلم افتراضي</option>
              <option value="meeting">📹 اجتماع مباشر</option>
              <option value="text">📝 نص الدرس</option>
            </select>
            <select value={listPublish} onChange={e => setListPublish(e.target.value as typeof listPublish)}
              className="dashboard-form-control rounded-xl border-2 border-slate-200 px-4 font-bold outline-none focus:border-blue-500">
              <option value="all">🔁 كل الحالات</option>
              <option value="published">✅ منشور</option>
              <option value="empty">⚠️ بلا محتوى</option>
            </select>
          </div>
          {listFiltersActive && (
            <button
              type="button"
              onClick={() => { setListSearch(''); setListSubject('all'); setListGrade('all'); setListKind('all'); setListPublish('all'); }}
              className="mt-3 rounded-xl bg-slate-100 px-5 py-2.5 text-sm font-bold text-slate-700 hover:bg-slate-200"
            >
              مسح الفلاتر ({visibleLessons.length} من {lessons.length})
            </button>
          )}
        </div>
      )}

      {/* ===== العرض الهجين: جدول على الشاشات الكبيرة، بطاقات دونها ===== */}
      <div className="dashboard-table-surface dashboard-content-records dashboard-content-table-surface dashboard-hybrid-table">
        <div className="dashboard-content-table-heading">
          <div>
            <span>المحتوى المنشور</span>
            <h2>دروس المنصة</h2>
          </div>
          <strong>{visibleLessons.length}{listFiltersActive ? ` من ${lessons.length}` : ''} محتوى</strong>
        </div>
        <table className="dashboard-content-table text-right">
          <thead className="dashboard-content-table-head">
            <tr>
              {/* الترتيب الهرمي كما يُقرأ: الصف ثم ما يتفرّع عنه حتى الدرس،
                  ثم الأعمدة الوظيفية. وكان العنوان الثالث «الترم» — مستوى
                  أُزيل من النظام — والعناوين خمسة والخلايا أربع، فانزاحت
                  القيم عموداً: الوحدة تُقرأ تحت «الترم»، والدرس لا يظهر. */}
              <th className="px-6 py-5">الصف</th>
              <th className="px-6 py-5">المادة</th>
              <th className="px-6 py-5">الفصل الدراسي</th>
              <th className="px-6 py-5">الوحدة</th>
              <th className="px-6 py-5">الدرس</th>
              {!teacherId && <th className="px-6 py-5">👨‍🏫 المنشئ</th>}
              <th className="px-6 py-5">الفيديو</th>
              <th className="px-6 py-5">الأفاتار</th>
              <th className="px-6 py-5">الاجتماع</th>
              <th className="px-6 py-5">الإجراءات</th>
            </tr>
          </thead>
          <tbody>
            {visibleLessons.map(l => (
              <tr key={l.id}>
                <td className="px-6 py-5 font-black text-purple-800">{l.grade}</td>
                <td className="px-6 py-5 font-bold text-purple-600">{l.subject}</td>
                <td className="px-6 py-5 text-purple-500">{l.term || '—'}</td>
                <td className="px-6 py-5 text-purple-500">{l.unit || '—'}</td>
                <td className="px-6 py-5 font-bold text-indigo-700">{l.lesson || '—'}</td>
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

      {/* ===== عرض البطاقات — الجوال والتابلت ===== */}
      <div className="dashboard-hybrid-cards">
        {lessons.length === 0 ? (
          <div className="dashboard-record-card text-center font-bold italic text-slate-400">
            لا يوجد محتوى تعليمي مضاف حالياً
          </div>
        ) : (
          <div className="dashboard-record-grid">
            {visibleLessons.map(l => (
              <article key={l.id} className="dashboard-record-card">
                <header className="dashboard-record-head">
                  <div className="min-w-0 flex-1">
                    <h3 className="dashboard-record-title">{l.lesson || l.unit}</h3>
                    <span className="dashboard-badge">👨‍🏫 {l.createdByName || 'المشرف'}</span>
                  </div>
                  <div className="dashboard-record-actions">
                    <button
                      onClick={() => handleEdit(l)}
                      className="dashboard-icon-button bg-blue-50 text-blue-700 hover:bg-blue-100"
                      title="تعديل"
                      aria-label="تعديل المحتوى"
                    >
                      ✏️
                    </button>
                    <button
                      onClick={() => handleDelete(l.id)}
                      className="dashboard-icon-button bg-red-50 text-red-700 hover:bg-red-100"
                      title="حذف"
                      aria-label="حذف المحتوى"
                    >
                      🗑️
                    </button>
                  </div>
                </header>

                {/* الهيكل السداسي كاملاً، مسمّى صراحةً — الجدول كان يعرض
                    أربعة مستويات فقط ويسقط الفصل والدرس. */}
                <div className="dashboard-record-badges">
                  <span className="dashboard-badge">{l.grade}</span>
                  <span className="dashboard-badge">{l.subject}</span>
                  <span className="dashboard-badge">{l.term}</span>
                  <span className="dashboard-badge">{l.unit}</span>
                  {l.lesson && <span className="dashboard-badge dashboard-badge-accent">📘 {l.lesson}</span>}
                </div>

                <dl className="dashboard-record-meta">
                  <div>
                    <dt>🎬 الفيديو</dt>
                    <dd>{l.explanationVideoUrl ? '✅ موجود' : '❌ غير موجود'}</dd>
                  </div>
                  <div>
                    <dt>🤖 الأفاتار</dt>
                    <dd>{l.avatarInteractionUrl ? '✅ موجود' : '❌ غير موجود'}</dd>
                  </div>
                  <div>
                    <dt>📹 الاجتماع</dt>
                    <dd>{l.liveMeetingUrl ? '✅ موجود' : '❌ غير موجود'}</dd>
                  </div>
                </dl>
              </article>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

export default ContentManagement;
