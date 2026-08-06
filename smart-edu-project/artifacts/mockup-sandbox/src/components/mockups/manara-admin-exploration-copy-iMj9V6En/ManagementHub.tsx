import React, {useState} from 'react';
import './_shared.css';

const admin = [
  ['🗂️','الإعدادات الأكاديمية','الصفوف والمواد والفصول والوحدات','6 مستويات • 18 مادة'],
  ['👥','إدارة الحسابات','الطلاب وأولياء الأمور والربط بينهم','428 طالباً • 312 ولي أمر'],
  ['👩‍🏫','إدارة المعلمين','التخصصات والحسابات والصلاحيات','24 معلماً'],
  ['📚','إدارة المحتوى','الدروس والفيديوهات والاختبارات','248 درساً'],
  ['🏆','الشهادات','الإصدار والمعاينة والطباعة','1,248 شهادة'],
  ['📊','التقارير العامة','النشاط والدرجات والتقدم','تحديث مباشر'],
];
const teacher = [
  ['🗂️','الإعدادات الأكاديمية','المسارات المسموحة لك','الرابع • رياضيات'],
  ['📚','إدارة المحتوى','دروسي ومواردي واختباراتي','42 درساً'],
  ['🧠','الاختبارات','إنشاء ومراجعة نتائج الطلاب','18 اختباراً'],
  ['🏆','الشهادات','إصدار شهادات طلابك','86 شهادة'],
  ['💬','المحادثات','الطلاب وأولياء الأمور','12 محادثة جديدة'],
  ['📊','تقارير الطلاب','الحضور والتقدم والدرجات','24 طالباً'],
];

export function ManagementHub() {
 const [role,setRole]=useState('admin'); const list=role==='admin'?admin:teacher;
 return <div className="shell"><header className="topbar"><div className="brand"><div className="brand-mark">م</div><div><div className="eyebrow">منارة المعرفة / مركز الإدارة</div><h1>لوحة التحكم</h1></div></div><div className="user-chip"><div className="avatar">{role==='admin'?'م':'س'}</div>{role==='admin'?'المشرف العام':'أ. سارة العتيبي'} <span>⌄</span></div></header>
 <div className="card toolbar"><div style={{marginLeft:'auto'}}><h2>{role==='admin'?'إدارة المنصة':'مساحة المعلم'}</h2><div className="muted">{role==='admin'?'كل الأدوات والبيانات والصلاحيات في مكان واحد':'كل ما تحتاجه لإدارة صفوفك ومتابعة طلابك'}</div></div><button className={'btn '+(role==='admin'?'btn-primary':'btn-ghost')} onClick={()=>setRole('admin')}>🛡️ المشرف</button><button className={'btn '+(role==='teacher'?'btn-primary':'btn-ghost')} onClick={()=>setRole('teacher')}>👩‍🏫 المعلم</button></div>
 <div className="stats"><div className="card stat motion"><small>{role==='admin'?'إجمالي الطلاب':'طلابك'}</small><b>{role==='admin'?'428':'24'}</b><i>🎒</i></div><div className="card stat motion"><small>المحتوى النشط</small><b>{role==='admin'?'248':'42'}</b><i>📚</i></div><div className="card stat motion"><small>اختبارات هذا الأسبوع</small><b>{role==='admin'?'36':'8'}</b><i>🧠</i></div><div className="card stat motion"><small>تحتاج انتباهك</small><b>{role==='admin'?'7':'3'}</b><i>🔔</i></div></div>
 <section className="card"><div className="section-head"><div><h2>{role==='admin'?'اختصارات الإدارة':'أدوات المعلم'}</h2><div className="muted">تظهر لك القوائم المرتبطة بصلاحيات دورك وعلاقاتك الأكاديمية</div></div><span className="tag green">صلاحيات مفعلة</span></div><div style={{padding:18,display:'grid',gridTemplateColumns:'repeat(3,1fr)',gap:12}}>{list.map(item=><button className="card motion" key={item[1]} style={{padding:16,textAlign:'right',border:'1px solid #ececf2',cursor:'pointer'}}><div style={{display:'flex',alignItems:'center',gap:10}}><span style={{fontSize:27}}>{item[0]}</span><b style={{fontSize:14}}>{item[1]}</b></div><div className="muted" style={{marginTop:9}}>{item[2]}</div><div style={{marginTop:10}}><span className="tag">{item[3]}</span><span style={{float:'left',color:'#8066dc'}}>←</span></div></button>)}</div></section></div>
}