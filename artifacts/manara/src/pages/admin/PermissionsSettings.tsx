import React, { useState, useEffect } from 'react';
import { Permissions } from '../../types';
import { STORAGE_KEYS, COLORS, DEFAULT_PERMISSIONS } from '../../constants';
import { getPermissions } from '../../permissions';

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
    // Normalize legacy settings so newly added toggles and limits are always visible.
    const normalized = getPermissions();
    localStorage.setItem(STORAGE_KEYS.PERMISSIONS, JSON.stringify(normalized));
    setPermissions(normalized);
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
      canManageVideos: '🎬 إدارة الفيديوهات',
      canCreateParents: '👨‍👦 إنشاء أولياء أمور',
      canEditParents: '✏️ تعديل أولياء أمور',
      canDeleteParents: '🗑️ حذف أولياء أمور',
      canManageParentPermissions: '🔐 منح صلاحيات مخصصة لولي الأمر',
      canCreatePermissionPackages: '🔐 إنشاء بكجات صلاحيات',
      canCreateStudents: '👨‍🎓 إنشاء طلاب',
      canEditStudents: '✏️ تعديل طلاب',
      canDeleteStudents: '🗑️ حذف طلاب',
      canViewReports: '📊 عرض التقارير',
      canManageQuizzes: '📝 إدارة الاختبارات',
      // صلاحيات أولياء الأمور
      canResetStudentPassword: '🔑 إعادة تعيين كلمة مرور الأبناء',
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
      canManageVideos: 'السماح للمعلم بإضافة وتعديل وحذف الفيديوهات',
      canCreateParents: 'السماح للمعلم بإنشاء حسابات جديدة لأولياء الأمور',
      canEditParents: 'السماح للمعلم بتعديل بيانات أولياء الأمور',
      canDeleteParents: 'السماح للمعلم بحذف حسابات أولياء الأمور',
      canManageParentPermissions: 'السماح للمعلم بتحديد الصلاحيات الخاصة بكل ولي أمر',
      canCreatePermissionPackages: 'السماح بإنشاء وتعديل وإسناد بكجات صلاحيات ضمن النطاق المسموح',
      canCreateStudents: 'السماح بإنشاء حسابات جديدة للطلاب',
      canEditStudents: 'السماح بتعديل بيانات الطلاب',
      canDeleteStudents: 'السماح بحذف حسابات الطلاب',
      canResetStudentPassword: 'السماح لولي الأمر بتغيير كلمة مرور أحد أبنائه',
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

  const limitLabels: Record<string, string> = {
    maxParents: 'الحد الأقصى لأولياء الأمور',
    maxStudents: 'الحد الأقصى للطلاب/الأبناء',
    maxContent: 'الحد الأقصى للمحتوى التعليمي',
    maxVideos: 'الحد الأقصى للفيديوهات',
    maxStorageMb: 'مساحة الفيديوهات بالميجابايت',
  };

  const limitDescriptions: Record<string, string> = {
    maxParents: 'عدد الحسابات التي يستطيع المعلم إنشاؤها. استخدم -1 لغير محدود.',
    maxStudents: 'للمعلم: إجمالي الطلاب. لولي الأمر: عدد الأبناء. استخدم -1 لغير محدود.',
    maxContent: 'عدد الدروس التي يستطيع المعلم إضافتها. استخدم -1 لغير محدود.',
    maxVideos: 'عدد الفيديوهات التي يستطيع المعلم إضافتها. استخدم -1 لغير محدود.',
    maxStorageMb: 'الحجم التقريبي لبيانات وروابط الفيديوهات. استخدم -1 لغير محدود.',
  };

  const handleLimitChange = (role: 'teacher' | 'parent', key: string, value: string) => {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) return;
    setPermissions(prev => ({
      ...prev,
      [role]: {
        ...prev[role],
        [key]: Math.max(-1, Math.floor(parsed)),
      },
    }));
    setHasChanges(true);
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
        {Object.entries(rolePermissions)
          .filter(([, value]) => typeof value === 'boolean')
          .map(([key, value]) => (
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

  const renderLimitCards = (role: 'teacher' | 'parent') => {
    const rolePermissions = permissions[role] as unknown as Record<string, unknown>;
    const keys = role === 'teacher'
      ? ['maxParents', 'maxStudents', 'maxContent', 'maxVideos', 'maxStorageMb']
      : ['maxStudents'];

    return (
      <div style={styles.limitsSection}>
        <div style={styles.limitsHeader}>
          <h3 style={styles.limitsTitle}>📏 الحدود العددية والمساحة</h3>
          <p style={styles.limitsHint}>القيمة -1 تعني غير محدود</p>
        </div>
        <div style={styles.limitsGrid}>
          {keys.map(key => (
            <div key={key} style={styles.limitCard}>
              <label style={styles.limitLabel}>{limitLabels[key]}</label>
              <p style={styles.limitDescription}>{limitDescriptions[key]}</p>
              <input
                type="number"
                min="-1"
                step="1"
                value={Number(rolePermissions[key] ?? -1)}
                onChange={e => handleLimitChange(role, key, e.target.value)}
                style={styles.limitInput}
              />
            </div>
          ))}
        </div>
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
          <button
            onClick={handleSave}
            style={{
              ...styles.saveButton,
              ...(hasChanges ? {} : styles.saveButtonIdle),
            }}
            title={hasChanges ? 'حفظ التعديلات في قاعدة البيانات' : 'لا توجد تعديلات جديدة'}
          >
            💾 حفظ التغييرات
          </button>
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
        {(activeTab === 'teacher' || activeTab === 'parent') && renderLimitCards(activeTab)}
      </div>

      <div style={styles.statsCard}>
        <div style={styles.stat}>
          <div style={styles.statValue}>{Object.values(permissions.teacher).filter(value => typeof value === 'boolean' && value).length}</div>
          <div style={styles.statLabel}>صلاحيات المعلمين المفعلة</div>
        </div>
        <div style={styles.stat}>
          <div style={styles.statValue}>{Object.values(permissions.parent).filter(value => typeof value === 'boolean' && value).length}</div>
          <div style={styles.statLabel}>صلاحيات أولياء الأمور المفعلة</div>
        </div>
        <div style={styles.stat}>
          <div style={styles.statValue}>{Object.values(permissions.student).filter(value => typeof value === 'boolean' && value).length}</div>
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
  saveButtonIdle: {
    backgroundColor: '#94a3b8',
    boxShadow: 'none',
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
  limitsSection: {
    marginTop: '30px',
    paddingTop: '28px',
    borderTop: '2px solid #e2e8f0',
  },
  limitsHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'baseline',
    gap: '15px',
    marginBottom: '18px',
    flexWrap: 'wrap',
  },
  limitsTitle: {
    fontSize: '21px',
    fontWeight: '900',
    color: '#1e293b',
  },
  limitsHint: {
    fontSize: '13px',
    color: '#64748b',
    fontWeight: 'bold',
  },
  limitsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
    gap: '15px',
  },
  limitCard: {
    backgroundColor: '#f8fafc',
    border: '1px solid #e2e8f0',
    borderRadius: '15px',
    padding: '16px',
  },
  limitLabel: {
    display: 'block',
    fontSize: '14px',
    fontWeight: '900',
    color: '#334155',
    marginBottom: '7px',
  },
  limitDescription: {
    fontSize: '12px',
    color: '#64748b',
    lineHeight: '1.5',
    minHeight: '38px',
    marginBottom: '10px',
  },
  limitInput: {
    width: '100%',
    padding: '10px 12px',
    border: '2px solid #cbd5e1',
    borderRadius: '10px',
    fontSize: '16px',
    fontWeight: '900',
    color: '#0f172a',
    outline: 'none',
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
