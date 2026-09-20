import React, { useState } from 'react';

/**
 * شجرة الإعدادات الأكاديمية: مكوّن واحد تعرضه لوحة المشرف ولوحة المعلم.
 *
 * كانت كل شاشة ترسم الشجرة بنفسها بأنماط inline خاصة بها، فتباعدت
 * الشاشتان: بطاقات بألوان مختلفة، وزرّا الصف في المشرف تحت العنوان لا
 * بجانبه، وحذفٌ بعلامة «✖» رمادية بدل سلّة حمراء. وأي إصلاح في واحدة لا
 * يصل الأخرى. الشجرة الآن هنا وحدها: ما يتغيّر فيها يظهر في اللوحتين
 * معاً، ولا سبيل لأن تفترقا من جديد.
 *
 * المسارات تُمرَّر بالفهرس والاسم معاً (`GradeNode` وما يبنى عليها): لوحة
 * المشرف تخاطب شجرتها بالفهارس ولوحة المعلم بالأسماء، فيأخذ كلٌّ ما يلزمه
 * من العقدة نفسها بلا تحويل.
 *
 * والحالة المؤقتة للتحرير — أي عقدة مفتوحة، ومسوّدة كل حقل درس — تسكن
 * داخل المكوّن، فلا تتكرّر في الشاشتين. أما الحفظ فيبقى عند صاحب البيانات:
 * المكوّن ينادي `onRename*` و`onDelete*` و`onAddLesson`، وكلٌّ يكتب في
 * شجرته ويزامنها إلى Supabase كما يفعل اليوم.
 */

export type GradeNode = { gradeIndex: number; grade: string };
export type SubjectNode = GradeNode & { subjectIndex: number; subject: string };
export type TermNode = SubjectNode & { termIndex: number; term: string };
export type UnitNode = TermNode & { unitIndex: number; unit: string };
export type LessonNode = UnitNode & { lessonIndex: number; lesson: string };

/** فصل دراسي كما تقرأه الشجرة: وحدات، ودروس مفهرسة باسم الوحدة. */
type TermShape = {
  term: string;
  units?: string[];
  lessons?: Record<string, string[]>;
};

// الشجرة تُمرَّر كما هي من كل لوحة، ولكل لوحة نوعها الخاص لـ
// `HierarchicalConfig`. المكوّن لا يقرأ منها إلا `grade` و`subjects`،
// فيقبلها كما جاءت بدل أن يفرض شكلاً يُجبر اللوحتين على التحويل.
export type AcademicTreeViewerProps = {
  /** الشجرة كاملة. الفهارس المُمرَّرة في العقد فهارس هذه المصفوفة. */
  configs: any[];
  /** هل يمرّ هذا الصف من التصفية والبحث؟ */
  gradeShown: (config: any, gradeIndex: number) => boolean;
  /** المواد الظاهرة بعد التصفية، محتفظةً بفهرسها الأصلي. */
  subjectEntries: (
    config: any,
    gradeIndex: number,
  ) => { subject: any; subjectIndex: number }[];
  isCollapsed: (config: any, gradeIndex: number) => boolean;
  onToggleGrade: (config: any, gradeIndex: number) => void;
  /** شارات إضافية بجانب اسم الصف (اسم المالك مثلاً في لوحة المشرف). */
  gradeBadges?: (config: any, gradeIndex: number) => React.ReactNode;
  /** صفٌّ لا يملك المستخدم حذفه يُعرض زرّه معطّلاً لا مخفياً. */
  canDeleteGrade?: (config: any, gradeIndex: number) => boolean;

  onRenameGrade: (node: GradeNode, name: string) => void;
  onRenameSubject: (node: SubjectNode, name: string) => void;
  onRenameTerm: (node: TermNode, name: string) => void;
  onRenameUnit: (node: UnitNode, name: string) => void;
  onRenameLesson: (node: LessonNode, name: string) => void;

  onDeleteGrade: (node: GradeNode) => void;
  onDeleteSubject: (node: SubjectNode) => void;
  onDeleteTerm: (node: TermNode) => void;
  onDeleteUnit: (node: UnitNode) => void;
  onDeleteLesson: (node: LessonNode) => void;

  /** إضافة درس من داخل بطاقة الوحدة. يُعيد true إن قُبل، فيُفرَّغ الحقل. */
  onAddLesson: (node: UnitNode, name: string) => boolean | void;

  /** ما يُعرض حين لا يوجد صف أصلاً، وحين تُخفي التصفية كل الصفوف. */
  emptyState: React.ReactNode;
  noMatchState?: React.ReactNode;
};

