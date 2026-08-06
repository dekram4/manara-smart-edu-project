import React, { useState } from 'react';
import {
  View, Text, TextInput, TouchableOpacity, StyleSheet,
  KeyboardAvoidingView, Platform, ScrollView, Alert
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import { Ionicons } from '@expo/vector-icons';

export default function TeacherLoginScreen() {
  const insets = useSafeAreaInsets();
  const navigation = useNavigation<any>();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [isLogging, setIsLogging] = useState(false);

  const handleLogin = () => {
    if (!username.trim() || !password.trim()) {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      Alert.alert('ملاحظة', 'الرجاء إدخال البيانات');
      return;
    }
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    setIsLogging(true);
    setTimeout(() => {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      setIsLogging(false);
      navigation.replace('TeacherDashboard');
    }, 1200);
  };

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      style={[styles.container, { paddingTop: insets.top + 20 }]}
    >
      <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
        <View style={styles.mascotCircle}>
          <Text style={styles.mascotText}>👨‍🏫</Text>
        </View>
        <Text style={styles.title}>مرحباً يا معلم!</Text>
        <Text style={styles.subtitle}>ادخل لإدارة محتواك وطلابك</Text>

        <View style={styles.card}>
          <View style={styles.inputContainer}>
            <Ionicons name="person-circle-outline" size={22} color="#F59E0B" style={styles.inputIcon} />
            <TextInput style={styles.input} placeholder="اسم المستخدم" placeholderTextColor="#A0AEC0" value={username} onChangeText={setUsername} textAlign="right" onFocus={() => Haptics.selectionAsync()} />
          </View>
          <View style={styles.inputContainer}>
            <Ionicons name="lock-closed-outline" size={20} color="#F59E0B" style={styles.inputIcon} />
            <TextInput style={[styles.input, { flex: 1 }]} placeholder="كلمة المرور" placeholderTextColor="#A0AEC0" value={password} onChangeText={setPassword} secureTextEntry={!showPassword} textAlign="right" onFocus={() => Haptics.selectionAsync()} />
            <TouchableOpacity onPress={() => setShowPassword(!showPassword)}>
              <Ionicons name={showPassword ? 'eye-off-outline' : 'eye-outline'} size={22} color="#718096" />
            </TouchableOpacity>
          </View>
          <TouchableOpacity activeOpacity={0.8} onPress={handleLogin} disabled={isLogging}>
            <LinearGradient colors={['#F59E0B', '#FB923C', '#FF6B35']} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} style={[styles.loginButton, isLogging && { opacity: 0.7 }]}>
              <Text style={styles.loginText}>{isLogging ? 'جارٍ الدخول...' : 'دخول المعلم!'}</Text>
            </LinearGradient>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#FFFBF0' },
  scroll: { alignItems: 'center', paddingBottom: 40, paddingHorizontal: 24 },
  mascotCircle: { width: 100, height: 100, borderRadius: 50, backgroundColor: '#F59E0B', justifyContent: 'center', alignItems: 'center', shadowColor: '#F59E0B', shadowOffset: { width: 0, height: 8 }, shadowOpacity: 0.4, shadowRadius: 20, elevation: 10, marginTop: 20, marginBottom: 16 },
  mascotText: { fontSize: 44 },
  title: { fontSize: 28, fontWeight: '900', color: '#2D3748', marginBottom: 6 },
  subtitle: { fontSize: 16, color: '#718096', marginBottom: 30, fontWeight: '600' },
  card: { width: '100%', backgroundColor: 'white', borderRadius: 28, padding: 28, shadowColor: '#000', shadowOffset: { width: 0, height: 8 }, shadowOpacity: 0.08, shadowRadius: 20, elevation: 6, borderWidth: 2, borderColor: '#FEF3C7' },
  inputContainer: { flexDirection: 'row', alignItems: 'center', backgroundColor: '#FFFBF0', borderRadius: 18, borderWidth: 2, borderColor: '#FEF3C7', paddingHorizontal: 16, marginBottom: 16, height: 56 },
  inputIcon: { marginRight: 12 },
  input: { flex: 1, fontSize: 16, fontWeight: '600', color: '#2D3748', height: 56 },
  loginButton: { height: 56, borderRadius: 18, justifyContent: 'center', alignItems: 'center', shadowColor: '#F59E0B', shadowOffset: { width: 0, height: 6 }, shadowOpacity: 0.4, shadowRadius: 16, elevation: 8 },
  loginText: { color: 'white', fontSize: 18, fontWeight: '900' },
});
