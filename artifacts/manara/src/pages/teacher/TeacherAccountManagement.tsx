
import React from 'react';
import ParentAccountSetup from '../parent/ParentAccountSetup';

interface TeacherAccountManagementProps {
  teacherId: string;
  teacherName: string;
}

const TeacherAccountManagement: React.FC<TeacherAccountManagementProps> = ({ teacherId, teacherName }) => {
  // المعلم يمكنه فقط إنشاء أولياء أمور
  return (
    <div className="space-y-6">
      <div className="bg-blue-50 p-6 rounded-2xl border-2 border-blue-200">
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