const lessonsOf = (term: TermShape, unit: string): string[] => term.lessons?.[unit] ?? [];

const countUnits = (config: any): number =>
  (config.subjects || []).reduce(
    (total: number, subject: any) =>
      total +
      (subject.terms || []).reduce(
        (sum: number, term: any) => sum + (term.units || []).length,
        0,
      ),
    0,
  );

const AcademicTreeViewer: React.FC<AcademicTreeViewerProps> = ({
  configs,
  gradeShown,
  subjectEntries,
  isCollapsed,
  onToggleGrade,
  gradeBadges,
  canDeleteGrade,
  onRenameGrade,
  onRenameSubject,
  onRenameTerm,
  onRenameUnit,
  onRenameLesson,
  onDeleteGrade,
  onDeleteSubject,
  onDeleteTerm,
  onDeleteUnit,
  onDeleteLesson,
  onAddLesson,
  emptyState,
  noMatchState,
}) => {
  // العقدة المفتوحة للتحرير، واحدة في كل مرة. مفتاحها نوعها ومسارها
  // الكامل، فلا يلتبس فصلان يحملان الاسم نفسه في مادتين مختلفتين.
  const [editingNode, setEditingNode] = useState<{ key: string; value: string } | null>(null);
  const [editingLesson, setEditingLesson] = useState<
    { key: string; index: number; value: string } | null
  >(null);
  const [lessonDrafts, setLessonDrafts] = useState<Record<string, string>>({});

  const keyOf = (kind: string, ...parts: (string | number)[]) =>
    `${kind}:${parts.join('|')}`;

  /**
   * اسم العقدة: نصاً عادياً، أو مربع إدخال حين تكون هذه العقدة قيد التحرير.
   *
   * دالة تُعيد JSX لا مكوّناً متداخلاً عن قصد: المكوّن المعرَّف داخل الـ
   * render يكون نوعاً جديداً في كل تمريرة، فيُفكّك React المدخل ويعيد
   * تركيبه مع كل حرف ويضيع التركيز.
   */
  const renderNodeName = (
    key: string,
    name: string,
    labelStyle: React.CSSProperties,
    icon: string,
    onSave: (value: string) => void,
  ): React.ReactNode => {
    if (editingNode?.key !== key) {
      return <span style={labelStyle}>{icon} {name}</span>;
    }
    const commit = () => {
      const value = editingNode.value.trim();
      setEditingNode(null);
      if (value && value !== name) onSave(value);
    };
    return (
      <span style={{ display: 'flex', alignItems: 'center', gap: '4px', flex: 1 }}>
        <input
          type="text"
          autoFocus
          value={editingNode.value}
          onChange={e =>
            setEditingNode(current => (current ? { ...current, value: e.target.value } : current))
          }
          onKeyDown={e => {
            if (e.key === 'Enter') {
              e.preventDefault();
              commit();
            }
            if (e.key === 'Escape') setEditingNode(null);
          }}
          style={styles.nodeInput}
        />
        <button onClick={commit} style={styles.tinyEditButton} title="حفظ">✅</button>
        <button onClick={() => setEditingNode(null)} style={styles.tinyDeleteButton} title="إلغاء">
          ↩️
        </button>
      </span>
    );
  };

  const openEdit = (key: string, value: string) => setEditingNode({ key, value });

  if (configs.length === 0) return <>{emptyState}</>;

  const shownGrades = configs
    .map((config, gradeIndex) => ({ config, gradeIndex }))
    .filter(entry => gradeShown(entry.config, entry.gradeIndex));

  if (shownGrades.length === 0) return <>{noMatchState ?? emptyState}</>;

  return (
    <>
      {shownGrades.map(({ config, gradeIndex }) => {
        const gradeNode: GradeNode = { gradeIndex, grade: config.grade };
        const gradeKey = keyOf('grade', gradeIndex, config.grade);
        const collapsed = isCollapsed(config, gradeIndex);
        const deletable = canDeleteGrade ? canDeleteGrade(config, gradeIndex) : true;

        return (
          <div key={gradeKey} style={styles.configCard}>
            <div style={styles.cardHeader}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
                <button
                  onClick={() => onToggleGrade(config, gradeIndex)}
                  style={styles.treeToggle}
                  title={collapsed ? 'فتح الصف' : 'طيّ الصف'}
                  aria-expanded={!collapsed}
                >
                  {collapsed ? '▶' : '▼'}
                </button>
                {renderNodeName(gradeKey, config.grade, styles.configTitle, '🏫', name =>
                  onRenameGrade(gradeNode, name),
                )}
                <span style={styles.treeCountBadge}>
                  {(config.subjects || []).length} مادة · {countUnits(config)} وحدة
                </span>
                {gradeBadges?.(config, gradeIndex)}
              </div>
              <div style={{ display: 'flex', gap: '8px' }}>
                <button
                  onClick={() => openEdit(gradeKey, config.grade)}
                  style={styles.editButton}
                  title="تعديل الصف"
                >
                  ✏️
                </button>
                <button
                  onClick={() => onDeleteGrade(gradeNode)}
                  style={deletable ? styles.deleteButton : styles.deleteButtonDisabled}
                  disabled={!deletable}
                  title={deletable ? 'حذف الصف' : 'هذا الصف ليس من إعداداتك'}
                >
                  🗑️
                </button>
              </div>
            </div>

            {collapsed ? null : subjectEntries(config, gradeIndex).length === 0 ? (
              <div style={styles.noUnitsHint}>لا توجد مواد في هذا الصف.</div>
            ) : (
              subjectEntries(config, gradeIndex).map(({ subject, subjectIndex }) => {
                const subjectNode: SubjectNode = {
                  ...gradeNode,
                  subjectIndex,
                  subject: subject.subject,
                };
                const subjectKey = keyOf('subject', gradeIndex, subjectIndex, subject.subject);
                return (
                  <div key={subjectKey} style={styles.subjectCard}>
                    <div style={styles.cardHeaderTight}>
                      {renderNodeName(subjectKey, subject.subject, styles.subjectTitle, '📖', name =>
                        onRenameSubject(subjectNode, name),
                      )}
                      <div style={{ display: 'flex', gap: '6px' }}>
                        <button
                          onClick={() => openEdit(subjectKey, subject.subject)}
                          style={styles.smallEditButton}
                          title="تعديل المادة"
                        >
                          ✏️
                        </button>
                        <button
                          onClick={() => onDeleteSubject(subjectNode)}
                          style={styles.smallDeleteButton}
                          title="حذف المادة"
                        >
                          🗑️
                        </button>
                      </div>
                    </div>

                    {!subject.terms || subject.terms.length === 0 ? (
                      <div style={styles.noUnitsHint}>لا توجد فصول في هذه المادة.</div>
                    ) : (
                      subject.terms.map((term, termIndex) => {
                        const termNode: TermNode = { ...subjectNode, termIndex, term: term.term };
                        const termKey = keyOf(
                          'term', gradeIndex, subjectIndex, termIndex, term.term,
                        );
                        return (
                          <div key={termKey} style={styles.termCard}>
                            <div style={styles.cardHeaderTight}>
                              {renderNodeName(termKey, term.term, styles.termTitle, '📚', name =>
                                onRenameTerm(termNode, name),
                              )}
                              <div style={{ display: 'flex', gap: '6px' }}>
                                <button
                                  onClick={() => openEdit(termKey, term.term)}
                                  style={styles.smallEditButton}
                                  title="تعديل الفصل"
                                >
                                  ✏️
                                </button>
                                <button
                                  onClick={() => onDeleteTerm(termNode)}
                                  style={styles.smallDeleteButton}
                                  title="حذف الفصل"
                                >
                                  🗑️
                                </button>
                              </div>
                            </div>

                            {/* الدروس تسكن داخل وحداتها، فبلا وحدة لا مكان
                                لحقل الدرس. قول ذلك صراحةً أفضل من إخفاء
                                القسم وترك المستخدم يبحث عن حقل غير موجود. */}
                            {!term.units || term.units.length === 0 ? (
                              <div style={styles.noUnitsHint}>
                                لا توجد وحدات في هذا الفصل — أضف وحدة أولاً، ثم يظهر حقل إضافة
                                الدرس داخلها.
                              </div>
                            ) : (
                              <div style={styles.unitsContainer}>
                                {term.units.map((unit, unitIndex) => {
                                  const unitNode: UnitNode = { ...termNode, unitIndex, unit };
                                  const unitKey = keyOf(
                                    'unit', gradeIndex, subjectIndex, termIndex, unit,
                                  );
                                  const draft = lessonDrafts[unitKey] ?? '';
                                  const lessons = lessonsOf(term, unit);
                                  const addLesson = () => {
                                    const name = draft.trim();
                                    if (!name) return;
                                    const accepted = onAddLesson(unitNode, name);
                                    if (accepted !== false) {
                                      setLessonDrafts(drafts => ({ ...drafts, [unitKey]: '' }));
                                    }
                                  };
                                  return (
                                    <div key={unitKey} style={styles.unitBlock}>
                                      <div style={styles.unitBadgeWithButtons}>
                                        {renderNodeName(
                                          unitKey, unit, styles.unitBadge, '📄', name =>
                                            onRenameUnit(unitNode, name),
                                        )}
                                        <button
                                          onClick={() => openEdit(unitKey, unit)}
                                          style={styles.tinyEditButton}
                                          title="تعديل الوحدة"
                                        >
                                          ✏️
                                        </button>
                                        <button
                                          onClick={() => onDeleteUnit(unitNode)}
                                          style={styles.tinyDeleteButton}
                                          title="حذف الوحدة"
                                        >
                                          🗑️
                                        </button>
                                      </div>

                                      {/* حقل إضافة الدرس: مربع ظاهر وزر صريح،
                                          لكل وحدة حقلها، فيبقى واضحاً أين
                                          سيُضاف الدرس. */}
                                      <div style={styles.lessonEditorRow}>
                                        <span style={styles.lessonFieldLabel}>الدرس:</span>
                                        <input
                                          type="text"
                                          value={draft}
                                          onChange={e => {
                                            const value = e.target.value;
                                            setLessonDrafts(drafts => ({
                                              ...drafts,
                                              [unitKey]: value,
                                            }));
                                          }}
                                          onKeyDown={e => {
                                            if (e.key === 'Enter') {
                                              e.preventDefault();
                                              addLesson();
                                            }
                                          }}
                                          placeholder={`اسم الدرس داخل وحدة "${unit}"`}
                                          style={styles.lessonInput}
                                        />
                                        <button
                                          onClick={addLesson}
                                          disabled={!draft.trim()}
                                          style={
                                            draft.trim()
                                              ? styles.addLessonButton
                                              : { ...styles.addLessonButton, ...styles.addLessonButtonDisabled }
                                          }
                                          title="إضافة درس إلى هذه الوحدة"
                                        >
                                          ➕ إضافة درس
                                        </button>
                                      </div>

                                      {lessons.length === 0 ? (
                                        <div style={styles.noLessonsHint}>
                                          لا توجد دروس في هذه الوحدة بعد — اكتب اسم الدرس أعلاه
                                          ثم اضغط «إضافة درس».
                                        </div>
                                      ) : (
                                        <div style={styles.lessonsRow}>
                                          {lessons.map((lesson, lessonIndex) => {
                                            const lessonNode: LessonNode = {
                                              ...unitNode,
                                              lessonIndex,
                                              lesson,
                                            };
                                            const isEditing =
                                              editingLesson?.key === unitKey &&
                                              editingLesson?.index === lessonIndex;
                                            const commitLesson = () => {
                                              const value = (editingLesson?.value ?? '').trim();
                                              setEditingLesson(null);
                                              if (value && value !== lesson) {
                                                onRenameLesson(lessonNode, value);
                                              }
                                            };
                                            return isEditing ? (
                                              <div key={lessonIndex} style={styles.lessonEditChip}>
                                                <input
                                                  type="text"
                                                  autoFocus
                                                  value={editingLesson!.value}
                                                  onChange={e =>
                                                    setEditingLesson(current =>
                                                      current
                                                        ? { ...current, value: e.target.value }
                                                        : current,
                                                    )
                                                  }
                                                  onKeyDown={e => {
                                                    if (e.key === 'Enter') {
                                                      e.preventDefault();
                                                      commitLesson();
                                                    }
                                                    if (e.key === 'Escape') setEditingLesson(null);
                                                  }}
                                                  style={styles.lessonEditInput}
                                                />
                                                <button
                                                  onClick={commitLesson}
                                                  style={styles.tinyEditButton}
                                                  title="حفظ"
                                                >
                                                  ✅
                                                </button>
                                                <button
                                                  onClick={() => setEditingLesson(null)}
                                                  style={styles.tinyDeleteButton}
                                                  title="إلغاء"
                                                >
                                                  ↩️
                                                </button>
                                              </div>
                                            ) : (
                                              <div key={lessonIndex} style={styles.lessonChip}>
                                                <span style={styles.lessonName}>📘 {lesson}</span>
                                                <button
                                                  onClick={() =>
                                                    setEditingLesson({
                                                      key: unitKey,
                                                      index: lessonIndex,
                                                      value: lesson,
                                                    })
                                                  }
                                                  style={styles.tinyEditButton}
                                                  title="تعديل الدرس"
                                                >
                                                  ✏️
                                                </button>
                                                <button
                                                  onClick={() => onDeleteLesson(lessonNode)}
                                                  style={styles.tinyDeleteButton}
                                                  title="حذف الدرس"
                                                >
                                                  🗑️
                                                </button>
                                              </div>
                                            );
                                          })}
                                        </div>
                                      )}
                                    </div>
                                  );
                                })}
                              </div>
                            )}
                          </div>
                        );
                      })
                    )}
                  </div>
                );
              })
            )}
          </div>
        );
      })}
    </>
  );
};

