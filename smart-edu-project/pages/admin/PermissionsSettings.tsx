import React, { useState, useEffect } from 'react';
import { Permissions } from '../../types';
import { STORAGE_KEYS, COLORS, DEFAULT_PERMISSIONS } from '../../constants';

interface PermissionsSettingsProps {
  onUpdate?: () => void;
}

const PermissionsSettings: React.FC<PermissionsSettingsProps> = ({ onUpdate }) => {
  const [permissions, setPermissions] = useState<Permissions>(DEFAULT_PERMISSIONS);
  const [activeTab, setActiveTab] = useState<'teacher' | 'parent' | 'student'>('teacher');
  const [hasChanges, setHasChanges] = useState(false);

  useEffect(() => {
    loadPermissions();
  }, []);

  const loadPermissions = () => {
    const saved = localStorage.getItem(STORAGE_KEYS.PERMISSIONS);
    if (saved) {
      setPermissions(JSON.parse(saved));
    } else {
      // حفظ الصلاحيات الافتراضية لأول مرة
      localStorage.setItem(STORAGE_KEYS.PERMISSIONS, JSON.stringify(DEFAULT_PERMISSIONS));
      setPermissions(DEFAULT_PERMISSIONS);
    }
  };

  const handleToggle = (role: 'teacher' | 'parent' | 'student', permission: string) => {
    setPermissions(prev => ({
      ...prev,
      [role]: {
        ...prev[role],
        [permission]: !prev[role][permission as keyof typeof prev[typeof role]]
      }
    }));
    setHasChanges(true);
  };

  const handleSave = () => {
    localStorage.setItem(STORAGE_KEYS.PERMISSIONS, JSON.stringify(permissions));
    setHasChanges(false);
    alert('✅ تم حفظ الصلاحيات بنجاح!');
    if (onUpdate) onUpdate();
  };

  const handleReset = () => {
    if (confirm('هل تريد إعادة تعيين الصلاحيات إلى الوضع الافتراضي؟')) {
      setPermissions(DEFAULT_PERMISSIONS);
      setHasChanges(true);
    }
  };

  const getPermissionLabel = (key: string): string => {
    const labels: Record<string, string> = {
      // صلاحيات المعلمين
      canManageAcademicSettings: '📚 إدارة الإعدادات الأكاديمية',
      canEditGeneralSettings: '⚙️ تعديل الإعدادات العامة',
      canManageContent: '📝 إدارة المحتوى التعليمي',
      canCreateParents: '👨‍👦 إنشاء أولياء أمور',
      canEditParents: '✏️ تعديل أولياء أمور',
      canDeleteParents: '🗑️ حذف أولياء أمور',
      canCreateStudents: '👨‍🎓 إنشاء طلاب',
      canEditStudents: '✏️ تعديل طلاب',
      canDeleteStudents: '🗑️ حذف طلاب',
      canViewReports: '📊 عرض التقارير',
      canManageQuizzes: '📝 إدارة الاختبارات',
      // صلاحيات أولياء الأمور
      canChangeGrade: '🔄 تغيير الصف للطالب',
      canChatWithSupport: '💬 التواصل مع الدعم',
      // صلاحيات الطلاب
      canAccessChat: '💬 الوصول للدردشة',
      canAccessLiveMeeting: '🎥 الوصول للقاءات المباشرة',
      canRetakeQuiz: '🔄 إعادة الاختبار',
      canViewSolutions: '📖 عرض الحلول',
      canDownloadCertificates: '📜 تحميل الشهادات',
    };
    return labels[key] || key;
  };

  const getPermissionDescription = (key: string): string => {
    const descriptions: Record<string, string> = {
      canManageAcademicSettings: 'السماح للمعلم بإضافة وتعديل الصفوف والمواد والترمات والوحدات',
      canEditGeneralSettings: 'السماح للمعلم بسحب وتعديل الإعدادات الأكاديمية العامة من المشرف',
      canManageContent: 'السماح للمعلم بربط المحتوى التعليمي (فيديو، أفاتار، تمارين)',
      canCreateParents: 'السماح للمعلم بإنشاء حسابات جديدة لأولياء الأمور',
      canEditParents: 'السماح للمعلم بتعديل بيانات أولياء الأمور',
      canDeleteParents: 'السماح للمعلم بحذف حسابات أولياء الأمور',
      canCreateStudents: 'السماح بإنشاء حسابات جديدة للطلاب',
      canEditStudents: 'السماح بتعديل بيانات الطلاب',
      canDeleteStudents: 'السماح بحذف حسابات الطلاب',
      canViewReports: 'السماح بعرض التقارير والإحصائيات',
      canManageQuizzes: 'السماح للمعلم بإنشاء وتعديل الاختبارات',
      canChangeGrade: 'السماح بتغيير الصف الدراسي للطالب',
      canChatWithSupport: 'السماح بالتواصل مع الدعم الفني عبر الدردشة',
      canAccessChat: 'السماح للطالب بالوصول إلى نظام الدردشة',
      canAccessLiveMeeting: 'السماح للطالب بالانضمام للقاءات المباشرة',
      canRetakeQuiz: 'السماح للطالب بإعادة الاختبار عند الرسوب',
      canViewSolutions: 'السماح للطالب بعرض حلول التمارين',
      canDownloadCertificates: 'السماح للطالب بتحميل الشهادات والوثائق',
    };
    return descriptions[key] || '';
  };

  const renderPermissionCard = (role: 'teacher' | 'parent' | 'student') => {
    const rolePermissions = permissions[role];
    const roleLabels = {
      teacher: '👨‍🏫 صلاحيات المعلمين',
      parent: '👨‍👦 صلاحيات أولياء الأمور',
      student: '👨‍🎓 صلاحيات الطلاب',
    };

    return (
      <div style={styles.permissionsGrid}>
        {Object.entries(rolePermissions).map(([key, value]) => (
          <div key={key} style={styles.permissionCard}>
            <div style={styles.permissionHeader}>
              <div style={styles.permissionInfo}>
                <h4 style={styles.permissionTitle}>{getPermissionLabel(key)}</h4>
                <p style={styles.permissionDescription}>{getPermissionDescription(key)}</p>
              </div>
              <label style={styles.switchContainer}>
                <input
                  type="checkbox"
                  checked={value as boolean}
                  onChange={() => handleToggle(role, key)}
                  style={styles.switchInput}
                />
                <span style={{
                  ...styles.switchSlider,
                  backgroundColor: value ? COLORS.success : '#cbd5e1'
                }}></span>
              </label>
            </div>
          </div>
        ))}
      </div>
    );
  };

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <div>
          <h1 style={styles.title}>🔐 إدارة الصلاحيات</h1>
          <p style={styles.subtitle}>تحكم في صلاحيات المعلمين وأولياء الأمور والطلاب</p>
        </div>
        <div style={styles.headerActions}>
          <button onClick={handleReset} style={styles.resetButton}>
            🔄 إعادة تعيين
          </button>
          {hasChanges && (
            <button onClick={handleSave} style={styles.saveButton}>
              💾 حفظ التغييرات
            </button>
          )}
        </div>
      </div>

      <div style={styles.infoCard}>
        <div style={styles.infoIcon}>ℹ️</div>
        <div>
          <h3 style={styles.infoTitle}>ملاحظة هامة</h3>
          <p style={styles.infoText}>
            المشرف يمتلك جميع الصلاحيات بشكل دائم ولا يمكن تقييده. الصلاحيات المعروضة هنا تطبق فقط على المعلمين وأولياء الأمور والطلاب.
          </p>
        </div>
      </div>

      <div style={styles.tabsContainer}>
        <button
          onClick={() => setActiveTab('teacher')}
          style={{
            ...styles.tab,
            ...(activeTab === 'teacher' ? styles.activeTab : {})
          }}
        >
          👨‍🏫 المعلمين
        </button>
        <button
          onClick={() => setActiveTab('parent')}
          style={{
            ...styles.tab,
            ...(activeTab === 'parent' ? styles.activeTab : {})
          }}
        >
          👨‍👦 أولياء الأمور
        </button>
        <button
          onClick={() => setActiveTab('student')}
          style={{
            ...styles.tab,
            ...(activeTab === 'student' ? styles.activeTab : {})
          }}
        >
          👨‍🎓 الطلاب
        </button>
      </div>

      <div style={styles.content}>
        {renderPermissionCard(activeTab)}
      </div>

      <div style={styles.statsCard}>
        <div style={styles.stat}>
          <div style={styles.statValue}>{Object.values(permissions.teacher).filter(Boolean).length}</div>
          <div style={styles.statLabel}>صلاحيات المعلمين المفعلة</div>
        </div>
        <div style={styles.stat}>
          <div style={styles.statValue}>{Object.values(permissions.parent).filter(Boolean).length}</div>
          <div style={styles.statLabel}>صلاحيات أولياء الأمور المفعلة</div>
        </div>
        <div style={styles.stat}>
          <div style={styles.statValue}>{Object.values(permissions.student).filter(Boolean).length}</div>
          <div style={styles.statLabel}>صلاحيات الطلاب المفعلة</div>
        </div>
      </div>
    </div>
  );
};

