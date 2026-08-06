import React, { useState, useRef } from 'react';
import {
  View, Text, TextInput, TouchableOpacity, StyleSheet,
  Animated, KeyboardAvoidingView, Platform, ScrollView, Alert
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import { Ionicons } from '@expo/vector-icons';

const SPEECH_MESSAGES = [
  'أهلاً يا بطل! جاهز نبدأ مغامرتنا التعليمية!',
  'يا هلا بالطالب! نهارك اليوم مليئة بالمعرفة!',
  'أهلاً وسهلاً يا بطل! لننسيم سالة خبرة جديدة!',
];

const AnimatedLottieView: any = null;

export default function StudentLoginScreen() {
  const insets = useSafeAreaInsets();
  const navigation = useNavigation<any>();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [isLogging, setIsLogging] = useState(false);
  const shakeAnim = useRef(new Animated.Value(0)).current;
  const floatAnims = useRef([
    new Animated.Value(0), new Animated.Value(0), new Animated.Value(0),
    new Animated.Value(0), new Animated.Value(0),
  ]).current;

  // Floating emojis animation
  React.useEffect(() => {
    const animations = floatAnims.map((anim, i) =>
      Animated.loop(
        Animated.sequence([
          Animated.timing(anim, { toValue: -15, duration: 2000 + i * 300, useNativeDriver: true }),
          Animated.timing(anim, { toValue: 0, duration: 2000 + i * 300, useNativeDriver: true }),
        ])
      ).start()
    );
  }, []);

  const shake = () => {
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
    Animated.sequence([
      Animated.timing(shakeAnim, { toValue: 15, duration: 50, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue: -15, duration: 50, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue: 15, duration: 50, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue: -15, duration: 50, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue: 0, duration: 50, useNativeDriver: true }),
    ]).start();
  };

  const handleLogin = () => {
    if (!username.trim() || !password.trim()) {
      shake();
      Alert.alert('☝️ الكام المطلوب', 'اكتب اسمك وكلمة السر الخاصة بك!');
      return;
    }

    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    setIsLogging(true);

    // Simulate login
    setTimeout(() => {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      setIsLogging(false);
      navigation.replace('StudentDashboard');
    }, 1500);
  };

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      style={[styles.container, { paddingTop: insets.top + 20 }]}
    >
      <ScrollView contentContainerStyle={styles.scroll} showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
        {/* Floating emojis background */}
        <View style={styles.floatingContainer}>
          {['📚', '🎨', '🚀', '⭐', '🎵'].map((emoji, i) => (
            <Animated.Text key={i} style={[styles.floatingEmoji, { transform: [{ translateY: floatAnims[i] }] }]}>
              {emoji}
            </Animated.Text>
          ))}
        </View>

        {/* Mascot */}
        <View style={styles.mascotCircle}>
          <Text style={styles.mascotText}>✌️</Text>
        </View>

        <Text style={styles.title}>أهلاً يا بطل!</Text>
        <Text style={styles.subtitle}>جاهز للمغامرة التعليمية</Text>

        <Animated.View style={{ transform: [{ translateX: shakeAnim }] }}>
          <View style={styles.card}>
            {/* Username */}
            <View style={styles.inputContainer}>
              <Ionicons name="person-circle-outline" size={22} color="#FF6B35" style={styles.inputIcon} />
              <TextInput
                style={styles.input}
                placeholder="اسمك أو رقمك"
                placeholderTextColor="#A0AEC0"
                value={username}
                onChangeText={setUsername}
                textAlign="right"
                autoCapitalize="none"
                onFocus={() => Haptics.selectionAsync()}
              />
            </View>

            {/* Password */}
            <View style={styles.inputContainer}>
              <Ionicons name="lock-closed-outline" size={20} color="#FF6B35" style={styles.inputIcon} />
              <TextInput
                style={[styles.input, { flex: 1 }]}
                placeholder="كلمة السر الخاصة"
                placeholderTextColor="#A0AEC0"
                value={password}
                onChangeText={setPassword}
                secureTextEntry={!showPassword}
                textAlign="right"
                onFocus={() => Haptics.selectionAsync()}
              />
              <TouchableOpacity onPress={() => setShowPassword(!showPassword)}>
                <Ionicons name={showPassword ? 'eye-off-outline' : 'eye-outline'} size={22} color="#718096" />
              </TouchableOpacity>
            </View>

            {/* Login Button */}
            <TouchableOpacity
              activeOpacity={0.8}
              onPress={handleLogin}
              disabled={isLogging}
            >
              <LinearGradient
                colors={['#FF6B35', '#FF6B9D', '#A78BFA']}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 0 }}
                style={[styles.loginButton, isLogging && { opacity: 0.7 }]}
              >
                <Text style={styles.loginText}>
                  {isLogging ? 'جارٍ الدخول... 🚀' : 'ادخل للمغامرة! 🚀'}
                </Text>
              </LinearGradient>
            </TouchableOpacity>
          </View>
        </Animated.View>

        {/* Speech bubble */}
        <View style={styles.speechBubble}>
          <Text style={styles.speechText}>
            {SPEECH_MESSAGES[Math.floor(Math.random() * SPEECH_MESSAGES.length)]}
          </Text>
          <View style={styles.speechTriangle} />
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#FFF5EE' },
  scroll: { alignItems: 'center', paddingBottom: 40, paddingHorizontal: 24 },
  floatingContainer: {
    position: 'absolute', top: 0, left: 0, right: 0,
    flexDirection: 'row', justifyContent: 'space-around', paddingTop: 20,
  },
  floatingEmoji: { fontSize: 28, opacity: 0.4 },
  mascotCircle: {
    width: 100, height: 100, borderRadius: 50,
    backgroundColor: '#FF6B35',
    justifyContent: 'center', alignItems: 'center',
    shadowColor: '#FF6B35', shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.4, shadowRadius: 20, elevation: 10,
    marginTop: 20, marginBottom: 16,
  },
  mascotText: { fontSize: 44 },
  title: { fontSize: 28, fontWeight: '900', color: '#2D3748', marginBottom: 6 },
  subtitle: { fontSize: 16, color: '#718096', marginBottom: 30, fontWeight: '600' },
  card: {
    width: '100%', backgroundColor: 'white', borderRadius: 28,
    padding: 28, shadowColor: '#000', shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.08, shadowRadius: 20, elevation: 6,
    borderWidth: 2, borderColor: '#FFE8D6',
  },
  inputContainer: {
    flexDirection: 'row', alignItems: 'center',
    backgroundColor: '#FFF8F4', borderRadius: 18,
    borderWidth: 2, borderColor: '#FFE0C8',
    paddingHorizontal: 16, marginBottom: 16,
    height: 56,
  },
  inputIcon: { marginRight: 12 },
  input: {
    flex: 1, fontSize: 16, fontWeight: '600',
    color: '#2D3748', height: 56,
  },
  loginButton: {
    height: 56, borderRadius: 18,
    justifyContent: 'center', alignItems: 'center',
    shadowColor: '#FF6B35', shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.4, shadowRadius: 16, elevation: 8,
  },
  loginText: { color: 'white', fontSize: 18, fontWeight: '900' },
  speechBubble: {
    backgroundColor: 'white', borderRadius: 20,
    padding: 16, marginTop: 20,
    borderWidth: 2, borderColor: '#FFE8D6',
    maxWidth: '90%',
    shadowColor: '#000', shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.05, shadowRadius: 12, elevation: 3,
  },
  speechText: { fontSize: 14, color: '#2D3748', fontWeight: '600', textAlign: 'center', lineHeight: 22 },
  speechTriangle: {
    position: 'absolute', bottom: -8, left: '50%', marginLeft: -8,
    width: 0, height: 0,
    borderLeftWidth: 8, borderRightWidth: 8, borderTopWidth: 10,
    borderLeftColor: 'transparent', borderRightColor: 'transparent', borderTopColor: 'white',
  },
});