// التدرّج البصري هو ما يجعل العمق مقروءاً: الصف بطاقة خضراء كبيرة، ثم
// المادة رمادية مزاحة، ثم الفصل بنفسجي، ثم الوحدة، ثم الدرس كبسولة.
// كل مستوى يُزاح عن أبيه، فيُقرأ الاحتواء من الشكل بلا خطوط.
const styles: { [key: string]: React.CSSProperties } = {
  configCard: {
    marginBottom: '20px',
    padding: '15px',
    backgroundColor: '#f0fdf4',
    borderRadius: '10px',
    border: '2px solid #22c55e',
  },
  cardHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: '10px',
    flexWrap: 'wrap',
    marginBottom: '10px',
  },
  cardHeaderTight: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: '8px',
    marginBottom: '6px',
  },
  configTitle: { fontSize: '1.1rem', fontWeight: 'bold', color: '#1e40af' },
  subjectTitle: { fontWeight: 'bold', fontSize: '0.95rem', color: '#059669' },
  termTitle: { fontWeight: 'bold', fontSize: '0.9rem', color: '#7c3aed' },
  treeToggle: {
    background: 'none', border: 'none', cursor: 'pointer',
    color: '#92400e', fontSize: '0.9rem', padding: '2px 4px', lineHeight: 1,
  },
  treeCountBadge: {
    backgroundColor: '#fff7ed', color: '#9a3412', padding: '2px 8px',
    borderRadius: '12px', fontSize: '0.72rem', fontWeight: 'bold',
  },
  subjectCard: {
    marginTop: '8px', marginRight: '15px', padding: '8px',
    backgroundColor: '#f1f5f9', borderRadius: '8px',
  },
  termCard: {
    marginTop: '6px', marginRight: '15px', padding: '8px',
    backgroundColor: '#f3e8ff', borderRadius: '8px',
  },
  unitsContainer: { display: 'flex', flexWrap: 'wrap', gap: '6px', marginTop: '6px' },
  unitBadge: {
    backgroundColor: '#e0e7ff', color: '#4338ca', padding: '2px 8px',
    borderRadius: '12px', fontSize: '0.8rem', fontWeight: 'bold',
  },
  unitBadgeWithButtons: { display: 'flex', alignItems: 'center', gap: '4px' },
  // الوحدة ودروسها ككتلة واحدة: الدروس تحت وحدتها مباشرة وبإزاحة، حتى
  // يظل واضحاً أي درس يتبع أي وحدة عندما يحمل الفصل عدة وحدات.
  unitBlock: { display: 'flex', flexDirection: 'column', gap: '6px', width: '100%' },
  lessonsRow: { display: 'flex', flexWrap: 'wrap', gap: '6px', paddingInlineStart: '22px' },
  lessonChip: {
    display: 'flex', alignItems: 'center', gap: '4px', padding: '4px 10px',
    borderRadius: '999px', backgroundColor: '#eef2ff', border: '1px solid #c7d2fe',
  },
  lessonName: { fontSize: '0.85rem', fontWeight: 700, color: '#3730a3' },
  lessonEditChip: { display: 'flex', alignItems: 'center', gap: '4px', flex: '1 1 240px' },
  // صف حقل الدرس: التسمية ثم مربع الإدخال ثم الزر، بخلفية فاتحة وإطار
  // متقطع حتى يُقرأ كمنطقة إدخال لا كجزء من قائمة الوحدات.
  lessonEditorRow: {
    display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap',
    marginInlineStart: '22px', marginTop: '2px', padding: '8px 10px',
    borderRadius: '10px', backgroundColor: '#f5f3ff', border: '1px dashed #a5b4fc',
  },
  lessonFieldLabel: {
    fontSize: '0.85rem', fontWeight: 800, color: '#4338ca', whiteSpace: 'nowrap',
  },
  lessonInput: {
    flex: '1 1 200px', minWidth: '160px', padding: '7px 11px', fontSize: '0.88rem',
    borderRadius: '8px', border: '1px solid #c7d2fe', outline: 'none', fontFamily: 'inherit',
  },
  lessonEditInput: {
    flex: 1, minWidth: '120px', padding: '5px 9px', fontSize: '0.82rem',
    borderRadius: '8px', border: '1px solid #93c5fd', outline: 'none', fontFamily: 'inherit',
  },
  addLessonButton: {
    padding: '7px 14px', fontSize: '0.85rem', fontWeight: 800,
    backgroundColor: '#4f46e5', color: 'white', border: 'none',
    borderRadius: '8px', cursor: 'pointer', whiteSpace: 'nowrap',
  },
  addLessonButtonDisabled: {
    backgroundColor: '#c7d2fe', color: '#6366f1', cursor: 'not-allowed',
  },
  nodeInput: {
    flex: 1, minWidth: '120px', padding: '5px 9px', fontSize: '0.9rem',
    borderRadius: '8px', border: '1px solid #3b82f6', outline: 'none', fontFamily: 'inherit',
  },
  noLessonsHint: { marginInlineStart: '22px', fontSize: '0.78rem', color: '#6b7280' },
  noUnitsHint: {
    marginTop: '6px', fontSize: '0.8rem', color: '#92400e',
    backgroundColor: '#f8fafc', border: '1px dashed #fcd34d',
    borderRadius: '8px', padding: '8px 10px',
  },
  // الأزرار ممتلئة اللون لا أيقونات نصّية: الحذف أحمر بارز في كل مستوى،
  // والتعديل أزرق، ويصغر حجمهما كلما عمقت العقدة.
  editButton: {
    padding: '8px 12px', fontSize: '1rem', backgroundColor: '#3b82f6', color: 'white',
    border: 'none', borderRadius: '8px', cursor: 'pointer',
  },
  deleteButton: {
    padding: '8px 12px', fontSize: '1rem', backgroundColor: '#ef4444', color: 'white',
    border: 'none', borderRadius: '8px', cursor: 'pointer',
  },
  deleteButtonDisabled: {
    padding: '8px 12px', fontSize: '1rem', backgroundColor: '#e5e7eb', color: '#9ca3af',
    border: 'none', borderRadius: '8px', cursor: 'not-allowed',
  },
  smallEditButton: {
    padding: '4px 8px', fontSize: '0.8rem', backgroundColor: '#3b82f6', color: 'white',
    border: 'none', borderRadius: '8px', cursor: 'pointer',
  },
  smallDeleteButton: {
    padding: '4px 8px', fontSize: '0.8rem', backgroundColor: '#ef4444', color: 'white',
    border: 'none', borderRadius: '8px', cursor: 'pointer',
  },
  tinyEditButton: {
    padding: '2px 6px', fontSize: '0.7rem', backgroundColor: '#3b82f6', color: 'white',
    border: 'none', borderRadius: '4px', cursor: 'pointer',
  },
  tinyDeleteButton: {
    padding: '2px 6px', fontSize: '0.7rem', backgroundColor: '#ef4444', color: 'white',
    border: 'none', borderRadius: '4px', cursor: 'pointer',
  },
};

export default AcademicTreeViewer;
