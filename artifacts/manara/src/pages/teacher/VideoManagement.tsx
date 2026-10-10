import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { readHierarchicalConfigs } from '../../utils/academic';
import { STORAGE_KEYS } from '../../constants';
import { playLamsaSound } from '../../utils/sounds';
import { HierarchicalConfig } from '../../types';
import { getRecordTeacherId, normalizeScopeValue } from '../../utils/scope';
import { getTeacherPermissions, isLimitReached } from '../../permissions';
import { deleteUploadedVideo, getVideoSourceType, isMp4VideoUrl, safeVideoUrl, showVideoStorageNotice, uploadMp4Video, VideoSourceType } from '../../utils/video';
import VideoThumbnail from '../../components/VideoThumbnail';
import { managementRequest } from '../../utils/managementApi';

/**
 * إدارة سينما منارة.
 *
 * ── الفيديو للصفّ، لا للدرس ──
 * كان الفيديو يُحفظ بمسارٍ سداسيّ (صفّ، مادة، فصل، وحدة، درس) ولا يراه
 * الطالب إلا داخل ذلك الدرس. صار الربطُ الصفَّ الدراسيّ والمعلمَ المسؤول
 * وحدهما — وكلاهما إلزاميّ — فيرى طلابُ المعلم في ذلك الصفّ الفيديو أيّاً
 * كان الدرس الذي يتصفّحونه.
 *
 * والحفظ عبر `/api/cinema/videos` لا عبر التخزين المحلي: الخادم يتحقّق من
 * الصفّ والمعلم والرابط، ويكتب في جدول `cinema_videos`.
 */

interface CinemaVideo {
  id: string;
  title: string;
  description: string;
  url: string;
  sourceType?: VideoSourceType;
  gradeId: string;
  teacherId: string;
  teacherName: string;
  createdBy: string;
  createdAt: string;
}

interface CinemaVideoDraft {
  id: string;
  title: string;
  description: string;
  url: string;
  sourceType: VideoSourceType;
}

interface CinemaListResponse {
  storage: 'table' | 'kv';
  teachers: Array<{ id: string; name: string }>;
  videos: CinemaVideo[];
}

interface VideoManagementProps {
  teacherId?: string;
  teacherName?: string;
  permissionPackageId?: string;
  isAdmin?: boolean;
}

const EMPTY_FORM = {
  title: '',
  description: '',
  url: '',
  sourceType: 'embed' as VideoSourceType,
  file: null as File | null,
  pendingVideos: [] as CinemaVideoDraft[],
  gradeId: '',
};

const readStringArray = (key: string): string[] => {
  try {
    const value = JSON.parse(localStorage.getItem(key) || '[]');
    return Array.isArray(value) ? value.filter((item): item is string => typeof item === 'string' && Boolean(item.trim())) : [];
  } catch {
    return [];
  }
};

