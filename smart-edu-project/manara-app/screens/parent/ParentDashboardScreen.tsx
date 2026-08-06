import React, { useState } from 'react';
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity, Alert
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useAuth } from '../../App';

const TABS = [
  { id: 'home', label: 'الرئيسية', icon: 'home' },
  { id: 'children', label: 'أبنائي', icon: 'people' },
  { id: 'reports', label: 'التقارير', icon: 'document-text' },
  { id: 'profile', label: 'حسابي', icon: 'person' },
];

const CHILDREN = [
  { id: '1', name: 'أحمد', grade: 'الصف السابس', progress: 85, attendance: '95%', color: '#F59E0B' },
  { id: '2', name: 'فاطمة', grade: 'الصف الرابع', progress: 92, attendance: '98%', color: '#FB7185' },
];

export default function ParentDashboardScreen() {
  const insets = useSafeAreaInsets();
  const { logout } = useAuth();
  const [activeTab, setActiveTab] = useState('home');

  const renderHome = () => (
    <View style={styles.tabContent}>
      <View style={styles.summaryCard}>
        <Text style={styles.summaryTitle}>ملخص الأبناء</Text>
        <View style={styles.summaryRow}>
          <View style={styles.summaryItem}>
            <Text style={styles.summaryValue}>2</Text>
            <Text style={styles.summaryLabel}>أبناء</Text>
          </View>
          <View style={styles.summaryDivider} />
          <View style={styles.summaryItem}>
            <Text style={styles.summaryValue}>88%</Text>
            <Text style={styles.summaryLabel}>معدل التقدم</Text>
          </View>
          <View style={styles.summaryDivider} />
          <View style={styles.summaryItem}>
            <Text style={styles.summaryValue}>96%</Text>
            <Text style={styles.summaryLabel}>الحضور</Text>
          </View>
        </View>
      </View>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>أبنائي</Text>
        {CHILDREN.map((child) => (
          <View key={child.id} style={styles.childCard}>
            <View style={[styles.childAvatar, { backgroundColor: child.color + '20' }]}>
              <Text style={{ fontSize: 28 }}>👨‍🧐</Text>
            </View>
            <View style={styles.childInfo}>
              <Text style={styles.childName}>{child.name}</Text>
              <Text style={styles.childGrade}>{child.grade}</Text>
              <View style={styles.childProgressBar}>
                <View style={[styles.childProgressFill, { width: `${child.progress}%`, backgroundColor: child.color }]} />
              </View>
            </View>
            <View style={styles.childStats}>
              <Text style={[styles.childPercent, { color: child.color }]}>{child.progress}%</Text>
              <Text style={styles.childAttendance}>الحضور {child.attendance}</Text>
            </View>
          </View>
        ))}
      </View>
    </View>
  );

  return (
    <View style={styles.container}>
      <LinearGradient colors={['#FB7185', '#F472B6', '#A78BFA']} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={[styles.header, { paddingTop: insets.top + 16 }]}>
        <View style={styles.headerTop}>
          <View style={styles.avatar}><Text style={{ fontSize: 30 }}>👨‍👩‍👧‍👦</Text></View>
          <View style={styles.headerInfo}>
            <Text style={styles.headerName}>مرحباً يا ولي أمر!</Text>
            <Text style={styles.headerSub}>تابع أداء أبنائك</Text>
          </View>
        </View>
      </LinearGradient>

      <ScrollView contentContainerStyle={styles.scrollContent} showsVerticalScrollIndicator={false}>
        {activeTab === 'home' && renderHome()}
        {activeTab === 'children' && renderHome()}
        {activeTab === 'reports' && renderHome()}
        {activeTab === 'profile' && (
          <View style={styles.tabContent}>
            <TouchableOpacity activeOpacity={0.7} onPress={() => { Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy); logout(); }} style={styles.logoutButton}>
              <Ionicons name="log-out-outline" size={22} color="#EF4444" />
              <Text style={styles.logoutText}>تسجيل الخروج</Text>
            </TouchableOpacity>
          </View>
        )}
      </ScrollView>

      <View style={[styles.bottomNav, { paddingBottom: insets.bottom + 8 }]}>
        {TABS.map((tab) => (
          <TouchableOpacity key={tab.id} activeOpacity={0.7} onPress={() => { Haptics.selectionAsync(); setActiveTab(tab.id); }} style={[styles.navItem, activeTab === tab.id && styles.navItemActive]}>
            <Ionicons name={tab.icon as any} size={24} color={activeTab === tab.id ? '#FB7185' : '#A0AEC0'} />
            <Text style={[styles.navLabel, activeTab === tab.id && { color: '#FB7185', fontWeight: '800' }]}>{tab.label}</Text>
          </TouchableOpacity>
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#FFF5F7' },
  header: { paddingHorizontal: 20, paddingBottom: 24, borderBottomLeftRadius: 32, borderBottomRightRadius: 32, shadowColor: '#FB7185', shadowOffset: { width: 0, height: 8 }, shadowOpacity: 0.3, shadowRadius: 20, elevation: 8 },
  headerTop: { flexDirection: 'row', alignItems: 'center' },
  avatar: { width: 50, height: 50, borderRadius: 25, backgroundColor: 'rgba(255,255,255,0.25)', justifyContent: 'center', alignItems: 'center', borderWidth: 2, borderColor: 'rgba(255,255,255,0.4)' },
  headerInfo: { flex: 1, marginLeft: 12 },
  headerName: { fontSize: 18, fontWeight: '900', color: 'white' },
  headerSub: { fontSize: 13, color: 'rgba(255,255,255,0.85)', marginTop: 2, fontWeight: '600' },
  scrollContent: { paddingBottom: 100 },
  tabContent: { padding: 20 },
  summaryCard: { backgroundColor: 'white', borderRadius: 24, padding: 20, marginBottom: 20, shadowColor: '#000', shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.06, shadowRadius: 12, elevation: 4, borderWidth: 2, borderColor: '#F0F0F0' },
  summaryTitle: { fontSize: 18, fontWeight: '900', color: '#2D3748', marginBottom: 16 },
  summaryRow: { flexDirection: 'row', justifyContent: 'space-around', alignItems: 'center' },
  summaryItem: { alignItems: 'center' },
  summaryValue: { fontSize: 28, fontWeight: '900', color: '#FB7185' },
  summaryLabel: { fontSize: 12, color: '#A0AEC0', fontWeight: '700', marginTop: 4 },
  summaryDivider: { width: 1, height: 40, backgroundColor: '#F0F0F0' },
  section: { marginBottom: 20 },
  sectionTitle: { fontSize: 20, fontWeight: '900', color: '#2D3748', marginBottom: 14 },
  childCard: { flexDirection: 'row', alignItems: 'center', backgroundColor: 'white', borderRadius: 20, padding: 14, marginBottom: 10, shadowColor: '#000', shadowOffset: { width: 0, height: 3 }, shadowOpacity: 0.05, shadowRadius: 10, elevation: 3, borderWidth: 2, borderColor: '#F0F0F0' },
  childAvatar: { width: 52, height: 52, borderRadius: 16, justifyContent: 'center', alignItems: 'center' },
  childInfo: { flex: 1, marginHorizontal: 12 },
  childName: { fontSize: 16, fontWeight: '800', color: '#2D3748' },
  childGrade: { fontSize: 13, color: '#718096', marginTop: 2, fontWeight: '600' },
  childProgressBar: { height: 8, backgroundColor: '#F3F4F6', borderRadius: 6, overflow: 'hidden', marginTop: 8 },
  childProgressFill: { height: '100%', borderRadius: 6 },
  childStats: { alignItems: 'center' },
  childPercent: { fontSize: 18, fontWeight: '900' },
  childAttendance: { fontSize: 11, color: '#A0AEC0', fontWeight: '600', marginTop: 2 },
  logoutButton: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', backgroundColor: '#FFF0F0', borderRadius: 18, padding: 16, marginTop: 20, gap: 8, borderWidth: 2, borderColor: '#FEE2E2' },
  logoutText: { fontSize: 16, fontWeight: '800', color: '#EF4444' },
  bottomNav: { position: 'absolute', bottom: 0, left: 0, right: 0, backgroundColor: 'white', borderTopWidth: 2, borderTopColor: '#FCE7F3', flexDirection: 'row', justifyContent: 'space-around', paddingTop: 8, paddingHorizontal: 10, shadowColor: '#000', shadowOffset: { width: 0, height: -4 }, shadowOpacity: 0.05, shadowRadius: 12, elevation: 8 },
  navItem: { alignItems: 'center', paddingHorizontal: 12, paddingVertical: 6, borderRadius: 16 },
  navItemActive: { backgroundColor: '#FFF5F7', transform: [{ translateY: -4 }] },
  navLabel: { fontSize: 10, color: '#A0AEC0', marginTop: 2, fontWeight: '600' },
});
