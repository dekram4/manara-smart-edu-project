
import React from 'react';
import ParentStudentManagement from './ParentStudentManagement';

interface TeacherAccountManagementProps {
  teacherId: string;
  teacherName: string;
}

const TeacherAccountManagement: React.FC<TeacherAccountManagementProps> = ({ teacherId, teacherName }) => {
  return <ParentStudentManagement teacherId={teacherId} teacherName={teacherName} />;
};

export default TeacherAccountManagement;
