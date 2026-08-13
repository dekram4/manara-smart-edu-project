import React, { useState, useEffect } from 'react';
import { STORAGE_KEYS } from '../../constants';
import { playLamsaSound } from '../../utils/sounds';
import { HierarchicalConfig } from '../../types';
import { getRecordTeacherId, normalizeScopeValue } from '../../utils/scope';
import { getTeacherPermissions, getTeacherVideoUsageMb, isLimitReached } from '../../permissions';
import { deleteUploadedVideo, getVideoSourceType, isMp4VideoUrl, uploadMp4Video, VideoSourceType } from '../../utils/video';
import VideoThumbnail from '../../src/components/VideoThumbnail';

interface VideoRecord {
  id: string;
  title: string;
  description: string;
  url: string;
  sourceType?: VideoSourceType;
  grade: string;
  atram: string;
  subject: string;
  term: string;
  unit: string;
  createdBy: string;
  teacherName: string;
  createdAt: string;
}

interface CinemaVideoDraft {
  id: string;
  title: string;
  description: string;
  url: string;
  sourceType: VideoSourceType;
  createdAt: string;
}

interface VideoManagementProps {
  teacherId?: string;
  teacherName?: string;
  permissionPackageId?: string;
  isAdmin?: boolean;
}

const VideoManagement: React.FC<VideoManagementProps> = ({ teacherId, teacherName, permissionPackageId, isAdmin = false }) => {
  const [videos, setVideos] = useState<VideoRecord[]>([]);
  const [academicConfigs, setAcademicConfigs] = useState<HierarchicalConfig[]>([]);
  const [filters, setFilters] = useState({ grade: '', atram: '', subject: '', term: '', unit: '' });
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({
    title: '', description: '', url: '', sourceType: 'embed' as VideoSourceType, file: null as File | null,
    pendingVideos: [] as CinemaVideoDraft[],
    grade: '', atram: '', subject: '', term: '', unit: ''
  });
  const [editingVideo, setEditingVideo] = useState<VideoRecord | null>(null);

  useEffect(() => {
    loadVideos();
    loadAcademicConfigs();
  }, [teacherId, isAdmin]);

  const loadVideos = () => {
    const saved = localStorage.getItem(STORAGE_KEYS.VIDEOS);
    if (saved) {
      const all = JSON.parse(saved);
       setVideos(isAdmin
         ? all
         : all.filter((v: VideoRecord) => getRecordTeacherId(v) === normalizeScopeValue(teacherId)));
    }
  };

  const loadAcademicConfigs = () => {
    const allConfigs: HierarchicalConfig[] = JSON.parse(
      localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]',
    );
    setAcademicConfigs(isAdmin
      ? allConfigs
      : allConfigs.filter(config => getRecordTeacherId(config) === normalizeScopeValue(teacherId)));
  };

  const selectedGradeConfig = academicConfigs.find(
    config => config.grade === formData.grade,
  );
  const selectedAtramConfig = selectedGradeConfig?.atrams.find(
    atram => atram.atram === formData.atram,
  );
  const selectedSubjectConfig = selectedAtramConfig?.subjects.find(
    subject => subject.subject === formData.subject,
  );
  const selectedTermConfig = selectedSubjectConfig?.terms.find(
    term => term.term === formData.term,
  );

  const withCurrentValue = (values: string[], currentValue: string) =>
    currentValue && !values.includes(currentValue)
      ? [currentValue, ...values]
      : values;

  const availableGrades = withCurrentValue(
    Array.from(new Set(academicConfigs.map(config => config.grade))),
    formData.grade,
  );
  const availableAtrams = withCurrentValue(
    selectedGradeConfig?.atrams.map(atram => atram.atram) || [],
    formData.atram,
  );
  const availableSubjects = withCurrentValue(
    selectedAtramConfig?.subjects.map(subject => subject.subject) || [],
    formData.subject,
  );
  const availableTerms = withCurrentValue(
    selectedSubjectConfig?.terms.map(term => term.term) || [],
    formData.term,
  );
  const availableUnits = withCurrentValue(
    selectedTermConfig?.units || [],
    formData.unit,
  );

  const updateAcademicField = (
    field: 'grade' | 'atram' | 'subject' | 'term' | 'unit',
    value: string,
  ) => {
    const next = { ...formData, [field]: value };
    if (field === 'grade') {
      next.atram = '';
      next.subject = '';
      next.term = '';
      next.unit = '';
    } else if (field === 'atram') {
      next.subject = '';
      next.term = '';
      next.unit = '';
    } else if (field === 'subject') {
      next.term = '';
      next.unit = '';
    } else if (field === 'term') {
      next.unit = '';
    }
    setFormData(next);
  };

  const makeVideoId = () =>
    typeof crypto !== 'undefined' && crypto.randomUUID
      ? crypto.randomUUID()
      : `${Date.now()}-${Math.random().toString(36).slice(2)}`;

  const addCinemaVideo = async () => {
    if (formData.sourceType === 'embed' && !formData.url.trim()) {
      alert('يرجى إدخال الرابط المضمن أولاً');
      return;
    }
    if (formData.sourceType === 'mp4' && !formData.file) {
      alert('يرجى اختيار ملف MP4 أولاً');
      return;
    }

    let videoUrl = formData.url.trim();
    let title = formData.title.trim();
    if (formData.sourceType === 'mp4' && formData.file) {
      try {
        const file = formData.file;
        const uploaded = await uploadMp4Video(file);
        videoUrl = uploaded.url;
        title = title || file.name;
      } catch (error) {
        alert(`⚠️ ${error instanceof Error ? error.message : 'فشل رفع ملف الفيديو'}`);
        return;
      }
    }

    const draft: CinemaVideoDraft = {
      id: makeVideoId(),
      title: title || `فيديو السينما ${formData.pendingVideos.length + 1}`,
      description: formData.description.trim(),
      url: videoUrl,
      sourceType: formData.sourceType,
      createdAt: new Date().toISOString(),
    };
    setFormData(current => ({
      ...current,
      pendingVideos: [...current.pendingVideos, draft],
      title: '',
      description: '',
      url: '',
      sourceType: 'embed',
      file: null,
    }));
    playLamsaSound('pop');
  };

  const removeCinemaVideo = (id: string) => {
    const video = formData.pendingVideos.find(item => item.id === id);
    setFormData(current => ({
      ...current,
      pendingVideos: current.pendingVideos.filter(item => item.id !== id),
    }));
    if (video?.sourceType === 'mp4') void deleteUploadedVideo(video.url);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (
      !formData.grade ||
      !formData.atram ||
      !formData.subject ||
      !formData.term ||
      !formData.unit
    ) {
      alert('يرجى اختيار الصف والترم والمادة والفصل والوحدة');
      return;
    }

    const saved = localStorage.getItem(STORAGE_KEYS.VIDEOS);
    const all: VideoRecord[] = saved ? JSON.parse(saved) : [];
    const permissions = getTeacherPermissions({ permissionPackageId });
    const canManageVideos = isAdmin || permissions.canManageVideos;
    const ownerId = teacherId || 'admin';
    const ownerName = teacherName || 'المشرف - سينما منارة';
    const teacherVideos = all.filter(
      video => isAdmin || getRecordTeacherId(video) === normalizeScopeValue(ownerId),
    );

    if (!canManageVideos) {
      alert(`⚠️ ليس لديك صلاحية ${editingVideo ? 'إدارة' : 'إضافة'} الفيديوهات`);
      return;
    }

    if (editingVideo) {
      if (formData.sourceType === 'embed' && !formData.url.trim()) {
        alert('يرجى إدخال الرابط المضمن أولاً');
        return;
      }
      if (formData.sourceType === 'mp4' && !formData.file && !isMp4VideoUrl(editingVideo.url)) {
        alert('يرجى اختيار ملف MP4');
        return;
      }

      let videoUrl = formData.url.trim();
      if (formData.sourceType === 'mp4' && formData.file) {
        try {
          const uploaded = await uploadMp4Video(formData.file);
          videoUrl = uploaded.url;
        } catch (error) {
          alert(`⚠️ ${error instanceof Error ? error.message : 'فشل رفع ملف الفيديو'}`);
          return;
        }
      } else if (formData.sourceType === 'mp4' && isMp4VideoUrl(editingVideo.url)) {
        videoUrl = editingVideo.url;
      }

      const updated = all.map(video => video.id === editingVideo.id ? {
        ...video,
        title: formData.title.trim() || editingVideo.title,
        description: formData.description.trim(),
        url: videoUrl,
        sourceType: formData.sourceType,
        grade: formData.grade,
        atram: formData.atram,
        subject: formData.subject,
        term: formData.term,
        unit: formData.unit,
      } : video);
      localStorage.setItem(STORAGE_KEYS.VIDEOS, JSON.stringify(updated));
      if (editingVideo.url && editingVideo.url !== videoUrl) void deleteUploadedVideo(editingVideo.url);
      setEditingVideo(null);
    } else {
      let videosToCreate = [...formData.pendingVideos];
      const hasUnaddedVideoInput = Boolean(
        formData.title.trim() || formData.description.trim() || formData.url.trim() || formData.file,
      );

      // Like the lesson-content form, the last video can be entered and saved
      // directly without requiring a second click on «إضافة فيديو جديد».
      if (hasUnaddedVideoInput) {
        if (formData.sourceType === 'embed' && !formData.url.trim()) {
          alert('أكمل بيانات الفيديو الحالي أو اضغط «إضافة فيديو جديد» قبل الحفظ');
          return;
        }
        if (formData.sourceType === 'mp4' && !formData.file) {
          alert('اختر ملف MP4 للفيديو الحالي أو اضغط «إضافة فيديو جديد» قبل الحفظ');
          return;
        }
        let videoUrl = formData.url.trim();
        let title = formData.title.trim();
        if (formData.sourceType === 'mp4' && formData.file) {
          try {
            const uploaded = await uploadMp4Video(formData.file);
            videoUrl = uploaded.url;
            title = title || formData.file.name;
          } catch (error) {
            alert(`⚠️ ${error instanceof Error ? error.message : 'فشل رفع ملف الفيديو'}`);
            return;
          }
        }
        videosToCreate.push({
          id: makeVideoId(),
          title: title || `فيديو السينما ${videosToCreate.length + 1}`,
          description: formData.description.trim(),
          url: videoUrl,
          sourceType: formData.sourceType,
          createdAt: new Date().toISOString(),
        });
      }

      if (videosToCreate.length === 0) {
        alert('أضف فيديو واحدًا على الأقل إلى سينما منارة');
        return;
      }
      if (
        !isAdmin &&
        isLimitReached(teacherVideos.length + videosToCreate.length, permissions.maxVideos)
      ) {
        alert(`⚠️ ستتجاوز الحد الأقصى المسموح به (${permissions.maxVideos}) من الفيديوهات`);
        return;
      }

      const newVideos: VideoRecord[] = videosToCreate.map(video => ({
        ...video,
        grade: formData.grade,
        atram: formData.atram,
        subject: formData.subject,
        term: formData.term,
        unit: formData.unit,
        createdBy: ownerId,
        teacherName: ownerName,
      }));
      const nextVideos = [...all, ...newVideos];
      if (
        permissions.maxStorageMb >= 0 &&
        getTeacherVideoUsageMb(nextVideos.filter(video =>
          getRecordTeacherId(video) === normalizeScopeValue(ownerId),
        )) > permissions.maxStorageMb
      ) {
        alert(`⚠️ ستتجاوز مساحة الفيديوهات المسموحة (${permissions.maxStorageMb} MB)`);
        return;
      }
      localStorage.setItem(STORAGE_KEYS.VIDEOS, JSON.stringify(nextVideos));

      if (!isAdmin) {
        const notifs = JSON.parse(localStorage.getItem(STORAGE_KEYS.VIDEO_NOTIFICATIONS) || '[]');
        newVideos.forEach(newVideo => {
          notifs.push({
            id: `${Date.now()}-${newVideo.id}`,
            type: 'new_video',
            message: `🎬 أضاف المعلم ${ownerName} فيديو جديد: "${newVideo.title}" (${formData.grade} • ${formData.atram} • ${formData.subject} • ${formData.term} • ${formData.unit})`,
            teacherId: ownerId,
            teacherName: ownerName,
            videoId: newVideo.id,
            videoTitle: newVideo.title,
            grade: newVideo.grade,
            atram: newVideo.atram,
            subject: newVideo.subject,
            term: newVideo.term,
            unit: newVideo.unit,
            createdAt: new Date().toISOString(),
            read: false,
          });
        });
        localStorage.setItem(STORAGE_KEYS.VIDEO_NOTIFICATIONS, JSON.stringify(notifs));
      }
    }

    setFormData({
      title: '',
      description: '',
      url: '',
      sourceType: 'embed',
      file: null,
      pendingVideos: [],
      grade: '',
      atram: '',
      subject: '',
      term: '',
      unit: '',
    });
    setShowForm(false);
    loadVideos();
    playLamsaSound('success');
  };

  const handleDelete = (id: string) => {
    if (!isAdmin && !getTeacherPermissions({ permissionPackageId }).canManageVideos) {
      alert('⚠️ ليس لديك صلاحية حذف الفيديوهات');
      return;
    }
    if (!confirm('هل أنت متأكد من حذف هذا الفيديو؟')) return;
    const deletedIds = JSON.parse(
      localStorage.getItem(STORAGE_KEYS.DELETED_VIDEOS) || '[]',
    );
    const nextDeletedIds = Array.from(
      new Set([...deletedIds.filter((value: unknown) => value != null).map(String), String(id)]),
    );
    // Save the tombstone before removing the record so a later Supabase hydrate
    // cannot merge this deliberately deleted video back into the local list.
    localStorage.setItem(STORAGE_KEYS.DELETED_VIDEOS, JSON.stringify(nextDeletedIds));
    const saved = localStorage.getItem(STORAGE_KEYS.VIDEOS);
    if (saved) {
      const all = JSON.parse(saved).filter((v: VideoRecord) => v.id !== id);
      localStorage.setItem(STORAGE_KEYS.VIDEOS, JSON.stringify(all));
      const deletedVideo = videos.find(video => video.id === id);
      if (deletedVideo?.url) void deleteUploadedVideo(deletedVideo.url);
      loadVideos();
      playLamsaSound('pop');
    }
  };

  const filteredVideos = videos.filter((video) => {
    if (filters.grade && video.grade !== filters.grade) return false;
    if (filters.atram && video.atram !== filters.atram) return false;
    if (filters.subject && video.subject !== filters.subject) return false;
    if (filters.term && video.term !== filters.term) return false;
    if (filters.unit && video.unit !== filters.unit) return false;
    return true;
  });

  const filterOptions = {
    grades: Array.from(new Set(videos.map((video) => video.grade).filter(Boolean))),
    atrams: Array.from(new Set(videos.map((video) => video.atram).filter(Boolean))),
    subjects: Array.from(new Set(videos.map((video) => video.subject).filter(Boolean))),
    terms: Array.from(new Set(videos.map((video) => video.term).filter(Boolean))),
    units: Array.from(new Set(videos.map((video) => video.unit).filter(Boolean))),
  };

  return (
     <div className="animate-fadeIn space-y-6">
      <div className="flex justify-between items-center">
        <div>
           <h2 className="text-4xl font-black text-amber-800">🎬 إدارة سينما منارة</h2>
           <p className="text-amber-500 font-medium mt-1">{isAdmin ? 'إدارة الفيديوهات العامة لجميع الطلاب' : 'أضف فيديوهات تعليمية لطلابك'}</p>
        </div>
        <button
           disabled={!isAdmin && !getTeacherPermissions({ permissionPackageId }).canManageVideos}
           onClick={() => {
             setShowForm(!showForm);
             setEditingVideo(null);
             if (!showForm) {
               setFormData({
                 title: '',
                 description: '',
                 url: '',
                 sourceType: 'embed',
                 file: null,
                 pendingVideos: [],
                 grade: '',
                 atram: '',
                 subject: '',
                 term: '',
                 unit: '',
               });
             }
             playLamsaSound('click');
           }}
          className="px-6 py-3 bg-gradient-to-r from-amber-400 to-orange-500 text-white rounded-2xl font-black shadow-xl hover:scale-105 transition-all active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {showForm ? '❌ إلغاء' : '➕ فيديو جديد'}
        </button>
      </div>

      <div className="rounded-2xl border-2 border-amber-200 bg-amber-50/80 p-4">
         <div className="mb-3 flex flex-col items-stretch gap-3 sm:flex-row sm:items-center sm:justify-between">
          <h3 className="text-lg font-black text-amber-800">🔎 فلترة الفيديوهات</h3>
          <button
            onClick={() => setFilters({ grade: '', atram: '', subject: '', term: '', unit: '' })}
             className="min-h-11 rounded-lg bg-white px-3 py-2 text-xs font-bold text-amber-700 hover:bg-amber-100 sm:min-h-0 sm:py-1"
          >
            مسح الفلاتر
          </button>
        </div>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-5">
          <select value={filters.grade} onChange={(e) => setFilters({ ...filters, grade: e.target.value })} className="rounded-xl border-2 border-amber-200 bg-white p-3 font-bold text-amber-900">
            <option value="">🎓 كل الصفوف</option>
            {filterOptions.grades.map((grade) => <option key={grade} value={grade}>{grade}</option>)}
          </select>
          <select value={filters.atram} onChange={(e) => setFilters({ ...filters, atram: e.target.value })} className="rounded-xl border-2 border-amber-200 bg-white p-3 font-bold text-amber-900">
            <option value="">📅 كل الأترام</option>
            {filterOptions.atrams.map((atram) => <option key={atram} value={atram}>{atram}</option>)}
          </select>
          <select value={filters.subject} onChange={(e) => setFilters({ ...filters, subject: e.target.value })} className="rounded-xl border-2 border-amber-200 bg-white p-3 font-bold text-amber-900">
            <option value="">📖 كل المواد</option>
            {filterOptions.subjects.map((subject) => <option key={subject} value={subject}>{subject}</option>)}
          </select>
          <select value={filters.term} onChange={(e) => setFilters({ ...filters, term: e.target.value })} className="rounded-xl border-2 border-amber-200 bg-white p-3 font-bold text-amber-900">
            <option value="">📑 كل الفصول</option>
            {filterOptions.terms.map((term) => <option key={term} value={term}>{term}</option>)}
          </select>
          <select value={filters.unit} onChange={(e) => setFilters({ ...filters, unit: e.target.value })} className="rounded-xl border-2 border-amber-200 bg-white p-3 font-bold text-amber-900">
            <option value="">📦 كل الوحدات</option>
            {filterOptions.units.map((unit) => <option key={unit} value={unit}>{unit}</option>)}
          </select>
        </div>
      </div>

      {showForm && (
        <form onSubmit={handleSubmit} className="space-y-5 rounded-[30px] border-2 border-amber-200 bg-white p-5 shadow-xl animate-bounce-in sm:p-8">
          <div className="flex flex-col gap-2 border-b border-amber-100 pb-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h3 className="text-2xl font-black text-amber-900">
                {editingVideo ? '✏️ تعديل فيديو سينما منارة' : '🎬 إضافة فيديوهات إلى سينما منارة'}
              </h3>
              <p className="mt-1 text-sm font-bold text-amber-600">
                أضف أكثر من فيديو لنفس الصف والترم والمادة والفصل والوحدة قبل الحفظ.
              </p>
            </div>
            {formData.pendingVideos.length > 0 && (
              <span className="rounded-full bg-amber-100 px-4 py-2 text-sm font-black text-amber-800">
                {formData.pendingVideos.length} فيديو جاهز للحفظ
              </span>
            )}
          </div>

          <div className="grid grid-cols-1 gap-5 md:grid-cols-2">
            <input
              type="text"
              placeholder="عنوان الفيديو (اختياري لملفات MP4)"
              value={formData.title}
              onChange={e => setFormData({ ...formData, title: e.target.value })}
              className="rounded-2xl border-[3px] border-amber-200 bg-amber-50 p-4 font-bold outline-none focus:border-amber-400 focus:ring-4 focus:ring-amber-100"
            />
            <div className="space-y-2">
              <div className="flex gap-2 rounded-2xl bg-amber-50 p-2">
                <button
                  type="button"
                  onClick={() => setFormData({ ...formData, sourceType: 'embed', url: formData.sourceType === 'mp4' ? '' : formData.url, file: null })}
                  className={`flex-1 rounded-xl px-3 py-3 text-sm font-black ${formData.sourceType === 'embed' ? 'bg-amber-500 text-white shadow-md' : 'text-amber-700'}`}
                >
                  🔗 رابط مضمن
                </button>
                <button
                  type="button"
                  onClick={() => setFormData({ ...formData, sourceType: 'mp4', url: '' })}
                  className={`flex-1 rounded-xl px-3 py-3 text-sm font-black ${formData.sourceType === 'mp4' ? 'bg-amber-500 text-white shadow-md' : 'text-amber-700'}`}
                >
                  📁 رفع MP4
                </button>
              </div>
              {formData.sourceType === 'embed' ? (
                <input
                  type="url"
                  placeholder="https://www.youtube.com/watch?v=..."
                  value={formData.url}
                  onChange={e => setFormData({ ...formData, url: e.target.value })}
                  className="w-full rounded-2xl border-[3px] border-amber-200 bg-amber-50 p-4 font-bold outline-none focus:border-amber-400 focus:ring-4 focus:ring-amber-100"
                />
              ) : (
                <label className="block cursor-pointer rounded-2xl border-[3px] border-dashed border-amber-300 bg-amber-50 p-4 text-center font-bold text-amber-700 transition hover:bg-amber-100">
                  <span>{formData.file?.name || 'اختر ملف MP4 بحد أقصى 500MB'}</span>
                  <input
                    type="file"
                    accept="video/mp4,.mp4"
                    className="hidden"
                    onChange={e => setFormData({ ...formData, file: e.target.files?.[0] || null })}
                  />
                </label>
              )}
            </div>
          </div>

          <textarea
            placeholder="وصف الفيديو (اختياري)"
            value={formData.description}
            onChange={e => setFormData({ ...formData, description: e.target.value })}
            className="w-full resize-none rounded-2xl border-[3px] border-amber-200 bg-amber-50 p-4 font-bold outline-none focus:border-amber-400 focus:ring-4 focus:ring-amber-100"
            rows={3}
          />

          {!editingVideo && (
            <button
              type="button"
              onClick={addCinemaVideo}
              className="w-full rounded-2xl border-2 border-amber-300 bg-amber-100 px-4 py-4 text-lg font-black text-amber-800 transition hover:bg-amber-200 active:scale-[.99]"
            >
              ➕ إضافة فيديو جديد إلى القائمة
            </button>
          )}

          {formData.pendingVideos.length > 0 && (
            <div className="space-y-3 rounded-3xl border-2 border-amber-200 bg-amber-50/70 p-4">
              <div className="flex items-center justify-between gap-3">
                <p className="font-black text-amber-900">🎞️ فيديوهات هذه الدفعة</p>
                <span className="text-xs font-bold text-amber-600">ستُحفظ كلها بنفس التصنيف الأكاديمي</span>
              </div>
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                {formData.pendingVideos.map((video, index) => (
                  <div key={video.id} className="flex items-center gap-3 rounded-2xl border border-amber-200 bg-white p-3 shadow-sm">
                    <div className="flex h-14 w-20 shrink-0 items-center justify-center overflow-hidden rounded-xl bg-gradient-to-br from-amber-400 via-orange-500 to-rose-500 text-2xl shadow-md">
                      {video.sourceType === 'mp4' ? '🎬' : '🔗'}
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-black text-amber-900">{index + 1}. {video.title}</p>
                      <p className="text-xs font-bold text-amber-600">{video.sourceType === 'mp4' ? 'ملف MP4' : 'رابط مضمن'}</p>
                    </div>
                    <button
                      type="button"
                      onClick={() => removeCinemaVideo(video.id)}
                      aria-label={`حذف ${video.title}`}
                      className="rounded-xl px-3 py-2 text-sm font-black text-red-600 transition hover:bg-red-100"
                    >
                      حذف
                    </button>
                  </div>
                ))}
              </div>
            </div>
          )}

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-3">
            <select
              value={formData.grade}
              onChange={e => updateAcademicField('grade', e.target.value)}
              className="p-3 bg-amber-50 border-2 border-amber-200 rounded-xl font-bold focus:border-amber-400 outline-none"
              required
            >
              <option value="">🎓 الصف</option>
              {availableGrades.map(grade => <option key={grade} value={grade}>{grade}</option>)}
            </select>
            <select
              value={formData.atram}
              onChange={e => updateAcademicField('atram', e.target.value)}
              className="p-3 bg-amber-50 border-2 border-amber-200 rounded-xl font-bold focus:border-amber-400 outline-none"
              disabled={!formData.grade}
              required
            >
              <option value="">📅 الترم</option>
              {availableAtrams.map(atram => <option key={atram} value={atram}>{atram}</option>)}
            </select>
            <select
              value={formData.subject}
              onChange={e => updateAcademicField('subject', e.target.value)}
              className="p-3 bg-amber-50 border-2 border-amber-200 rounded-xl font-bold focus:border-amber-400 outline-none"
              disabled={!formData.atram}
              required
            >
              <option value="">📖 المادة</option>
              {availableSubjects.map(subject => <option key={subject} value={subject}>{subject}</option>)}
            </select>
            <select
              value={formData.term}
              onChange={e => updateAcademicField('term', e.target.value)}
              className="p-3 bg-amber-50 border-2 border-amber-200 rounded-xl font-bold focus:border-amber-400 outline-none"
              disabled={!formData.subject}
              required
            >
              <option value="">📑 الفصل</option>
              {availableTerms.map(term => <option key={term} value={term}>{term}</option>)}
            </select>
            <select
              value={formData.unit}
              onChange={e => updateAcademicField('unit', e.target.value)}
              className="p-3 bg-amber-50 border-2 border-amber-200 rounded-xl font-bold focus:border-amber-400 outline-none"
              disabled={!formData.term}
              required
            >
              <option value="">📦 الوحدة</option>
              {availableUnits.map(unit => <option key={unit} value={unit}>{unit}</option>)}
            </select>
          </div>
          <button type="submit" className="w-full bg-gradient-to-r from-amber-400 to-orange-500 py-4 text-xl font-black text-white rounded-2xl shadow-xl transition-all hover:scale-[1.02] hover:-translate-y-0.5 active:scale-95 animate-pulse-glow">
            {editingVideo ? '💾 حفظ التعديل' : '✨ حفظ كل فيديوهات السينما'}
          </button>
        </form>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {filteredVideos.map((video) => {
          return (
            <div key={video.id} className="bg-white rounded-[30px] shadow-xl border-2 border-amber-100 overflow-hidden hover:shadow-2xl hover:-translate-y-2 transition-all group">
              <div className="relative aspect-video bg-black">
                <VideoThumbnail url={video.url} sourceType={video.sourceType} alt={video.title} />
                <div className="absolute inset-0 flex items-center justify-center bg-black/30 transition-all group-hover:bg-black/20">
                  <div className="flex h-16 w-16 items-center justify-center rounded-full bg-white/90 text-3xl shadow-xl transition-transform group-hover:scale-110">
                    <span>▶</span>
                  </div>
                </div>
              </div>
              <div className="p-5">
                <h3 className="text-xl font-black text-amber-900 mb-2">{video.title}</h3>
                <p className="text-amber-600 text-sm font-medium mb-3 line-clamp-2">{video.description}</p>
                <div className="flex flex-wrap gap-2 mb-4">
                  {video.grade && <span className="px-2 py-1 bg-amber-100 text-amber-700 rounded-lg text-xs font-bold">📚 {video.grade}</span>}
                  {video.subject && <span className="px-2 py-1 bg-orange-100 text-orange-700 rounded-lg text-xs font-bold">📖 {video.subject}</span>}
                  {video.atram && <span className="px-2 py-1 bg-indigo-100 text-indigo-700 rounded-lg text-xs font-bold">📅 {video.atram}</span>}
                  {video.term && <span className="px-2 py-1 bg-rose-100 text-rose-700 rounded-lg text-xs font-bold">📑 {video.term}</span>}
                  {video.unit && <span className="px-2 py-1 bg-emerald-100 text-emerald-700 rounded-lg text-xs font-bold">📦 {video.unit}</span>}
                </div>
                <div className="flex gap-2">
                     <button disabled={!isAdmin && !getTeacherPermissions({ permissionPackageId }).canManageVideos} onClick={() => { setEditingVideo(video); setFormData({ title: video.title, description: video.description, url: video.url, sourceType: getVideoSourceType(video.sourceType, video.url), file: null, pendingVideos: [], grade: video.grade, atram: video.atram || '', subject: video.subject, term: video.term, unit: video.unit }); setShowForm(true); playLamsaSound('click'); }} className="flex-1 py-2 bg-amber-100 text-amber-700 rounded-xl font-bold hover:bg-amber-200 transition-all text-sm disabled:opacity-50">✏️ تعديل</button>
                    <button disabled={!isAdmin && !getTeacherPermissions({ permissionPackageId }).canManageVideos} onClick={() => handleDelete(video.id)} className="flex-1 py-2 bg-red-100 text-red-600 rounded-xl font-bold hover:bg-red-200 transition-all text-sm disabled:opacity-50">❌ حذف</button>
                </div>
              </div>
            </div>
          );
        })}
        {filteredVideos.length === 0 && (
          <div className="col-span-full p-16 bg-amber-50 rounded-[40px] border-2 border-dashed border-amber-300 text-center animate-popIn">
            <div className="text-7xl mb-6">🎬</div>
            <h3 className="text-2xl font-black text-amber-800 mb-3">لا توجد فيديوهات مطابقة للفلاتر</h3>
            <p className="text-amber-600 font-bold">جرّب تغيير الفلاتر أو أضف فيديو جديد ✓</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default VideoManagement;