const VideoManagement: React.FC<VideoManagementProps> = ({ teacherId, teacherName, permissionPackageId, isAdmin = false }) => {
  const [videos, setVideos] = useState<CinemaVideo[]>([]);
  const [teachers, setTeachers] = useState<Array<{ id: string; name: string }>>([]);
  const [storage, setStorage] = useState<'table' | 'kv' | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState('');
  const [saving, setSaving] = useState(false);
  const [selectedTeacherId, setSelectedTeacherId] = useState('');
  const [filters, setFilters] = useState({ grade: '', teacher: '' });
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState(EMPTY_FORM);
  const [editingVideo, setEditingVideo] = useState<CinemaVideo | null>(null);

  const permissions = getTeacherPermissions({ permissionPackageId });
  const canManageVideos = isAdmin || permissions.canManageVideos;

  const loadVideos = useCallback(async () => {
    setLoading(true);
    setLoadError('');
    try {
      const data = await managementRequest<CinemaListResponse>('/api/cinema/videos');
      setVideos(Array.isArray(data.videos) ? data.videos : []);
      setTeachers(Array.isArray(data.teachers) ? data.teachers : []);
      setStorage(data.storage ?? null);
    } catch (error) {
      setLoadError(error instanceof Error ? error.message : 'تعذر تحميل فيديوهات السينما');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadVideos();
  }, [loadVideos, teacherId, isAdmin]);

  // المعلم المسؤول: للمعلم هو نفسه دائماً، وللمشرف ما يختاره.
  const ownerId = isAdmin ? selectedTeacherId : teacherId || '';
  const ownerName = isAdmin
    ? teachers.find(teacher => teacher.id === selectedTeacherId)?.name || editingVideo?.teacherName || ''
    : teacherName || '';

  /// صفوف المعلم المسؤول من شجرته الأكاديمية، ومعها قائمة الصفوف العامة —
  /// فلا يبقى الحقل فارغاً لمعلمٍ لم يبنِ شجرته بعد.
  const availableGrades = useMemo(() => {
    const configs: HierarchicalConfig[] = readHierarchicalConfigs(STORAGE_KEYS.HIERARCHICAL_CONFIGS);
    const owned = ownerId
      ? configs.filter(config => getRecordTeacherId(config) === normalizeScopeValue(ownerId))
      : [];
    const grades = [
      ...owned.map(config => config.grade),
      ...readStringArray(STORAGE_KEYS.GRADES),
    ].filter(Boolean);
    if (formData.gradeId) grades.unshift(formData.gradeId);
    return Array.from(new Set(grades));
  }, [ownerId, formData.gradeId]);

  const resetForm = () => {
    setFormData(EMPTY_FORM);
    setEditingVideo(null);
    if (isAdmin) setSelectedTeacherId('');
  };

  const beginEditingVideo = (video: CinemaVideo) => {
    if (isAdmin) setSelectedTeacherId(video.teacherId);
    setEditingVideo(video);
    setFormData({
      ...EMPTY_FORM,
      title: video.title,
      description: video.description,
      url: video.url,
      sourceType: getVideoSourceType(video.sourceType, video.url),
      gradeId: video.gradeId,
    });
    setShowForm(true);
    playLamsaSound('click');
  };

  const makeVideoId = () =>
    typeof crypto !== 'undefined' && crypto.randomUUID
      ? crypto.randomUUID()
      : `${Date.now()}-${Math.random().toString(36).slice(2)}`;

  /// يجهّز ما في الحقول (رابطاً أو ملفاً أو كليهما) كمسوّداتٍ تُحفظ معاً.
  const draftsFromInputs = async (startIndex: number): Promise<CinemaVideoDraft[] | null> => {
    const embedUrl = formData.url.trim();
    const selectedFile = formData.file;
    const title = formData.title.trim();
    const description = formData.description.trim();
    const drafts: CinemaVideoDraft[] = [];
    if (embedUrl) {
      drafts.push({
        id: makeVideoId(),
        title: title || `رابط سينما ${startIndex + 1}`,
        description,
        url: embedUrl,
        sourceType: 'embed',
      });
    }
    if (selectedFile) {
      try {
        const uploaded = await uploadMp4Video(selectedFile);
        showVideoStorageNotice(uploaded);
        drafts.push({
          id: makeVideoId(),
          title: title || selectedFile.name,
          description,
          url: uploaded.url,
          sourceType: 'mp4',
        });
      } catch (error) {
        alert(`⚠️ ${error instanceof Error ? error.message : 'فشل رفع ملف الفيديو'}`);
        return null;
      }
    }
    return drafts;
  };

  const addCinemaVideo = async () => {
    if (!formData.url.trim() && !formData.file) {
      alert('أدخل رابطًا مضمنًا أو اختر ملف MP4 واحدًا على الأقل');
      return;
    }
    const drafts = await draftsFromInputs(formData.pendingVideos.length);
    if (!drafts) return;
    setFormData(current => ({
      ...current,
      pendingVideos: [...current.pendingVideos, ...drafts],
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

  const saveVideo = (video: {
    id?: string;
    title: string;
    description: string;
    url: string;
    sourceType: VideoSourceType;
  }) =>
    managementRequest<{ video: CinemaVideo }>('/api/cinema/videos', {
      method: 'POST',
      body: JSON.stringify({
        ...video,
        embedUrl: video.url,
        gradeId: formData.gradeId,
        teacherId: ownerId,
        teacherName: ownerName,
      }),
    });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!canManageVideos) {
      alert(`⚠️ ليس لديك صلاحية ${editingVideo ? 'إدارة' : 'إضافة'} الفيديوهات`);
      return;
    }
    if (!ownerId) {
      alert('يرجى اختيار المعلم المسؤول عن الفيديو');
      return;
    }
    if (!formData.gradeId.trim()) {
      alert('يرجى اختيار الصف الدراسي');
      return;
    }

    setSaving(true);
    try {
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
            showVideoStorageNotice(uploaded);
            videoUrl = uploaded.url;
          } catch (error) {
            alert(`⚠️ ${error instanceof Error ? error.message : 'فشل رفع ملف الفيديو'}`);
            return;
          }
        } else if (formData.sourceType === 'mp4') {
          videoUrl = editingVideo.url;
        }
        await saveVideo({
          id: editingVideo.id,
          title: formData.title.trim() || editingVideo.title,
          description: formData.description.trim(),
          url: videoUrl,
          sourceType: formData.sourceType,
        });
        if (editingVideo.url && editingVideo.url !== videoUrl) void deleteUploadedVideo(editingVideo.url);
      } else {
        let videosToCreate = [...formData.pendingVideos];
        // كنموذج المحتوى: آخر فيديو يُحفظ مباشرةً بلا ضغطة «إضافة» ثانية.
        if (formData.title.trim() || formData.description.trim() || formData.url.trim() || formData.file) {
          if (!formData.url.trim() && !formData.file) {
            alert('أدخل رابطًا مضمنًا أو اختر ملف MP4 قبل الحفظ');
            return;
          }
          const drafts = await draftsFromInputs(videosToCreate.length);
          if (!drafts) return;
          videosToCreate = [...videosToCreate, ...drafts];
        }
        if (videosToCreate.length === 0) {
          alert('أضف فيديو واحدًا على الأقل إلى سينما منارة');
          return;
        }
        if (!isAdmin && isLimitReached(videos.length + videosToCreate.length, permissions.maxVideos)) {
          alert(`⚠️ ستتجاوز الحد الأقصى المسموح به (${permissions.maxVideos}) من الفيديوهات`);
          return;
        }
        for (const draft of videosToCreate) {
          await saveVideo({
            title: draft.title,
            description: draft.description,
            url: draft.url,
            sourceType: draft.sourceType,
          });
        }
        if (!isAdmin) {
          const notifs = JSON.parse(localStorage.getItem(STORAGE_KEYS.VIDEO_NOTIFICATIONS) || '[]');
          videosToCreate.forEach(video => {
            notifs.push({
              id: `${Date.now()}-${video.id}`,
              type: 'new_video',
              message: `🎬 أضاف المعلم ${ownerName} فيديو جديد: "${video.title}" (${formData.gradeId})`,
              teacherId: ownerId,
              teacherName: ownerName,
              videoId: video.id,
              videoTitle: video.title,
              grade: formData.gradeId,
              createdAt: new Date().toISOString(),
              read: false,
            });
          });
          localStorage.setItem(STORAGE_KEYS.VIDEO_NOTIFICATIONS, JSON.stringify(notifs));
        }
      }
      resetForm();
      setShowForm(false);
      await loadVideos();
      playLamsaSound('success');
    } catch (error) {
      alert(`⚠️ ${error instanceof Error ? error.message : 'تعذر حفظ فيديو السينما'}`);
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (video: CinemaVideo) => {
    if (!canManageVideos) {
      alert('⚠️ ليس لديك صلاحية حذف الفيديوهات');
      return;
    }
    if (!confirm('هل أنت متأكد من حذف هذا الفيديو؟')) return;
    try {
      await managementRequest<null>(`/api/cinema/videos/${encodeURIComponent(video.id)}`, { method: 'DELETE' });
      if (video.url) void deleteUploadedVideo(video.url);
      await loadVideos();
      playLamsaSound('pop');
    } catch (error) {
      alert(`⚠️ ${error instanceof Error ? error.message : 'تعذر حذف الفيديو'}`);
    }
  };

  const filteredVideos = videos.filter(video => {
    if (filters.grade && video.gradeId !== filters.grade) return false;
    if (filters.teacher && video.teacherId !== filters.teacher) return false;
    return true;
  });

  const filterGrades = Array.from(new Set(videos.map(video => video.gradeId).filter(Boolean)));
  const filterTeachers = Array.from(
    new Map(videos.map(video => [video.teacherId, video.teacherName || video.teacherId])).entries(),
  );

  return (
     <div className="dashboard-page dashboard-consistent-page dashboard-video-page animate-fadeIn">
       <div className="dashboard-section-header">
        <div>
           <h2 className="text-4xl font-black text-amber-800">🎬 إدارة سينما منارة</h2>
           <p className="text-amber-500 font-medium mt-1">
             {isAdmin ? 'فيديوهات لكل صف دراسي، مسندة إلى المعلم المسؤول' : 'أضف فيديوهات لطلابك في كل صف دراسي'}
           </p>
        </div>
        <button
           disabled={!canManageVideos}
           onClick={() => {
             if (showForm) {
               setShowForm(false);
               resetForm();
             } else {
               resetForm();
               setShowForm(true);
             }
             playLamsaSound('click');
           }}
          className="px-6 py-3 bg-gradient-to-r from-amber-400 to-orange-500 text-white rounded-2xl font-black shadow-xl hover:scale-105 transition-all active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {showForm ? '❌ إلغاء' : '➕ فيديو جديد'}
        </button>
      </div>

      {storage === 'kv' && (
        <div className="rounded-2xl border-2 border-amber-300 bg-amber-50 p-3 text-sm font-bold text-amber-900">
          ℹ️ جدول <code>cinema_videos</code> لم يُنشأ بعد في Supabase، فتُحفظ الفيديوهات مؤقتاً في التخزين المشترك القديم وتعمل كاملةً.
          شغّل ملف <code>cinema-and-card-permissions.sql</code> في محرّر SQL لنقلها إلى الجدول.
        </div>
      )}

       <div className="dashboard-filter-surface border-amber-200 bg-amber-50/80">
         <div className="mb-3 flex flex-col items-stretch gap-3 sm:flex-row sm:items-center sm:justify-between">
          <h3 className="text-lg font-black text-amber-800">🔎 فلترة الفيديوهات</h3>
          <button
            onClick={() => setFilters({ grade: '', teacher: '' })}
             className="min-h-11 rounded-lg bg-white px-3 py-2 text-xs font-bold text-amber-700 hover:bg-amber-100 sm:min-h-0 sm:py-1"
          >
            مسح الفلاتر
          </button>
        </div>
         <div className="dashboard-filter-grid">
          <select value={filters.grade} onChange={(e) => setFilters({ ...filters, grade: e.target.value })} className="rounded-xl border-2 border-amber-200 bg-white p-3 font-bold text-amber-900">
            <option value="">🎓 كل الصفوف</option>
            {filterGrades.map(grade => <option key={grade} value={grade}>{grade}</option>)}
          </select>
          {isAdmin && (
            <select value={filters.teacher} onChange={(e) => setFilters({ ...filters, teacher: e.target.value })} className="rounded-xl border-2 border-amber-200 bg-white p-3 font-bold text-amber-900">
              <option value="">👨‍🏫 كل المعلمين</option>
              {filterTeachers.map(([id, name]) => <option key={id} value={id}>{name}</option>)}
            </select>
          )}
        </div>
      </div>

      {showForm && (
         <form onSubmit={handleSubmit} className="dashboard-surface flex flex-col space-y-5 border-amber-200 animate-bounce-in">
          <div className="flex flex-col gap-2 border-b border-amber-100 pb-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h3 className="text-2xl font-black text-amber-900">
                {editingVideo ? '✏️ تعديل فيديو سينما منارة' : '🎬 إضافة فيديوهات إلى سينما منارة'}
              </h3>
              <p className="mt-1 text-sm font-bold text-amber-600">
                الفيديو يظهر لكل طلاب المعلم المسؤول في الصف المختار، أيّاً كان الدرس الذي يتصفّحونه.
              </p>
            </div>
            {formData.pendingVideos.length > 0 && (
              <span className="rounded-full bg-amber-100 px-4 py-2 text-sm font-black text-amber-800">
                {formData.pendingVideos.length} فيديو جاهز للحفظ
              </span>
            )}
          </div>

          <div className="grid grid-cols-1 gap-5 md:grid-cols-2">
            <div>
              <label htmlFor="cinema-teacher" className="mb-2 block text-sm font-black text-amber-900">
                👨‍🏫 المعلم المسؤول <span className="text-red-600">*</span>
              </label>
              {isAdmin ? (
                <select
                  id="cinema-teacher"
                  value={selectedTeacherId}
                  onChange={e => {
                    e.currentTarget.setCustomValidity('');
                    setSelectedTeacherId(e.target.value);
                  }}
                  onInvalid={e => e.currentTarget.setCustomValidity('يرجى اختيار المعلم المسؤول عن الفيديو')}
                  required
                  className="w-full rounded-2xl border-[3px] border-amber-200 bg-amber-50 p-4 text-lg font-black text-amber-900 outline-none focus:border-amber-400 focus:ring-4 focus:ring-amber-100"
                >
                  <option value="">اختر المعلم</option>
                  {teachers.map(teacher => (
                    <option key={teacher.id} value={teacher.id}>👨‍🏫 {teacher.name}</option>
                  ))}
                </select>
              ) : (
                <div className="w-full rounded-2xl border-[3px] border-amber-100 bg-amber-50/60 p-4 text-lg font-black text-amber-900">
                  👨‍🏫 {teacherName || 'أنت'}
                </div>
              )}
              {isAdmin && teachers.length === 0 && !loading && (
                <p className="mt-2 text-sm font-bold text-red-600">لا يوجد معلمون مسجلون بعد لإسناد فيديو السينما.</p>
              )}
            </div>
            <div>
              <label htmlFor="cinema-grade" className="mb-2 block text-sm font-black text-amber-900">
                🎓 الصف الدراسي <span className="text-red-600">*</span>
              </label>
              <select
                id="cinema-grade"
                value={formData.gradeId}
                onChange={e => {
                  e.currentTarget.setCustomValidity('');
                  setFormData({ ...formData, gradeId: e.target.value });
                }}
                onInvalid={e => e.currentTarget.setCustomValidity('يرجى اختيار الصف الدراسي')}
                required
                disabled={isAdmin && !selectedTeacherId}
                className="w-full rounded-2xl border-[3px] border-amber-200 bg-amber-50 p-4 text-lg font-black text-amber-900 outline-none focus:border-amber-400 focus:ring-4 focus:ring-amber-100 disabled:opacity-60"
              >
                <option value="">{isAdmin && !selectedTeacherId ? 'اختر المعلم أولاً' : 'اختر الصف'}</option>
                {availableGrades.map(grade => <option key={grade} value={grade}>{grade}</option>)}
              </select>
              {ownerId && availableGrades.length === 0 && (
                <p className="mt-2 text-sm font-bold text-red-600">
                  لا توجد صفوف معرّفة لهذا المعلم. أضفها أولاً من «الإعدادات الأكاديمية».
                </p>
              )}
            </div>
          </div>

          <div className="grid grid-cols-1 gap-5 md:grid-cols-2">
            <input
              type="text"
              placeholder="عنوان الفيديو (اختياري لملفات MP4)"
              value={formData.title}
              onChange={e => setFormData({ ...formData, title: e.target.value })}
              className="rounded-2xl border-[3px] border-amber-200 bg-amber-50 p-4 font-bold outline-none focus:border-amber-400 focus:ring-4 focus:ring-amber-100"
            />
            <div className="space-y-3">
              {editingVideo ? (
                <>
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
                </>
              ) : (
                <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
                  <div className="space-y-2">
                    <label className="block text-sm font-black text-amber-800">🔗 رابط مضمن</label>
                    <input
                      type="url"
                      placeholder="https://www.youtube.com/watch?v=..."
                      value={formData.url}
                      onChange={e => setFormData({ ...formData, url: e.target.value })}
                      className="w-full rounded-2xl border-[3px] border-amber-200 bg-amber-50 p-4 font-bold outline-none focus:border-amber-400 focus:ring-4 focus:ring-amber-100"
                    />
                  </div>
                  <div className="space-y-2">
                    <label className="block text-sm font-black text-amber-800">📁 ملف فيديو MP4</label>
                    <label className="block cursor-pointer rounded-2xl border-[3px] border-dashed border-amber-300 bg-amber-50 p-4 text-center font-bold text-amber-700 transition hover:bg-amber-100">
                      <span>{formData.file?.name || 'اختر ملف MP4 بحد أقصى 500MB'}</span>
                      <input
                        type="file"
                        accept="video/mp4,.mp4"
                        className="hidden"
                        onChange={e => setFormData({ ...formData, file: e.target.files?.[0] || null })}
                      />
                    </label>
                  </div>
                </div>
              )}
            </div>
          </div>

          <textarea
            className="w-full resize-none rounded-2xl border-[3px] border-amber-200 bg-amber-50 p-4 font-bold outline-none focus:border-amber-400 focus:ring-4 focus:ring-amber-100"
            placeholder="وصف الفيديو (اختياري)"
            value={formData.description}
            onChange={e => setFormData({ ...formData, description: e.target.value })}
            rows={3}
          />

          {!editingVideo && (
            <button
              type="button"
              onClick={addCinemaVideo}
              className="w-full rounded-2xl border-2 border-amber-300 bg-amber-100 px-4 py-4 text-lg font-black text-amber-800 transition hover:bg-amber-200 active:scale-[.99]"
            >
              ➕ إضافة هذا الفيديو إلى القائمة
            </button>
          )}

          {formData.pendingVideos.length > 0 && (
            <div className="space-y-3 rounded-3xl border-2 border-amber-200 bg-amber-50/70 p-4">
              <div className="flex items-center justify-between gap-3">
                <p className="font-black text-amber-900">🎬 فيديوهات هذه الإضافة</p>
                <span className="text-xs font-bold text-amber-600">ستُحفظ كلها لنفس الصف والمعلم</span>
              </div>
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                {formData.pendingVideos.map((video, index) => (
                  <div key={video.id} className="flex items-center gap-3 rounded-2xl border border-amber-200 bg-white p-3 shadow-sm">
                    <div className="flex min-h-14 w-20 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-amber-400 via-orange-500 to-rose-500 text-2xl shadow-md">
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

          <button
            type="submit"
            disabled={saving}
            className="w-full bg-gradient-to-r from-amber-400 to-orange-500 py-4 text-xl font-black text-white rounded-2xl shadow-xl transition-all hover:scale-[1.02] hover:-translate-y-0.5 active:scale-95 disabled:opacity-60"
          >
            {saving ? '⏳ جارٍ الحفظ…' : editingVideo ? '💾 حفظ التعديل' : '💾 حفظ ونشر فيديوهات السينما'}
          </button>
        </form>
      )}

      {loadError && (
        <div className="rounded-2xl border-2 border-red-200 bg-red-50 p-4 font-bold text-red-700">
          ⚠️ {loadError}
          <button onClick={() => void loadVideos()} className="mr-3 rounded-lg bg-white px-3 py-1 text-sm text-red-700 hover:bg-red-100">إعادة المحاولة</button>
        </div>
      )}

       <div className="dashboard-card-grid dashboard-card-grid-wide dashboard-video-grid">
        {filteredVideos.map((video) => (
            <div key={video.id} className="dashboard-video-card bg-white rounded-[30px] shadow-xl border-2 border-amber-100 hover:shadow-2xl hover:-translate-y-2 transition-all group">
              <div className="relative aspect-video bg-black">
                <VideoThumbnail url={safeVideoUrl(video.url)} sourceType={video.sourceType} alt={video.title} />
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
                  {video.gradeId && <span className="px-2 py-1 bg-amber-100 text-amber-700 rounded-lg text-xs font-bold">🎓 {video.gradeId}</span>}
                  {(video.teacherName || video.teacherId) && (
                    <span className="px-2 py-1 bg-orange-100 text-orange-700 rounded-lg text-xs font-bold">👨‍🏫 {video.teacherName || video.teacherId}</span>
                  )}
                  {video.createdBy === 'admin' && <span className="px-2 py-1 bg-sky-100 text-sky-700 rounded-lg text-xs font-bold">🛡️ أضافه المشرف</span>}
                </div>
                <div className="flex gap-2">
                  <button disabled={!canManageVideos} onClick={() => beginEditingVideo(video)} className="flex-1 py-2 bg-amber-100 text-amber-700 rounded-xl font-bold hover:bg-amber-200 transition-all text-sm disabled:opacity-50">✏️ تعديل</button>
                  <button disabled={!canManageVideos} onClick={() => void handleDelete(video)} className="flex-1 py-2 bg-red-100 text-red-600 rounded-xl font-bold hover:bg-red-200 transition-all text-sm disabled:opacity-50">❌ حذف</button>
                </div>
              </div>
            </div>
        ))}
        {!loading && filteredVideos.length === 0 && (
          <div className="col-span-full p-16 bg-amber-50 rounded-[40px] border-2 border-dashed border-amber-300 text-center animate-popIn">
            <div className="text-7xl mb-6">🎬</div>
            <h3 className="text-2xl font-black text-amber-800 mb-3">لا توجد فيديوهات مطابقة للفلاتر</h3>
            <p className="text-amber-600 font-bold">جرّب تغيير الفلاتر أو أضف فيديو جديد ✓</p>
          </div>
        )}
        {loading && (
          <div className="col-span-full p-10 text-center font-black text-amber-700">⏳ جارٍ تحميل الفيديوهات…</div>
        )}
      </div>
    </div>
  );
};

export default VideoManagement;
