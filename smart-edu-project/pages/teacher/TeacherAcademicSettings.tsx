
// نفس محتوى AcademicSettings.tsx ولكن مع إضافة teacherId لكل إعداد يتم إنشاؤه
import React, { useState, useEffect } from 'react';
import AcademicSettings from '../admin/AcademicSettings';
import { STORAGE_KEYS } from '../../constants';
import { TeacherInfo } from '../../types';
import { getTeacherPermissions } from '../../permissions';

interface TeacherAcademicSettingsProps {
  teacherId: string;
}

const TeacherAcademicSettings: React.FC<TeacherAcademicSettingsProps> = ({ teacherId }) => {
  const [teacherName, setTeacherName] = useState('');

  useEffect(() => {
    const teachers: TeacherInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.TEACHERS) || '[]');
    const teacher = teachers.find(t => t.id === teacherId);
    if (teacher) {
      setTeacherName(teacher.name);
    }
  }, [teacherId]);

  // فحص الصلاحية
  const teacher = (() => {
    try {
      const teachers: TeacherInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.TEACHERS) || '[]');
      return teachers.find(item => item.id === teacherId) || null;
    } catch {
      return null;
    }
  })();
  const canManageAcademicSettings = getTeacherPermissions(teacher).canManageAcademicSettings;

  if (!canManageAcademicSettings) {
    return (
      <div style={styles.noPermissionContainer}>
        <div style={styles.noPermissionIcon}>🔒</div>
        <h2 style={styles.noPermissionTitle}>لا توجد صلاحية</h2>
        <p style={styles.noPermissionText}>
          عذراً، ليس لديك صلاحية الوصول إلى الإعدادات الأكاديمية.
          <br />
          يرجى التواصل مع المشرف للحصول على الصلاحيات اللازمة.
        </p>
      </div>
    );
  }

  return <AcademicSettings onUpdate={() => {}} teacherId={teacherId} teacherName={teacherName} />;
};

const styles: Record<string, React.CSSProperties> = {
  noPermissionContainer: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: '60vh',
    textAlign: 'center',
    padding: '40px',
  },
  noPermissionIcon: {
    fontSize: '120px',
    marginBottom: '30px',
    opacity: 0.5,
  },
  noPermissionTitle: {
    fontSize: '32px',
    fontWeight: 'bold',
    color: '#1e293b',
    marginBottom: '15px',
  },
  noPermissionText: {
    fontSize: '18px',
    color: '#64748b',
    lineHeight: '1.8',
    maxWidth: '600px',
  },
};

export default TeacherAcademicSettings;
