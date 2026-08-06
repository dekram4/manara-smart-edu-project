import React, { useState, useEffect, useRef } from 'react';
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity,
  TextInput, KeyboardAvoidingView, Platform, FlatList
} from 'react-native';
import * as Haptics from 'expo-haptics';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { getData, setData, STORAGE_KEYS, getSampleContacts } from '../../utils/storage';

interface Message {
  id: string;
  senderId: string;
  senderName: string;
  receiverId: string;
  receiverName: string;
  text: string;
  timestamp: string;
  read: boolean;
}

export default function ChatScreen({ navigation }: any) {
  const insets = useSafeAreaInsets();
  const [activeTab, setActiveTab] = useState<'private' | 'group'>('private');
  const [contacts, setContacts] = useState<any[]>([]);
  const [selectedContact, setSelectedContact] = useState<any>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputText, setInputText] = useState('');
  const [gradeMessages, setGradeMessages] = useState<any[]>([]);
  const scrollRef = useRef<ScrollView>(null);

  useEffect(() => {
    loadContacts();
    loadAllMessages();
    const interval = setInterval(loadAllMessages, 2000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    if (selectedContact) loadMessages();
  }, [selectedContact]);

  const loadContacts = async () => {
    const saved = await getData('manara_contacts', []);
    if (saved.length > 0) setContacts(saved);
    else setContacts(getSampleContacts());
  };

  const loadAllMessages = async () => {
    const all = await getData(STORAGE_KEYS.PRIVATE_MESSAGES, []);
    const grade = await getData(STORAGE_KEYS.CHAT_MESSAGES, []);
    setGradeMessages(grade);
    if (selectedContact) {
      const filtered = all.filter((m: Message) =>
        (m.senderId === 'student' && m.receiverId === selectedContact.id) ||
        (m.senderId === selectedContact.id && m.receiverId === 'student')
      );
      setMessages(filtered);
    }
  };

  const loadMessages = async () => {
    const all = await getData(STORAGE_KEYS.PRIVATE_MESSAGES, []);
    const filtered = all.filter((m: Message) =>
      (m.senderId === 'student' && m.receiverId === selectedContact.id) ||
      (m.senderId === selectedContact.id && m.receiverId === 'student')
    );
    setMessages(filtered);
  };

  const sendMessage = async () => {
    if (!inputText.trim() || !selectedContact) return;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);

    const newMsg: Message = {
      id: Date.now().toString(),
      senderId: 'student',
      senderName: 'أنا',
      receiverId: selectedContact.id,
      receiverName: selectedContact.name,
      text: inputText.trim(),
      timestamp: new Date().toISOString(),
      read: true,
    };

    const all = await getData(STORAGE_KEYS.PRIVATE_MESSAGES, []);
    all.push(newMsg);
    await setData(STORAGE_KEYS.PRIVATE_MESSAGES, all);
    setInputText('');
    loadMessages();

    // Simulate reply after 2 seconds
    setTimeout(async () => {
      const reply: Message = {
        id: (Date.now() + 1).toString(),
        senderId: selectedContact.id,
        senderName: selectedContact.name,
        receiverId: 'student',
        receiverName: 'أنا',
        text: 'شكرًا على رسالتك! 👍',
        timestamp: new Date().toISOString(),
        read: false,
      };
      const all2 = await getData(STORAGE_KEYS.PRIVATE_MESSAGES, []);
      all2.push(reply);
      await setData(STORAGE_KEYS.PRIVATE_MESSAGES, all2);
      loadMessages();
    }, 2000);
  };

  const sendGroupMessage = async () => {
    if (!inputText.trim()) return;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);

    const newMsg = {
      id: Date.now().toString(),
      senderId: 'student',
      senderName: 'أنا',
      grade: 'الصف السابس',
      text: inputText.trim(),
      timestamp: new Date().toISOString(),
    };

    const all = await getData(STORAGE_KEYS.CHAT_MESSAGES, []);
    all.push(newMsg);
    await setData(STORAGE_KEYS.CHAT_MESSAGES, all);
    setInputText('');
    setGradeMessages(all);
  };

  const renderPrivateChat = () => {
    if (!selectedContact) {
      return (
        <View style={styles.contactsList}>
          <Text style={styles.sectionTitle}>اختر من تريد التواصل معه</Text>
          {contacts.map((c) => (
            <TouchableOpacity
              key={c.id}
              onPress={() => {
                Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                setSelectedContact(c);
              }}
              style={styles.contactCard}
            >
              <View style={[styles.contactAvatar, { backgroundColor: c.role === 'teacher' ? '#60A5FA' : '#A78BFA' }]}>
                <Text style={styles.avatarText}>{c.name[0]}</Text>
              </View>
              <View style={styles.contactInfo}>
                <Text style={styles.contactName}>{c.name}</Text>
                <Text style={styles.contactRole}>{c.role === 'teacher' ? 'معلم' : 'مشرف'}</Text>
              </View>
              <Ionicons name="chevron-forward" size={20} color="#A0AEC0" />
            </TouchableOpacity>
          ))}
        </View>
      );
    }

    return (
      <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        {/* Chat header */}
        <View style={styles.chatHeader}>
          <TouchableOpacity onPress={() => setSelectedContact(null)}>
            <Ionicons name="arrow-back" size={24} color="#2D3748" />
          </TouchableOpacity>
          <View style={styles.chatHeaderInfo}>
            <View style={[styles.chatAvatar, { backgroundColor: selectedContact.role === 'teacher' ? '#60A5FA' : '#A78BFA' }]}>
              <Text style={styles.chatAvatarText}>{selectedContact.name[0]}</Text>
            </View>
            <Text style={styles.chatName}>{selectedContact.name}</Text>
          </View>
          <View style={{ width: 24 }} />
        </View>

        {/* Messages */}
        <ScrollView
          ref={scrollRef}
          style={styles.messagesArea}
          onContentSizeChange={() => scrollRef.current?.scrollToEnd({ animated: true })}
        >
          {messages.map((msg) => (
            <View
              key={msg.id}
              style={[
                styles.messageBubble,
                msg.senderId === 'student' ? styles.myBubble : styles.theirBubble
              ]}
            >
              <Text style={msg.senderId === 'student' ? styles.myText : styles.theirText}>
                {msg.text}
              </Text>
              <Text style={styles.msgTime}>
                {new Date(msg.timestamp).toLocaleTimeString('ar-SA', { hour: '2-digit', minute: '2-digit' })}
              </Text>
            </View>
          ))}
        </ScrollView>

        {/* Input */}
        <View style={styles.inputArea}>
          <TextInput
            style={styles.input}
            placeholder="اكتب رسالتك..."
            value={inputText}
            onChangeText={setInputText}
            multiline
          />
          <TouchableOpacity onPress={sendMessage} style={styles.sendBtn}>
            <Ionicons name="send" size={20} color="#FFF" />
          </TouchableOpacity>
        </View>
      </KeyboardAvoidingView>
    );
  };

  const renderGroupChat = () => (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <View style={styles.groupHeader}>
        <Ionicons name="people" size={20} color="#FF6B35" />
        <Text style={styles.groupTitle}>دردشة الصف</Text>
        <Text style={styles.groupSubtitle}>الصف السابس</Text>
      </View>

      <ScrollView style={styles.messagesArea}>
        {gradeMessages.map((msg) => (
          <View
            key={msg.id}
            style={[
              styles.messageBubble,
              msg.senderId === 'student' ? styles.myBubble : styles.theirBubble
            ]}
          >
            {msg.senderId !== 'student' && (
              <Text style={styles.senderName}>{msg.senderName}</Text>
            )}
            <Text style={msg.senderId === 'student' ? styles.myText : styles.theirText}>
              {msg.text}
            </Text>
            <Text style={styles.msgTime}>
              {new Date(msg.timestamp).toLocaleTimeString('ar-SA', { hour: '2-digit', minute: '2-digit' })}
            </Text>
          </View>
        ))}
      </ScrollView>

      <View style={styles.inputArea}>
        <TextInput
          style={styles.input}
          placeholder="اكتب رسالتك للمجموعة..."
          value={inputText}
          onChangeText={setInputText}
          multiline
        />
        <TouchableOpacity onPress={sendGroupMessage} style={styles.sendBtn}>
          <Ionicons name="send" size={20} color="#FFF" />
        </TouchableOpacity>
      </View>
    </KeyboardAvoidingView>
  );

  return (
    <View style={[styles.container, { paddingTop: insets.top + 16 }]}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Ionicons name="arrow-back" size={28} color="#2D3748" />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>💬 الدردشة</Text>
        <View style={{ width: 28 }} />
      </View>

      {/* Tabs */}
      <View style={styles.tabs}>
        <TouchableOpacity
          onPress={() => { setActiveTab('private'); setSelectedContact(null); }}
          style={[styles.tab, activeTab === 'private' && styles.tabActive]}
        >
          <Text style={[styles.tabText, activeTab === 'private' && styles.tabTextActive]}>خاص</Text>
        </TouchableOpacity>
        <TouchableOpacity
          onPress={() => setActiveTab('group')}
          style={[styles.tab, activeTab === 'group' && styles.tabActive]}
        >
          <Text style={[styles.tabText, activeTab === 'group' && styles.tabTextActive]}>جماعي</Text>
        </TouchableOpacity>
      </View>

      {activeTab === 'private' ? renderPrivateChat() : renderGroupChat()}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#FFF8F0' },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 20, paddingVertical: 12 },
  headerTitle: { fontSize: 22, fontWeight: '900', color: '#2D3748' },
  tabs: { flexDirection: 'row', paddingHorizontal: 20, gap: 8, marginBottom: 8 },
  tab: { flex: 1, paddingVertical: 12, borderRadius: 16, backgroundColor: '#FFF', alignItems: 'center', borderWidth: 1, borderColor: '#F0E6D8' },
  tabActive: { backgroundColor: '#FF6B35', borderColor: '#FF6B35' },
  tabText: { fontSize: 15, fontWeight: '700', color: '#718096' },
  tabTextActive: { color: '#FFF' },
  contactsList: { flex: 1, paddingHorizontal: 20 },
  sectionTitle: { fontSize: 16, fontWeight: '700', color: '#A0AEC0', marginVertical: 16 },
  contactCard: { flexDirection: 'row', alignItems: 'center', backgroundColor: '#FFF', borderRadius: 20, padding: 16, marginBottom: 12, borderWidth: 1, borderColor: '#F0E6D8' },
  contactAvatar: { width: 48, height: 48, borderRadius: 24, justifyContent: 'center', alignItems: 'center' },
  avatarText: { fontSize: 20, fontWeight: '800', color: '#FFF' },
  contactInfo: { flex: 1, marginHorizontal: 12 },
  contactName: { fontSize: 16, fontWeight: '800', color: '#2D3748' },
  contactRole: { fontSize: 13, color: '#A0AEC0', marginTop: 2 },
  chatHeader: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20, paddingVertical: 12, borderBottomWidth: 1, borderBottomColor: '#F0E6D8', backgroundColor: '#FFF' },
  chatHeaderInfo: { flex: 1, flexDirection: 'row', alignItems: 'center', marginHorizontal: 12 },
  chatAvatar: { width: 40, height: 40, borderRadius: 20, justifyContent: 'center', alignItems: 'center', marginLeft: 8 },
  chatAvatarText: { fontSize: 16, fontWeight: '800', color: '#FFF' },
  chatName: { fontSize: 16, fontWeight: '800', color: '#2D3748', marginLeft: 10 },
  messagesArea: { flex: 1, paddingHorizontal: 16, paddingVertical: 8 },
  messageBubble: { maxWidth: '80%', padding: 12, borderRadius: 20, marginVertical: 4 },
  myBubble: { alignSelf: 'flex-start', backgroundColor: '#FF6B35' },
  theirBubble: { alignSelf: 'flex-end', backgroundColor: '#FFF', borderWidth: 1, borderColor: '#F0E6D8' },
  myText: { fontSize: 15, color: '#FFF', fontWeight: '600', lineHeight: 22 },
  theirText: { fontSize: 15, color: '#2D3748', fontWeight: '600', lineHeight: 22 },
  senderName: { fontSize: 12, fontWeight: '700', color: '#FF6B35', marginBottom: 4 },
  msgTime: { fontSize: 11, color: 'rgba(255,255,255,0.7)', marginTop: 4, alignSelf: 'flex-end' },
  inputArea: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingVertical: 10, backgroundColor: '#FFF', borderTopWidth: 1, borderTopColor: '#F0E6D8' },
  input: { flex: 1, backgroundColor: '#F7F2EC', borderRadius: 24, paddingHorizontal: 16, paddingVertical: 10, fontSize: 15, color: '#2D3748', maxHeight: 100, textAlign: 'right' },
  sendBtn: { width: 44, height: 44, borderRadius: 22, backgroundColor: '#FF6B35', justifyContent: 'center', alignItems: 'center', marginLeft: 10 },
  groupHeader: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20, paddingVertical: 12, gap: 8 },
  groupTitle: { fontSize: 16, fontWeight: '800', color: '#2D3748' },
  groupSubtitle: { fontSize: 13, color: '#A0AEC0' },
});