const styles: Record<string, React.CSSProperties> = {
  container: {
    padding: '40px',
    maxWidth: '1400px',
    margin: '0 auto',
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: '40px',
    flexWrap: 'wrap',
    gap: '20px',
  },
  title: {
    fontSize: '42px',
    fontWeight: '900',
    color: '#1e293b',
    marginBottom: '10px',
  },
  subtitle: {
    fontSize: '18px',
    color: '#64748b',
    fontWeight: 'bold',
  },
  headerActions: {
    display: 'flex',
    gap: '15px',
    alignItems: 'center',
  },
  resetButton: {
    padding: '14px 28px',
    backgroundColor: '#f1f5f9',
    border: 'none',
    borderRadius: '15px',
    fontSize: '16px',
    fontWeight: 'bold',
    color: '#475569',
    cursor: 'pointer',
    transition: 'all 0.3s',
  },
  saveButton: {
    padding: '14px 28px',
    backgroundColor: COLORS.success,
    border: 'none',
    borderRadius: '15px',
    fontSize: '16px',
    fontWeight: 'bold',
    color: 'white',
    cursor: 'pointer',
    transition: 'all 0.3s',
    boxShadow: '0 4px 20px rgba(16, 185, 129, 0.3)',
  },
  infoCard: {
    backgroundColor: '#dbeafe',
    padding: '25px',
    borderRadius: '20px',
    marginBottom: '30px',
    display: 'flex',
    gap: '20px',
    alignItems: 'flex-start',
  },
  infoIcon: {
    fontSize: '32px',
  },
  infoTitle: {
    fontSize: '18px',
    fontWeight: 'bold',
    color: '#1e40af',
    marginBottom: '8px',
  },
  infoText: {
    fontSize: '15px',
    color: '#1e40af',
    lineHeight: '1.6',
  },
  tabsContainer: {
    display: 'flex',
    gap: '10px',
    marginBottom: '30px',
    backgroundColor: '#f8fafc',
    padding: '8px',
    borderRadius: '20px',
  },
  tab: {
    flex: 1,
    padding: '16px 24px',
    backgroundColor: 'transparent',
    border: 'none',
    borderRadius: '15px',
    fontSize: '18px',
    fontWeight: 'bold',
    color: '#64748b',
    cursor: 'pointer',
    transition: 'all 0.3s',
  },
  activeTab: {
    backgroundColor: 'white',
    color: COLORS.primary,
    boxShadow: '0 2px 10px rgba(0,0,0,0.05)',
  },
  content: {
    backgroundColor: 'white',
    padding: '40px',
    borderRadius: '25px',
    boxShadow: '0 2px 20px rgba(0,0,0,0.05)',
    marginBottom: '30px',
  },
  permissionsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fill, minmax(450px, 1fr))',
    gap: '20px',
  },
  permissionCard: {
    backgroundColor: '#f8fafc',
    padding: '20px',
    borderRadius: '15px',
    transition: 'all 0.3s',
  },
  permissionHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: '20px',
  },
  permissionInfo: {
    flex: 1,
  },
  permissionTitle: {
    fontSize: '16px',
    fontWeight: 'bold',
    color: '#1e293b',
    marginBottom: '6px',
  },
  permissionDescription: {
    fontSize: '13px',
    color: '#64748b',
    lineHeight: '1.5',
  },
  switchContainer: {
    position: 'relative',
    display: 'inline-block',
    width: '60px',
    height: '32px',
    flexShrink: 0,
  },
  switchInput: {
    opacity: 0,
    width: 0,
    height: 0,
  },
  switchSlider: {
    position: 'absolute',
    cursor: 'pointer',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    borderRadius: '34px',
    transition: 'all 0.3s',
  },
  statsCard: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))',
    gap: '20px',
  },
  stat: {
    backgroundColor: 'white',
    padding: '30px',
    borderRadius: '20px',
    textAlign: 'center',
    boxShadow: '0 2px 15px rgba(0,0,0,0.05)',
  },
  statValue: {
    fontSize: '48px',
    fontWeight: '900',
    color: COLORS.primary,
    marginBottom: '10px',
  },
  statLabel: {
    fontSize: '15px',
    color: '#64748b',
    fontWeight: 'bold',
  },
};

export default PermissionsSettings;
