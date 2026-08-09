import React, { useState, useEffect } from 'react';
import { STORAGE_KEYS } from '../../constants';
import { playLamsaSound } from '../../utils/sounds';
import { HierarchicalConfig } from '../../types';
import { getRecordTeacherId, normalizeScopeValue } from '../../utils/scope';

interface VideoRecord {
  id: string;
  title: string;
  description: string;
  url: string;
  grade: string;
  atram: string;
  subject: string;
  term: string;
  unit: string;
  createdBy: string;
  teacherName: string;
  createdAt: string;
}

interface VideoManagementProps {
  teacherId: string;
  teacherName: string;
}

const VideoManagement: React.FC<VideoManagementProps> = ({ teacherId, teacherName }) => {
  const [videos, setVideos] = useState<VideoRecord[]>([]);
  const [academicConfigs, setAcademicConfigs] = useState<HierarchicalConfig[]>([]);
  const [filters, setFilters] = useState({ grade: '', atram: '', subject: '', term: '', unit: '' });
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({
    title: '', description: '', url: '', grade: '', subject: '', term: '', unit: ''
  });
  const [editingVideo, setEditingVideo] = useState<VideoRecord | null>(null);

  useEffect(() => {
    loadVideos();
    loadAcademicConfigs();
  }, [teacherId]);

  const loadVideos = () => {
    const saved = localStorage.getItem(STORAGE_KEYS.VIDEOS);
    if (saved) {
      const all = JSON.parse(saved);
       setVideos(all.filter((v: VideoRecord) => getRecordTeacherId(v) === normalizeScopeValue(teacherId)));
    }
  };

  const loadAcademicConfigs = () => {
    const allConfigs: HierarchicalConfig[] = JSON.parse(
      localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]',
    );
    setAcademicConfigs(allConfigs.filter(config => getRecordTeacherId(config) === normalizeScopeValue(teacherId)));
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

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (
      !formData.title.trim() ||
      !formData.url.trim() ||
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

    if (editingVideo) {
      const updated = all.map(v => v.id === editingVideo.id ? { ...v, ...formData } : v);
      localStorage.setItem(STORAGE_KEYS.VIDEOS, JSON.stringify(updated));
      setEditingVideo(null);
    } else {
      const newVideo: VideoRecord = {
        id: Date.now().toString(),
        ...formData,
        createdBy: teacherId,
        teacherName,
        createdAt: new Date().toISOString(),
      };
      all.push(newVideo);
      localStorage.setItem(STORAGE_KEYS.VIDEOS, JSON.stringify(all));

      // 🔔 إشعار للمشرف
      const notifs = JSON.parse(localStorage.getItem(STORAGE_KEYS.VIDEO_NOTIFICATIONS) || '[]');
      notifs.push({
        id: Date.now().toString(),
        type: 'new_video',
        message: `🎬 أضاف المعلم ${teacherName} فيديو جديد: "${formData.title}" (${formData.grade} • ${formData.atram} • ${formData.subject} • ${formData.term} • ${formData.unit})`,
        teacherId,
        teacherName,
        videoId: newVideo.id,
        videoTitle: newVideo.title,
        grade: newVideo.grade,
        atram: formData.atram,
        subject: newVideo.subject,
        term: newVideo.term,
        unit: newVideo.unit,
        createdAt: new Date().toISOString(),
        read: false,
      });
      localStorage.setItem(STORAGE_KEYS.VIDEO_NOTIFICATIONS, JSON.stringify(notifs));
    }

    setFormData({ title: '', description: '', url: '', grade: '', subject: '', term: '', unit: '' });
    setShowForm(false);
    loadVideos();
    playLamsaSound('success');
  };

  const handleDelete = (id: string) => {
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
      loadVideos();
      playLamsaSound('pop');
    }
  };

  const extractVideoId = (url: string) => {
    const regExp = /^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*/;
    const match = url.match(regExp);
    return (match && match[2].length === 11) ? match[2] : null;
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
          <h2 className="text-4xl font-black text-amber-800">🎬 إدارة الفيديوهات</h2>
          <p className="text-amber-500 font-medium mt-1">أضف فيديوهات تعليمية لطلابك</p>
        </div>
        <button
          onClick={() => { setShowForm(!showForm); setEditingVideo(null); playLamsaSound('click'); }}
          className="px-6 py-3 bg-gradient-to-r from-amber-400 to-orange-500 text-white rounded-2xl font-black shadow-xl hover:scale-105 transition-all active:scale-95"
        >
          {showForm ? '❌ إلغاء' : '➕ فيديو جديد'}
        </button>
      </div>

      <div className="rounded-2xl border-2 border-amber-200 bg-amber-50/80 p-4">
        <div className="mb-3 flex items-center justify-between">
          <h3 className="text-lg font-black text-amber-800">🔎 فلترة الفيديوهات</h3>
          <button
            onClick={() => setFilters({ grade: '', atram: '', subject: '', term: '', unit: '' })}
            className="rounded-lg bg-white px-3 py-1 text-xs font-bold text-amber-700 hover:bg-amber-100"
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
        <form onSubmit={handleSubmit} className="bg-white p-8 rounded-[30px] shadow-xl border-2 border-amber-200 animate-bounce-in space-y-5">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            <input
              type="text" placeholder="عنوان الفيديو"
              value={formData.title}
              onChange={e => setFormData({ ...formData, title: e.target.value })}
              className="p-4 bg-amber-50 border-[3px] border-amber-200 rounded-2xl font-bold focus:border-amber-400 focus:ring-4 focus:ring-amber-100 outline-none"
              required
            />
            <input
              type="url" placeholder="رابط يوتيوب"
              value={formData.url}
              onChange={e => setFormData({ ...formData, url: e.target.value })}
              className="p-4 bg-amber-50 border-[3px] border-amber-200 rounded-2xl font-bold focus:border-amber-400 focus:ring-4 focus:ring-amber-100 outline-none"
              required
            />
          </div>
          <textarea
            placeholder="وصف الفيديو (u062eu062au064au0627رu064a)"
            value={formData.description}
            onChange={e => setFormData({ ...formData, description: e.target.value })}
            className="w-full p-4 bg-amber-50 border-[3px] border-amber-200 rounded-2xl font-bold focus:border-amber-400 focus:ring-4 focus:ring-amber-100 outline-none resize-none"
            rows={3}
          />
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
          <button type="submit" className="w-full bg-gradient-to-r from-amber-400 to-orange-500 text-white py-4 rounded-2xl font-black text-xl shadow-xl hover:scale-[1.02] hover:-translate-y-0.5 transition-all active:scale-95 animate-pulse-glow">
            {editingVideo ? '💾 حفظ التعديل' : '✨ إضافة الفيديو'}
          </button>
        </form>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {filteredVideos.map((video) => {
          const vid = extractVideoId(video.url);
          return (
            <div key={video.id} className="bg-white rounded-[30px] shadow-xl border-2 border-amber-100 overflow-hidden hover:shadow-2xl hover:-translate-y-2 transition-all group">
              {vid ? (
                <div className="relative aspect-video">
                  <img src={`https://img.youtube.com/vi/${vid}/mqdefault.jpg`} alt={video.title} className="w-full h-full object-cover" />
                  <div className="absolute inset-0 bg-black/40 flex items-center justify-center group-hover:bg-black/30 transition-all">
                    <div className="w-16 h-16 rounded-full bg-white/90 flex items-center justify-center shadow-xl group-hover:scale-110 transition-transform">
                      <span className="text-3xl">▶️</span>
                    </div>
                  </div>
                </div>
              ) : (
                <div className="aspect-video bg-amber-50 flex items-center justify-center">
                  <span className="text-5xl">🎬</span>
                </div>
              )}
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
                  <button onClick={() => { setEditingVideo(video); setFormData({ title: video.title, description: video.description, url: video.url, grade: video.grade, subject: video.subject, term: video.term, unit: video.unit }); setShowForm(true); playLamsaSound('click'); }} className="flex-1 py-2 bg-amber-100 text-amber-700 rounded-xl font-bold hover:bg-amber-200 transition-all text-sm">✏️ تعديل</button>
                  <button onClick={() => handleDelete(video.id)} className="flex-1 py-2 bg-red-100 text-red-600 rounded-xl font-bold hover:bg-red-200 transition-all text-sm">❌ حذف</button>
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
