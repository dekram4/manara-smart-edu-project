import React, {useState} from 'react';
import './_shared.css';

const levels = [
  {name:'الصف الرابع الابتدائي', open:true, terms:[
    {name:'الفصل الدراسي الأول', open:true, subjects:[
      {name:'الرياضيات', units:['الوحدة الأولى: الأعداد','الوحدة الثانية: العمليات الحسابية','الوحدة الثالثة: الهندسة']},
      {name:'اللغة العربية', units:['الوحدة الأولى: لغتي الجميلة','الوحدة الثانية: القراءة والفهم']},
    ]},
    {name:'الفصل الدراسي الثاني', subjects:[{name:'العلوم',units:['المادة والطاقة','الكائنات الحية']}]},
  ]},
  {name:'الصف الخامس الابتدائي', terms:[{name:'الفصل الدراسي الأول',subjects:[{name:'الرياضيات',units:['الكسور','القياس']}]}]},
];

export function AcademicSettings() {
  const [active,setActive]=useState('academic'); const [open,setOpen]=useState(''); const [query,setQuery]=useState('');
  return <div className="shell">
    <header className="topbar"><div className="brand"><div className="brand-mark">م</div><div><div className="eyebrow">منارة المعرفة / الإدارة</div><h1>الإعدادات الأكاديمية</h1></div></div><div className="user-chip"><div className="avatar">م</div>المشرف العام <span>⌄</span></div></header>
    <div className="layout"><main className="main">
      <div className="stats"><div className="card stat motion"><small>الصفوف</small><b>6</b><i>🏫</i></div><div className="card stat motion"><small>المواد</small><b>18</b><i>📚</i></div><div className="card stat motion"><small>الوحدات</small><b>72</b><i>🗂️</i></div><div className="card stat motion"><small>آخر تحديث</small><b style={{fontSize:16}}>اليوم</b><i>✓</i></div></div>
      <div className="card toolbar"><div className="search"><input placeholder="ابحث في الصفوف أو المواد أو الوحدات..." value={query} onChange={e=>setQuery(e.target.value)}/></div><select className="select"><option>كل الفصول</option><option>الفصل الدراسي الأول</option><option>الفصل الدراسي الثاني</option></select><button className="btn btn-primary">+ إضافة مستوى</button><button className="btn btn-ghost">تصدير</button></div>
      <section className="card"><div className="section-head"><div><h2>الهيكل الأكاديمي</h2><div className="muted">اضغط على أي مستوى للتوسيع وإدارة العلاقات التابعة له</div></div><span className="tag green">متزامن</span></div><div className="tree">
        {levels.filter(l=>!query||l.name.includes(query)).map((level,i)=><div key={level.name}>
          <div className="tree-row root motion" onClick={()=>setOpen(open===level.name?'':level.name)}><span className="chev">{open===level.name||level.open?'⌄':'‹'}</span><span>🏫</span><b>{level.name}</b><div className="tree-meta"><span className="tag">2 فصل</span><span className="tag blue">8 مادة</span></div><button className="icon-btn">⋮</button></div>
          {(open===level.name||level.open)&&level.terms.map(term=><div key={term.name}><div className="tree-row child"><span className="chev">⌄</span><span>📅</span><b>{term.name}</b><div className="tree-meta"><span className="tag orange">{term.subjects.length} مواد</span></div><button className="icon-btn">⋮</button></div>
            {term.subjects.map(subject=><div key={subject.name}><div className="tree-row grandchild"><span className="chev">⌄</span><span>📘</span><b>{subject.name}</b><div className="tree-meta">{subject.units.map(u=><span className="tag" key={u}>{u.split(':')[0]}</span>)}</div><button className="icon-btn">⋮</button></div></div>)}
          </div>)}
        </div>)}
      </div></section>
    </main><aside className="card sidebar"><div className="side-title">لوحة الإدارة</div>{[['academic','🗂️','الإعدادات الأكاديمية'],['content','📚','إدارة المحتوى'],['certs','🏆','الشهادات'],['users','👥','الحسابات والربط'],['reports','📊','التقارير']].map(x=><button className={'nav-item '+(active===x[0]?'active':'')} onClick={()=>setActive(x[0])} key={x[0]}><span>{x[1]}</span>{x[2]}</button>)}<div style={{marginTop:30,padding:14,background:'#f7f5ff',borderRadius:14}}><div className="eyebrow">صلاحية الدور</div><b style={{fontSize:13}}>المشرف العام</b><div className="muted">إدارة كل المستويات والمواد والوحدات</div></div></aside></div>
  </div>
}