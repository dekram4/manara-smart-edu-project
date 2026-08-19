
import React from 'react';
import ParentAccountSetup from '../parent/ParentAccountSetup';

interface TeacherAccountManagementProps {
  teacherId: string;
  teacherName: string;
}

const TeacherAccountManagement: React.FC<TeacherAccountManagementProps> = ({ teacherId, teacherName }) => {
  // المعلم يمكنه فقط إنشاء أولياء أمور
  return (
    <div className="dashboard-page">
      <div className="dashboard-notice bg-blue-50 border-blue-200">
        <h2 className="text-2xl font-black text-blue-900 mb-2">👥 إدارة أولياء الأمور</h2>
        <p className="text-blue-700 font-medium">
          يمكنك إنشاء حسابات أولياء الأمور. سيتم ربط جميع أولياء الأمور بحسابك تلقائياً.
        </p>
      </div>
      
      <ParentAccountSetup 
        onComplete={() => {}} 
        createdBy={teacherId}
        createdByName={teacherName}
      />
    </div>
  );
};

export default TeacherAccountManagement;
