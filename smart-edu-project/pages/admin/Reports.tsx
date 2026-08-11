
import React, { useState, useEffect } from 'react';
import { STORAGE_KEYS, COLORS } from '../../constants';
import { StudentInfo, QuizResult, ParentInfo, ReportData, LessonConfig } from '../../types';
import { getParentChildren, getTeacherParents, getTeacherStudents } from '../../utils/scope';
import { getQuizTypeLabel as formatQuizTypeLabel } from '../../utils/quizTypes';
import { getQuizResultPercentage } from '../../utils/quizScoring';

const Reports: React.FC = () => {
  const [reports, setReports] = useState<ReportData[]>([]);
  const [data, setData] = useState({ students: [], quizzes: [], parents: [], lessons: [], teachers: [] });
  const [selectedStudentId, setSelectedStudentId] = useState<string>('all');
  const [selectedTeacherId, setSelectedTeacherId] = useState<string>('all');
  const [selectedParentId, setSelectedParentId] = useState<string>('all');
  const [reportType, setReportType] = useState<string>('all'); // 'all' | 'byTeacher' | 'byParent'

  const getQuizTypeLabel = (quizType?: string) => {
    return formatQuizTypeLabel(quizType);
  };

  useEffect(() => {
    loadData();
  }, []);

  const loadData = () => {
    setData({
      students: JSON.parse(localStorage.getItem(STORAGE_KEYS.STUDENTS) || '[]'),
       quizzes: JSON.parse(localStorage.getItem(STORAGE_KEYS.QUIZ_RESULTS) || '[]')
         .map((quiz: QuizResult) => ({ ...quiz, percentage: getQuizResultPercentage(quiz) })),
      parents: JSON.parse(localStorage.getItem(STORAGE_KEYS.PARENTS) || '[]'),
      lessons: JSON.parse(localStorage.getItem(STORAGE_KEYS.LESSON_CONFIGS) || '[]'),
      teachers: JSON.parse(localStorage.getItem(STORAGE_KEYS.TEACHERS) || '[]'),
    });
    setReports(JSON.parse(localStorage.getItem(STORAGE_KEYS.REPORTS) || '[]'));
  };

  const handlePrint = (type: string) => {
    const printWindow = window.open('', '_blank');
    if (!printWindow) return;

    let content = '';
    let title = '';
    
    // تحديد العنوان والمحتوى حسب نوع التقرير
    if (type === 'students') {
      if (reportType === 'byTeacher') {
        title = selectedTeacherId === 'all' ? 'تقرير الطلاب حسب المعلمين' : `تقرير طلاب المعلم`;
        content = generateStudentsByTeacherReport();
      } else if (reportType === 'byParent') {
        title = selectedParentId === 'all' ? 'تقرير الطلاب حسب أولياء الأمور' : `تقرير طلاب ولي الأمر`;
        content = generateStudentsByParentReport();
      } else {
        title = 'تقرير الطلاب المسجلين';
        content = generateAllStudentsReport();
      }
    } else if (type === 'quizzes') {
      title = 'تقرير النتائج العامة';
      content = generateQuizzesReport();
    } else if (type === 'interactions') {
      title = 'تقرير التفاعل';
      content = generateInteractionsReport();
    }

    printWindow.document.write(`
      <html dir="rtl" lang="ar">
        <head>
          <title>${title}</title>
          <style>
            body { font-family: sans-serif; padding: 40px; }
            h1 { text-align: center; color: #1e40af; margin-bottom: 40px; border-bottom: 3px solid #3b82f6; padding-bottom: 20px; }
            h2 { color: #3b82f6; margin-top: 40px; margin-bottom: 20px; border-right: 4px solid #3b82f6; padding-right: 15px; }
            table { width: 100%; border-collapse: collapse; margin-top: 20px; margin-bottom: 40px; box-shadow: 0 2px 10px rgba(0,0,0,0.05); }
            th, td { border: 1px solid #e2e8f0; padding: 12px; text-align: right; }
            th { background: #3b82f6; color: white; font-weight: bold; }
            tr:nth-child(even) { background-color: #f8fafc; }
            .meta { margin-bottom: 20px; font-weight: bold; color: #64748b; }
            .teacher-section { margin-bottom: 60px; padding: 20px; background: #f8fafc; border-radius: 15px; }
            .footer { margin-top: 60px; text-align: center; color: #94a3b8; font-size: 12px; border-top: 1px solid #e2e8f0; padding-top: 20px; }
            @media print { .no-print { display: none; } }
          </style>
        </head>
        <body>
          <h1>${title}</h1>
          <div class="meta text-right">تاريخ الاستخراج: ${new Date().toLocaleString('ar-SA')}</div>
          ${content}
          <div class="footer">منصة التعليم الذكي - الإدارة العامة • جميع الحقوق محفوظة © ${new Date().getFullYear()}</div>
          <div class="no-print" style="text-align:center; margin-top:40px;">
             <button onclick="window.print()" style="padding:15px 50px; background:#3b82f6; color:white; border:none; border-radius:15px; cursor:pointer; font-weight:black; font-size:18px;">طباعة الآن</button>
          </div>
        </body>
      </html>
    `);
    printWindow.document.close();
  };

  const generateAllStudentsReport = () => {
    return `
      <table border="1">
        <thead>
          <tr>
            <th>الاسم</th>
            <th>رقم الهوية</th>
            <th>الصف</th>
            <th>ولي الأمر</th>
            <th>المعلم</th>
            <th>تاريخ التسجيل</th>
          </tr>
        </thead>
        <tbody>
          ${data.students.map((s: StudentInfo) => {
            const parent = (data.parents as ParentInfo[]).find(p => p.id === s.parentId);
            const teacher = (data.teachers as any[]).find(t => t.id === (s.teacherId ?? s.createdBy));
            return `
              <tr>
                <td>${s.name}</td>
                <td>${s.studentIdNumber || '—'}</td>
                <td>${s.primaryGrade || s.grade}</td>
                <td>${parent?.name || '—'}</td>
                <td>${teacher?.name || '—'}</td>
                <td>${new Date(s.createdAt).toLocaleDateString('ar-SA')}</td>
              </tr>
            `;
          }).join('')}
        </tbody>
      </table>
    `;
  };

  const generateStudentsByTeacherReport = () => {
    const teachers = data.teachers as any[];
    if (selectedTeacherId !== 'all') {
      const teacher = teachers.find(t => t.id === selectedTeacherId);
      const parents = getTeacherParents(data.parents as ParentInfo[], selectedTeacherId);
      const students = getTeacherStudents(data.students as StudentInfo[], selectedTeacherId, parents);
      
      return `
        <div class="teacher-section">
          <h2>👨‍🏫 المعلم: ${teacher?.name || 'غير معروف'}</h2>
          <p><strong>عدد أولياء الأمور:</strong> ${parents.length}</p>
          <p><strong>عدد الطلاب:</strong> ${students.length}</p>
          
          <h3 style="margin-top: 30px;">أولياء الأمور:</h3>
          <table border="1">
            <thead>
              <tr>
                <th>الاسم</th>
                <th>اسم المستخدم</th>
                <th>رقم الجوال</th>
                <th>عدد الأبناء</th>
              </tr>
            </thead>
            <tbody>
              ${parents.map(p => `
                <tr>
                  <td>${p.name}</td>
                  <td>${p.username}</td>
                  <td>${p.phoneNumber}</td>
                  <td>${(data.students as StudentInfo[]).filter(s => s.parentId === p.id).length}</td>
                </tr>
              `).join('')}
            </tbody>
          </table>

          <h3 style="margin-top: 30px;">الطلاب:</h3>
          <table border="1">
            <thead>
              <tr>
                <th>الاسم</th>
                <th>رقم الهوية</th>
                <th>الصف</th>
                <th>ولي الأمر</th>
                <th>تاريخ التسجيل</th>
              </tr>
            </thead>
            <tbody>
              ${students.map(s => {
                const parent = parents.find(p => p.id === s.parentId);
                return `
                  <tr>
                    <td>${s.name}</td>
                    <td>${s.studentIdNumber || '—'}</td>
                    <td>${s.primaryGrade || s.grade}</td>
                    <td>${parent?.name || '—'}</td>
                    <td>${new Date(s.createdAt).toLocaleDateString('ar-SA')}</td>
                  </tr>
                `;
              }).join('')}
            </tbody>
          </table>
        </div>
      `;
    } else {
      // تقرير لكل المعلمين
      return teachers.map(teacher => {
        const parents = getTeacherParents(data.parents as ParentInfo[], teacher.id);
        const students = getTeacherStudents(data.students as StudentInfo[], teacher.id, parents);
        
        return `
          <div class="teacher-section">
            <h2>👨‍🏫 المعلم: ${teacher.name}</h2>
            <p><strong>المادة:</strong> ${teacher.subject || '—'} | <strong>عدد أولياء الأمور:</strong> ${parents.length} | <strong>عدد الطلاب:</strong> ${students.length}</p>
            <table border="1">
              <thead>
                <tr>
                  <th>اسم الطالب</th>
                  <th>رقم الهوية</th>
                  <th>الصف</th>
                  <th>ولي الأمر</th>
                </tr>
              </thead>
              <tbody>
                ${students.map(s => {
                  const parent = parents.find(p => p.id === s.parentId);
                  return `
                    <tr>
                      <td>${s.name}</td>
                      <td>${s.studentIdNumber || '—'}</td>
                      <td>${s.primaryGrade || s.grade}</td>
                      <td>${parent?.name || '—'}</td>
                    </tr>
                  `;
                }).join('') || '<tr><td colspan="4" style="text-align:center;">لا يوجد طلاب</td></tr>'}
              </tbody>
            </table>
          </div>
        `;
      }).join('');
    }
  };

  const generateStudentsByParentReport = () => {
    const parents = data.parents as ParentInfo[];
    if (selectedParentId !== 'all') {
      const parent = parents.find(p => p.id === selectedParentId);
      const students = parent
        ? getParentChildren(data.students as StudentInfo[], parent)
        : [];
      
      return `
        <div class="teacher-section">
          <h2>👨‍👩‍👧‍👦 ولي الأمر: ${parent?.name || 'غير معروف'}</h2>
          <p><strong>رقم الجوال:</strong> ${parent?.phoneNumber || '—'} | <strong>عدد الأبناء:</strong> ${students.length}</p>
          <table border="1">
            <thead>
              <tr>
                <th>اسم الطالب</th>
                <th>رقم الهوية</th>
                <th>الصف</th>
                <th>تاريخ التسجيل</th>
              </tr>
            </thead>
            <tbody>
              ${students.map(s => `
                <tr>
                  <td>${s.name}</td>
                  <td>${s.studentIdNumber || '—'}</td>
                  <td>${s.primaryGrade || s.grade}</td>
                  <td>${new Date(s.createdAt).toLocaleDateString('ar-SA')}</td>
                </tr>
              `).join('') || '<tr><td colspan="4" style="text-align:center;">لا يوجد أبناء</td></tr>'}
            </tbody>
          </table>
        </div>
      `;
    } else {
      // تقرير لكل أولياء الأمور
      return parents.map(parent => {
        const students = getParentChildren(data.students as StudentInfo[], parent);
        
        return `
          <div class="teacher-section">
            <h2>👨‍👩‍👧‍👦 ولي الأمر: ${parent.name}</h2>
            <p><strong>رقم الجوال:</strong> ${parent.phoneNumber} | <strong>عدد الأبناء:</strong> ${students.length}</p>
            <table border="1">
              <thead>
                <tr>
                  <th>اسم الطالب</th>
                  <th>رقم الهوية</th>
                  <th>الصف</th>
                </tr>
              </thead>
              <tbody>
                ${students.map(s => `
                  <tr>
                    <td>${s.name}</td>
                    <td>${s.studentIdNumber || '—'}</td>
                    <td>${s.primaryGrade || s.grade}</td>
                  </tr>
                `).join('') || '<tr><td colspan="3" style="text-align:center;">لا يوجد أبناء</td></tr>'}
              </tbody>
            </table>
          </div>
        `;
      }).join('');
    }
  };

  const generateQuizzesReport = () => {
    const studentsMap: Record<string, StudentInfo> = {};
    (data.students as StudentInfo[]).forEach(s => (studentsMap[s.id] = s));
    let quizList: QuizResult[] = data.quizzes;
    if (selectedStudentId && selectedStudentId !== 'all') quizList = quizList.filter((q: QuizResult) => q.studentId === selectedStudentId);
    
    return `
      <table border="1">
        <thead>
          <tr>
            <th>اسم الطالب</th>
            <th>رقم الهوية</th>
            <th>المادة</th>
            <th>نوع الاختبار</th>
            <th>الوحدة</th>
            <th>النتيجة</th>
            <th>المستوى</th>
            <th>التاريخ</th>
          </tr>
        </thead>
        <tbody>
          ${quizList.map((q: QuizResult) => {
            const s = studentsMap[q.studentId] || null;
            const studentName = s ? s.name : q.studentName || 'غير معروف';
            const studentIdNumber = s ? (s.studentIdNumber || '—') : (q.studentId || '—');
            return `
              <tr>
                <td>${studentName}</td>
                <td>${studentIdNumber}</td>
                <td>${q.subject}</td>
                <td>${getQuizTypeLabel(q.quizType)}</td>
                <td>${q.unit}</td>
                <td style="font-weight:bold;">${q.percentage}%</td>
                <td>${q.level}</td>
                <td>${new Date(q.createdAt).toLocaleDateString('ar-SA')}</td>
              </tr>
            `;
          }).join('')}
        </tbody>
      </table>
    `;
  };

  const generateInteractionsReport = () => {
    const interactions = JSON.parse(localStorage.getItem(STORAGE_KEYS.INTERACTIONS) || '[]');
    const studentsMap: Record<string, StudentInfo> = {};
    (data.students as StudentInfo[]).forEach(s => (studentsMap[s.id] = s));
    
    return `
      <table border="1">
        <thead>
          <tr>
            <th>الاسم</th>
            <th>رقم الهوية</th>
            <th>الصف</th>
            <th>المادة</th>
            <th>الوحدة</th>
            <th>التفاعل</th>
            <th>الزمن</th>
          </tr>
        </thead>
        <tbody>
          ${interactions.map((it: any) => {
            const s = studentsMap[it.studentId] || null;
            const name = s ? s.name : it.studentName || '—';
            const idNum = s ? (s.studentIdNumber || '—') : (it.studentId || '—');
            return `
              <tr>
                <td>${name}</td>
                <td>${idNum}</td>
                <td>${it.grade || '—'}</td>
                <td>${it.subject || '—'}</td>
                <td>${it.unit || '—'}</td>
                <td>${it.action || it.type || '—'}</td>
                <td>${new Date(it.timestamp || it.time || Date.now()).toLocaleString('ar-SA')}</td>
              </tr>
            `;
          }).join('')}
        </tbody>
      </table>
    `;
  };

  const handlePrintOld = (type: string) => {
    const printWindow = window.open('', '_blank');
    if (!printWindow) return;

    let content = '';
    const title = type === 'students' ? 'تقرير الطلاب المسجلين' : type === 'quizzes' ? 'تقرير النتائج العامة' : 'تقرير المحتوى التعليمي';

    if (type === 'students') {
      // Student report: only the requested columns (Name, ID number, Grade, Registration Date)
      content = `
        <table border="1">
          <thead>
            <tr>
              <th>الاسم</th>
              <th>رقم الهوية</th>
              <th>الصف</th>
              <th>تاريخ التسجيل</th>
            </tr>
          </thead>
          <tbody>
            ${data.students.map((s: StudentInfo) => `
              <tr>
                <td>${s.name}</td>
                <td>${s.studentIdNumber || '—'}</td>
                <td>${s.grade}</td>
                <td>${new Date(s.createdAt).toLocaleDateString('ar-SA')}</td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      `;
    } else if (type === 'quizzes') {
      // Build quizzes list and cross-reference students to ensure data ties to current student records
      const studentsMap: Record<string, StudentInfo> = {};
      (data.students as StudentInfo[]).forEach(s => (studentsMap[s.id] = s));
      let quizList: QuizResult[] = data.quizzes;
      if (selectedStudentId && selectedStudentId !== 'all') quizList = quizList.filter((q: QuizResult) => q.studentId === selectedStudentId);
      content = `
        <table border="1">
          <thead>
            <tr>
              <th>اسم الطالب</th>
              <th>رقم الهوية</th>
              <th>المادة</th>
              <th>نوع الاختبار</th>
              <th>الوحدة</th>
              <th>النتيجة</th>
              <th>المستوى</th>
              <th>التاريخ</th>
            </tr>
          </thead>
          <tbody>
            ${quizList.map((q: QuizResult) => {
              const s = studentsMap[q.studentId] || null;
              const studentName = s ? s.name : q.studentName || 'غير معروف';
              const studentIdNumber = s ? (s.studentIdNumber || '—') : (q.studentId || '—');
              return `
                <tr>
                  <td>${studentName}</td>
                  <td>${studentIdNumber}</td>
                  <td>${q.subject}</td>
                  <td>${getQuizTypeLabel(q.quizType)}</td>
                  <td>${q.unit}</td>
                  <td style="font-weight:bold;">${q.percentage}%</td>
                  <td>${q.level}</td>
                  <td>${new Date(q.createdAt).toLocaleDateString('ar-SA')}</td>
                </tr>
              `;
            }).join('')}
          </tbody>
        </table>
      `;
    } else if (type === 'interactions') {
      // Interaction report: list of interactions (student, id, lesson info, action, timestamp)
      const interactions = JSON.parse(localStorage.getItem(STORAGE_KEYS.INTERACTIONS) || '[]');
      const studentsMap: Record<string, StudentInfo> = {};
      (data.students as StudentInfo[]).forEach(s => (studentsMap[s.id] = s));
      content = `
        <table border="1">
          <thead>
            <tr>
              <th>الاسم</th>
              <th>رقم الهوية</th>
              <th>الصف</th>
              <th>المادة</th>
              <th>الوحدة</th>
              <th>التفاعل</th>
              <th>الزمن</th>
            </tr>
          </thead>
          <tbody>
            ${interactions.map((it: any) => {
              const s = studentsMap[it.studentId] || null;
              const name = s ? s.name : it.studentName || '—';
              const idNum = s ? (s.studentIdNumber || '—') : (it.studentId || '—');
              return `
                <tr>
                  <td>${name}</td>
                  <td>${idNum}</td>
                  <td>${it.grade || '—'}</td>
                  <td>${it.subject || '—'}</td>
                  <td>${it.unit || '—'}</td>
                  <td>${it.action || it.type || '—'}</td>
                  <td>${new Date(it.timestamp || it.time || Date.now()).toLocaleString('ar-SA')}</td>
                </tr>
              `;
            }).join('')}
          </tbody>
        </table>
      `;
    }

    printWindow.document.write(`
      <html dir="rtl" lang="ar">
        <head>
          <title>${title}</title>
          <style>
            body { font-family: sans-serif; padding: 40px; }
            h1 { text-align: center; color: #1e40af; margin-bottom: 40px; border-bottom: 3px solid #3b82f6; padding-bottom: 20px; }
            table { width: 100%; border-collapse: collapse; margin-top: 20px; box-shadow: 0 2px 10px rgba(0,0,0,0.05); }
            th, td { border: 1px solid #e2e8f0; padding: 12px; text-align: right; }
            th { background: #3b82f6; color: white; font-weight: bold; }
            tr:nth-child(even) { background-color: #f8fafc; }
            .meta { margin-bottom: 20px; font-weight: bold; color: #64748b; }
            .footer { margin-top: 60px; text-align: center; color: #94a3b8; font-size: 12px; border-top: 1px solid #e2e8f0; padding-top: 20px; }
            @media print { .no-print { display: none; } }
          </style>
        </head>
        <body>
          <h1>${title}</h1>
          <div class="meta text-right">تاريخ الاستخراج: ${new Date().toLocaleString('ar-SA')}</div>
          ${content}
          <div class="footer">منصة التعليم الذكي - الإدارة العامة • جميع الحقوق محفوظة © ${new Date().getFullYear()}</div>
          <div class="no-print" style="text-align:center; margin-top:40px;">
             <button onclick="window.print()" style="padding:15px 50px; background:#3b82f6; color:white; border:none; border-radius:15px; cursor:pointer; font-weight:black; font-size:18px;">طباعة الان</button>
          </div>
        </body>
      </html>
    `);
    printWindow.document.close();
  };

  return (
    <div className="space-y-12 animate-fadeIn max-w-6xl mx-auto">
      <div>
        <h1 className="text-4xl font-black text-purple-900">مركز التقارير</h1>
        <p className="text-purple-500 font-bold mt-2 text-lg">استخرج إحصائيات دقيقة وشاملة حول أداء المنصة</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
        <div className="bg-white p-12 rounded-[50px] shadow-sm border border-purple-100 flex flex-col items-center text-center group hover:shadow-2xl hover:-translate-y-2 transition-all">
          <div className="text-8xl mb-8 bg-blue-50 w-32 h-32 flex items-center justify-center rounded-[40px] group-hover:scale-110 transition-transform">👨‍🎓</div>
          <h3 className="text-2xl font-black text-purple-800 mb-4">تقرير الطلاب</h3>
          <p className="text-purple-400 font-bold mb-6 flex-1">بيانات الطلاب الأكاديمية وحالة التسجيل والصفوف</p>
          
          <div className="w-full mb-4 text-right space-y-3">
            <div>
              <label className="text-sm font-bold text-purple-700 mr-2">نوع التقرير</label>
              <select 
                value={reportType} 
                onChange={e => setReportType(e.target.value)}
                className="w-full p-3 rounded-lg border-2 border-blue-100 font-bold"
              >
                <option value="all">تقرير عام - كل الطلاب</option>
                <option value="byTeacher">تقرير حسب المعلمين</option>
                <option value="byParent">تقرير حسب أولياء الأمور</option>
              </select>
            </div>
            
            {reportType === 'byTeacher' && (
              <div>
                <label className="text-sm font-bold text-purple-700 mr-2">اختر المعلم</label>
                <select 
                  value={selectedTeacherId} 
                  onChange={e => setSelectedTeacherId(e.target.value)}
                  className="w-full p-3 rounded-lg border-2 border-blue-100 font-bold"
                >
                  <option value="all">كل المعلمين</option>
                  {data.teachers.map((t: any) => (
                    <option key={t.id} value={t.id}>{t.name} - {t.subject || 'غير محدد'}</option>
                  ))}
                </select>
              </div>
            )}
            
            {reportType === 'byParent' && (
              <div>
                <label className="text-sm font-bold text-purple-700 mr-2">اختر ولي الأمر</label>
                <select 
                  value={selectedParentId} 
                  onChange={e => setSelectedParentId(e.target.value)}
                  className="w-full p-3 rounded-lg border-2 border-blue-100 font-bold"
                >
                  <option value="all">كل أولياء الأمور</option>
                  {(data.parents as ParentInfo[]).map((p: ParentInfo) => (
                    <option key={p.id} value={p.id}>{p.name} - {p.phoneNumber}</option>
                  ))}
                </select>
              </div>
            )}
          </div>
          
          <button
            onClick={() => handlePrint('students')}
            className="w-full bg-blue-600 text-white py-5 rounded-[25px] font-black text-xl hover:bg-blue-700 shadow-xl shadow-blue-100 transition-all"
          >🖨️ طباعة التقرير</button>
        </div>

        <div className="bg-white p-12 rounded-[50px] shadow-sm border border-purple-100 flex flex-col items-center text-center group hover:shadow-2xl hover:-translate-y-2 transition-all">
          <div className="text-8xl mb-8 bg-emerald-50 w-32 h-32 flex items-center justify-center rounded-[40px] group-hover:scale-110 transition-transform">📝</div>
          <h3 className="text-2xl font-black text-purple-800 mb-4">نتائج الاختبارات</h3>
          <p className="text-purple-400 font-bold mb-10 flex-1">تحليل شامل لنتائج جميع الطلاب في مختلف المواد والوحدات</p>
          <div className="w-full mb-4 text-right">
            <label className="text-sm font-bold text-purple-700 mr-2">تصفية حسب الطالب</label>
            <select value={selectedStudentId} onChange={e => setSelectedStudentId(e.target.value)} className="p-3 rounded-lg border-2 border-emerald-100">
              <option value="all">الكل</option>
              {data.students.map((s: StudentInfo) => <option key={s.id} value={s.id}>{s.name} {s.studentIdNumber ? `(${s.studentIdNumber})` : ''}</option>)}
            </select>
          </div>
          <button
            onClick={() => handlePrint('quizzes')}
            className="w-full bg-emerald-600 text-white py-5 rounded-[25px] font-black text-xl hover:bg-emerald-700 shadow-xl shadow-emerald-100 transition-all"
          >🖨️ طباعة التقرير</button>
        </div>

        <div className="bg-white p-12 rounded-[50px] shadow-sm border border-purple-100 flex flex-col items-center text-center group hover:shadow-2xl hover:-translate-y-2 transition-all">
          <div className="text-8xl mb-8 bg-purple-50 w-32 h-32 flex items-center justify-center rounded-[40px] group-hover:scale-110 transition-transform">📈</div>
          <h3 className="text-2xl font-black text-purple-800 mb-4">تقرير التفاعل</h3>
          <p className="text-purple-400 font-bold mb-6 flex-1">سجل تفاعلات الطلاب مع المحتوى (الأفاتار، الفيديو)</p>
          <button
            onClick={() => handlePrint('interactions')}
            className="w-full bg-purple-600 text-white py-5 rounded-[25px] font-black text-xl hover:bg-purple-700 shadow-xl shadow-purple-100 transition-all"
          >🖨️ طباعة تقرير التفاعل</button>
        </div>
      </div>
    </div>
  );
};

export default Reports;
