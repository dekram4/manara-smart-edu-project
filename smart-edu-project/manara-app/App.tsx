import React, { useState, useEffect, createContext, useContext } from 'react';
import { View, Text, StatusBar } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createStackNavigator } from '@react-navigation/stack';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { SafeAreaProvider, useSafeAreaInsets } from 'react-native-safe-area-context';

import RoleSelectScreen from './screens/RoleSelectScreen';
import StudentLoginScreen from './screens/student/StudentLoginScreen';
import StudentDashboardScreen from './screens/student/StudentDashboardScreen';
import LessonsScreen from './screens/student/LessonsScreen';
import LessonDetailScreen from './screens/student/LessonDetailScreen';
import QuizScreen from './screens/student/QuizScreen';
import ChatScreen from './screens/student/ChatScreen';
import VideosScreen from './screens/student/VideosScreen';
import MathSolverScreen from './screens/student/MathSolverScreen';

import MemoryGameScreen from './screens/student/games/MemoryGameScreen';
import TrueFalseGameScreen from './screens/student/games/TrueFalseGameScreen';
import SpeedQuizScreen from './screens/student/games/SpeedQuizScreen';
import AvatarScreen from './screens/student/AvatarScreen';
import LiveMeetingScreen from './screens/student/LiveMeetingScreen';
import QuestScreen from './screens/student/QuestScreen';
import LeaderboardScreen from './screens/student/LeaderboardScreen';

import TeacherLoginScreen from './screens/teacher/TeacherLoginScreen';
import TeacherDashboardScreen from './screens/teacher/TeacherDashboardScreen';
import ParentLoginScreen from './screens/parent/ParentLoginScreen';
import ParentDashboardScreen from './screens/parent/ParentDashboardScreen';
import AdminLoginScreen from './screens/admin/AdminLoginScreen';
import AdminDashboardScreen from './screens/admin/AdminDashboardScreen';

export type UserRole = 'student' | 'teacher' | 'parent' | 'admin' | null;

interface AuthContextType {
  role: UserRole;
  user: any;
  isLoading: boolean;
  setRole: (role: UserRole) => void;
  setUser: (user: any) => void;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType>({
  role: null, user: null, isLoading: true,
  setRole: () => {}, setUser: () => {}, logout: () => {},
});

export const useAuth = () => useContext(AuthContext);

const Stack = createStackNavigator();

function AppContent() {
  const insets = useSafeAreaInsets();
  const [role, setRole] = useState<UserRole>(null);
  const [user, setUser] = useState<any>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    (async () => {
      try {
        const savedRole = await AsyncStorage.getItem('manara_role');
        const savedUser = await AsyncStorage.getItem('manara_user');
        if (savedRole) setRole(savedRole as UserRole);
        if (savedUser) setUser(JSON.parse(savedUser));
      } catch (e) {}
      setIsLoading(false);
    })();
  }, []);

  const handleSetRole = async (newRole: UserRole) => {
    setRole(newRole);
    if (newRole) await AsyncStorage.setItem('manara_role', newRole);
    else await AsyncStorage.removeItem('manara_role');
  };

  const handleSetUser = async (newUser: any) => {
    setUser(newUser);
    if (newUser) await AsyncStorage.setItem('manara_user', JSON.stringify(newUser));
    else await AsyncStorage.removeItem('manara_user');
  };

  const logout = async () => {
    setRole(null);
    setUser(null);
    await AsyncStorage.removeItem('manara_role');
    await AsyncStorage.removeItem('manara_user');
  };

  if (isLoading) {
    return (
      <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: '#FFF8F0' }}>
        <View style={{ width: 60, height: 60, borderRadius: 30, backgroundColor: '#FF6B35', justifyContent: 'center', alignItems: 'center' }}>
          <Text style={{ fontSize: 30 }}>✌️</Text>
        </View>
        <Text style={{ marginTop: 16, fontSize: 20, fontWeight: '900', color: '#2D3748' }}>منارة المعرفة</Text>
        <Text style={{ marginTop: 8, fontSize: 14, color: '#718096' }}>جارٍ تحميل...</Text>
      </View>
    );
  }

  return (
    <AuthContext.Provider value={{ role, user, isLoading, setRole: handleSetRole, setUser: handleSetUser, logout }}>
      <NavigationContainer>
        <StatusBar barStyle="dark-content" backgroundColor="#FFF8F0" />
        <Stack.Navigator screenOptions={{ headerShown: false }}>
          {!role ? (
            <Stack.Screen name="RoleSelect" component={RoleSelectScreen} />
          ) : (
            <>
              {role === 'student' && (
                <>
                  <Stack.Screen name="StudentLogin" component={StudentLoginScreen} />
                  <Stack.Screen name="StudentDashboard" component={StudentDashboardScreen} />
                  <Stack.Screen name="Lessons" component={LessonsScreen} />
                  <Stack.Screen name="LessonDetail" component={LessonDetailScreen} />
                  <Stack.Screen name="Quiz" component={QuizScreen} />
                  <Stack.Screen name="Chat" component={ChatScreen} />
                  <Stack.Screen name="Videos" component={VideosScreen} />
                  <Stack.Screen name="MathSolver" component={MathSolverScreen} />
                  {/* Games */}
                  <Stack.Screen name="MemoryGame" component={MemoryGameScreen} />
                  <Stack.Screen name="TrueFalseGame" component={TrueFalseGameScreen} />
                  <Stack.Screen name="SpeedQuiz" component={SpeedQuizScreen} />
                  <Stack.Screen name="Avatar" component={AvatarScreen} />
                  <Stack.Screen name="LiveMeeting" component={LiveMeetingScreen} />
                  <Stack.Screen name="Quests" component={QuestScreen} />
                  <Stack.Screen name="Leaderboard" component={LeaderboardScreen} />
                </>
              )}
              {role === 'teacher' && (
                <>
                  <Stack.Screen name="TeacherLogin" component={TeacherLoginScreen} />
                  <Stack.Screen name="TeacherDashboard" component={TeacherDashboardScreen} />
                </>
              )}
              {role === 'parent' && (
                <>
                  <Stack.Screen name="ParentLogin" component={ParentLoginScreen} />
                  <Stack.Screen name="ParentDashboard" component={ParentDashboardScreen} />
                </>
              )}
              {role === 'admin' && (
                <>
                  <Stack.Screen name="AdminLogin" component={AdminLoginScreen} />
                  <Stack.Screen name="AdminDashboard" component={AdminDashboardScreen} />
                </>
              )}
            </>
          )}
        </Stack.Navigator>
      </NavigationContainer>
    </AuthContext.Provider>
  );
}

export default function App() {
  return (
    <SafeAreaProvider>
      <AppContent />
    </SafeAreaProvider>
  );
}
