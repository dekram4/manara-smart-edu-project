import React, { useState, useEffect, useRef } from 'react';
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity,
  TextInput, Dimensions, Animated
} from 'react-native';
import * as Haptics from 'expo-haptics';
import * as Speech from 'expo-speech';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { addXP, addGems, unlockAchievement } from '../../utils/storage';

const { width } = Dimensions.get('window');

const ENCOURAGEMENT_MESSAGES = [
  'أحسنت! أنت بطل محترف!',
  'رائع! أنت الأفضل!',
  'ممتاز! كم أنت ذكي!',
  'برافو! أنت ستصبح عالماً يومما!',
  'عظيم! واصل في التميز!',
  'أنت بطل! استمر في النجاح!',
  'أنت نجم! اعتز بنفسك!',
];

const GREETING_MESSAGES = [
  'مرحبا! هل أنت جاهز للتعلم؟',
  'يا هلا! أهلا وسهلا في منصتنا!',
  'أهلا! اليوم رائع للتعلم!',
];

const QUICK_TOPICS = [
  { id: 'math', label: 'الرياضيات', icon: '🔢', color: '#60A5FA' },
  { id: 'science', label: 'العلوم', icon: '🔬', color: '#4ADE80' },
  { id: 'arabic', label: 'العربية', icon: '✍️', color: '#F59E0B' },
  { id: 'history', label: 'التاريخ', icon: '📚', color: '#A78BFA' },
];

