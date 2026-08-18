import React from 'react';
import ContentManagement from '../admin/ContentManagement';
import { getTeacherPermissions } from '../../permissions';

interface TeacherContentManagementProps {
  teacherId: string;
  teacherName: string;
  permissionPackageId?: string;
}

const TeacherContentManagement: React.FC<TeacherContentManagementProps> = ({ teacherId, teacherName, permissionPackageId }) => {
  // فحص الصلاحية
  const canManageContent = getTeacherPermissions({ permissionPackageId }).canManageContent;

  if (!canManageContent) {
    return (
      <div style={styles.noPermissionContainer}>
        <div style={styles.noPermissionIcon}>🔒</div>
        <h2 style={styles.noPermissionTitle}>لا توجد صلاحية</h2>
        <p style={styles.noPermissionText}>
          عذراً، ليس لديك صلاحية الوصول إلى إدارة المحتوى التعليمي.
          <br />
          يرجى التواصل مع المشرف للحصول على الصلاحيات اللازمة.
        </p>
      </div>
    );
  }

  // استخدام نفس مكون ContentManagement مع تمرير معلومات المعلم
  return <ContentManagement onUpdate={() => {}} teacherId={teacherId} teacherName={teacherName} permissionPackageId={permissionPackageId} />;
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

export default TeacherContentManagement;