export default function AvatarScreen({ navigation }: any) {
  const insets = useSafeAreaInsets();
  const [messages, setMessages] = useState<Array<{id: string; text: string; from: 'user' | 'avatar'; type?: 'encourage' | 'greet' | 'answer'}>>([]);
  const [inputText, setInputText] = useState('');
  const [isSpeaking, setIsSpeaking] = useState(false);
  const [avatarMood, setAvatarMood] = useState<'happy' | 'thinking' | 'talking'>('happy');
  const bounceAnim = useRef(new Animated.Value(0)).current;
  const scaleAnim = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    // Greeting on mount
    const greeting = GREETING_MESSAGES[Math.floor(Math.random() * GREETING_MESSAGES.length)];
    addMessage(greeting, 'avatar', 'greet');
    speak(greeting);
  }, []);

  useEffect(() => {
    // Bounce animation for avatar
    Animated.loop(
      Animated.sequence([
        Animated.timing(bounceAnim, { toValue: -10, duration: 500, useNativeDriver: true }),
        Animated.timing(bounceAnim, { toValue: 0, duration: 500, useNativeDriver: true }),
      ])
    ).start();
  }, []);

  const speak = (text: string) => {
    setIsSpeaking(true);
    setAvatarMood('talking');
    Speech.speak(text, {
      language: 'ar-SA',
      pitch: 1.2,
      rate: 0.9,
      onDone: () => { setIsSpeaking(false); setAvatarMood('happy'); },
    });
  };

  const addMessage = (text: string, from: 'user' | 'avatar', type?: string) => {
    setMessages(prev => [...prev, { id: Date.now().toString() + Math.random(), text, from, type: type as any }]);
  };

  const handleSend = async () => {
    if (!inputText.trim()) return;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    addMessage(inputText, 'user');
    setInputText('');

    // Simulate AI avatar response
    setAvatarMood('thinking');
    setTimeout(async () => {
      const responses = [
        'يا له سؤال جميل! دعني أفكر في ذلك...',
        'أحسنت! هذا موضوع ممتاز. تعلم معي يساعدك الأستفادة!',
        'واو! أنت تسأل كما يسأل العالمون. الإجابة: تعلم بالمثالة والتدريب!',
        'شكراً على السؤال! دعني أشرح لك بأسلوب بسيط...',
      ];
      const response = responses[Math.floor(Math.random() * responses.length)];
      addMessage(response, 'avatar', 'answer');
      speak(response);
      await addXP(10);
    }, 1500);
  };

  const handleEncourage = async () => {
    const msg = ENCOURAGEMENT_MESSAGES[Math.floor(Math.random() * ENCOURAGEMENT_MESSAGES.length)];
    addMessage(msg, 'avatar', 'encourage');
    speak(msg);
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    await addXP(5);
    await addGems(1);
    await unlockAchievement('avatar_friend', 'صديق الأفاتار');

    // Pulse animation
    Animated.sequence([
      Animated.timing(scaleAnim, { toValue: 1.2, duration: 200, useNativeDriver: true }),
      Animated.timing(scaleAnim, { toValue: 1, duration: 200, useNativeDriver: true }),
    ]).start();
  };

  const handleTopic = (topic: typeof QUICK_TOPICS[0]) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    const responses: Record<string, string> = {
      math: 'الرياضيات رائعة! دعني أساعدك في حل أي مسألة. الجمع والطرح والضرب سهلة جداً!',
      science: 'العلوم مجال رائع! من النباتات إلى الفضاء، العالم مليء بالأسرار!',
      arabic: 'اللغة العربية جميلة! تعلم القرآن والأدب والقصيد يجعلك أكثر ذكاءً.',
      history: 'التاريخ يعلمنا دروس المضي. دعني أروي لك قصة ممتعة!',
    };
    const text = responses[topic.id] || 'موضوع رائع! دعني أتعلم معك!';
    addMessage(text, 'avatar', 'answer');
    speak(text);
  };

  return (
    <View style={[styles.container, { paddingTop: insets.top + 16 }]}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Ionicons name="arrow-back" size={28} color="#2D3748" />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>🤖 صديقي الذكي</Text>
        <View style={{ width: 28 }} />
      </View>

      {/* Avatar Area */}
      <View style={styles.avatarArea}>
        <Animated.View style={[
          styles.avatarCircle,
          { transform: [{ translateY: bounceAnim }, { scale: scaleAnim }] },
          avatarMood === 'thinking' ? styles.avatarThinking : null,
          avatarMood === 'talking' ? styles.avatarTalking : null,
        ]}>
          <Text style={styles.avatarEmoji}>
            {avatarMood === 'thinking' ? '🤔' : avatarMood === 'talking' ? '🗣️' : '🤖'}
          </Text>
        </Animated.View>
        <View style={styles.statusBadge}>
          <View style={[styles.statusDot, { backgroundColor: isSpeaking ? '#4ADE80' : '#F59E0B' }]} />
          <Text style={styles.statusText}>
            {isSpeaking ? 'يتكلم...' : avatarMood === 'thinking' ? 'يفكر...' : 'جاهز!'}
          </Text>
        </View>

        {/* Encourage button */}
        <TouchableOpacity onPress={handleEncourage} style={styles.encourageBtn}>
          <Text style={styles.encourageText}>🎉 شجعني!</Text>
        </TouchableOpacity>
      </View>

      {/* Quick Topics */}
      <View style={styles.topicsRow}>
        {QUICK_TOPICS.map((topic) => (
          <TouchableOpacity
            key={topic.id}
            onPress={() => handleTopic(topic)}
            style={[styles.topicChip, { backgroundColor: topic.color + '20', borderColor: topic.color }]}
          >
            <Text style={{ fontSize: 20 }}>{topic.icon}</Text>
            <Text style={[styles.topicText, { color: topic.color }]}>{topic.label}</Text>
          </TouchableOpacity>
        ))}
      </View>

      {/* Messages */}
      <ScrollView style={styles.messagesArea} contentContainerStyle={{ paddingBottom: 20 }}>
        {messages.map((msg) => (
          <View
            key={msg.id}
            style={[
              styles.messageBubble,
              msg.from === 'user' ? styles.userBubble : styles.avatarBubble,
              msg.type === 'encourage' && styles.encourageBubble,
              msg.type === 'greet' && styles.greetBubble,
            ]}
          >
            {msg.from === 'avatar' && (
              <Text style={styles.avatarName}>🤖 صديقك الذكي</Text>
            )}
            <Text style={[styles.messageText, msg.from === 'user' ? styles.userText : styles.avatarText]}>
              {msg.text}
            </Text>
          </View>
        ))}
      </ScrollView>

      {/* Input */}
      <View style={styles.inputArea}>
        <TextInput
          style={styles.input}
          placeholder="اكتب سؤالك للصديق الذكي..."
          value={inputText}
          onChangeText={setInputText}
          multiline
          textAlign="right"
        />
        <TouchableOpacity onPress={handleSend} style={styles.sendBtn}>
          <Ionicons name="send" size={20} color="#FFF" />
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#FFF8F0' },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 20, paddingVertical: 12 },
  headerTitle: { fontSize: 22, fontWeight: '900', color: '#2D3748' },
  avatarArea: { alignItems: 'center', paddingVertical: 20 },
  avatarCircle: { width: 120, height: 120, borderRadius: 60, backgroundColor: '#A78BFA', justifyContent: 'center', alignItems: 'center', borderWidth: 4, borderColor: '#EDE9FE' },
  avatarThinking: { backgroundColor: '#F59E0B', borderColor: '#FFFBEE' },
  avatarTalking: { backgroundColor: '#4ADE80', borderColor: '#F0FDF4' },
  avatarEmoji: { fontSize: 60 },
  statusBadge: { flexDirection: 'row', alignItems: 'center', gap: 6, marginTop: 12, backgroundColor: '#FFF', paddingHorizontal: 14, paddingVertical: 6, borderRadius: 16, borderWidth: 1, borderColor: '#F0E6D8' },
  statusDot: { width: 8, height: 8, borderRadius: 4 },
  statusText: { fontSize: 13, fontWeight: '700', color: '#2D3748' },
  encourageBtn: { backgroundColor: '#FF6B35', paddingHorizontal: 20, paddingVertical: 10, borderRadius: 20, marginTop: 12 },
  encourageText: { fontSize: 15, fontWeight: '800', color: '#FFF' },
  topicsRow: { flexDirection: 'row', justifyContent: 'center', gap: 8, paddingHorizontal: 20, marginBottom: 12 },
  topicChip: { flexDirection: 'row', alignItems: 'center', gap: 4, paddingHorizontal: 12, paddingVertical: 8, borderRadius: 16, borderWidth: 1.5 },
  topicText: { fontSize: 12, fontWeight: '800' },
  messagesArea: { flex: 1, paddingHorizontal: 16 },
  messageBubble: { maxWidth: '85%', padding: 14, borderRadius: 20, marginVertical: 6 },
  userBubble: { alignSelf: 'flex-end', backgroundColor: '#FF6B35' },
  avatarBubble: { alignSelf: 'flex-start', backgroundColor: '#FFF', borderWidth: 1, borderColor: '#F0E6D8' },
  encourageBubble: { backgroundColor: '#FFFBEE', borderColor: '#F59E0B', borderWidth: 2 },
  greetBubble: { backgroundColor: '#F0FDF4', borderColor: '#4ADE80', borderWidth: 2 },
  avatarName: { fontSize: 12, fontWeight: '800', color: '#A78BFA', marginBottom: 6 },
  messageText: { fontSize: 15, fontWeight: '700', lineHeight: 22 },
  userText: { color: '#FFF' },
  avatarText: { color: '#2D3748' },
  inputArea: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingVertical: 12, backgroundColor: '#FFF', borderTopWidth: 1, borderTopColor: '#F0E6D8' },
  input: { flex: 1, backgroundColor: '#F7F2EC', borderRadius: 24, paddingHorizontal: 16, paddingVertical: 12, fontSize: 15, color: '#2D3748', maxHeight: 100, textAlign: 'right' },
  sendBtn: { width: 44, height: 44, borderRadius: 22, backgroundColor: '#A78BFA', justifyContent: 'center', alignItems: 'center', marginLeft: 10 },
});
