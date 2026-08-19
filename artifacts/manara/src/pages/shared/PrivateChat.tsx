import React, { useState, useEffect, useRef } from 'react';
import { STORAGE_KEYS, COLORS } from '../../constants';
import { getParentTeacherId, getTeacherParents, normalizeScopeValue } from '../../utils/scope';

interface Message {
  id: string;
  senderId: string;
  senderName: string;
  senderRole: 'admin' | 'teacher' | 'parent';
  receiverId: string;
  receiverName: string;
  message: string;
  timestamp: string;
  read: boolean;
}

interface PrivateChatProps {
  currentUserId: string;
  currentUserName: string;
  currentUserRole: 'admin' | 'teacher' | 'parent';
  onClose: () => void;
}

const PrivateChat: React.FC<PrivateChatProps> = ({ 
  currentUserId, 
  currentUserName, 
  currentUserRole, 
  onClose 
}) => {
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [contacts, setContacts] = useState<Array<{id: string, name: string, role: 'admin' | 'teacher' | 'parent'}>>([]);
  const [selectedContact, setSelectedContact] = useState<{id: string, name: string, role: string} | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const [adminContact, setAdminContact] = useState('');

  useEffect(() => {
    loadContacts();
    loadMessages();
    loadAdminContact();
    
    const interval = window.setInterval(() => {
      loadMessages();
    }, 4000);
    
    return () => window.clearInterval(interval);
  }, [selectedContact]);

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  const loadAdminContact = () => {
    const settings = JSON.parse(localStorage.getItem(STORAGE_KEYS.ADMIN_SETTINGS) || '{}');
    setAdminContact(settings.adminContactInfo || '');
  };

  const loadContacts = () => {
    const contactsList: Array<{id: string, name: string, role: 'admin' | 'teacher' | 'parent'}> = [];
    
    if (currentUserRole === 'admin') {
      // المشرف يمكنه التواصل مع جميع المعلمين وأولياء الأمور
      const teachers = JSON.parse(localStorage.getItem(STORAGE_KEYS.TEACHERS) || '[]');
      teachers.forEach((teacher: any) => {
        contactsList.push({ id: teacher.id, name: teacher.name, role: 'teacher' });
      });
      
      const parents = JSON.parse(localStorage.getItem(STORAGE_KEYS.PARENTS) || '[]');
      parents.forEach((parent: any) => {
        contactsList.push({ id: parent.id, name: parent.name, role: 'parent' });
      });
    } else {
      // دائماً يمكن التواصل مع المشرف (للمعلمين وأولياء الأمور)
      contactsList.push({ id: 'admin', name: 'المشرف', role: 'admin' });

      if (currentUserRole === 'parent') {
        // ولي الأمر يمكنه التواصل فقط مع المعلم الذي أنشأه
        const parents = JSON.parse(localStorage.getItem(STORAGE_KEYS.PARENTS) || '[]');
        const myParent = parents.find((p: any) => p.id === currentUserId);
        const students = JSON.parse(localStorage.getItem(STORAGE_KEYS.STUDENTS) || '[]');
        const parentTeacherId = myParent ? getParentTeacherId(myParent, students) : '';
        if (parentTeacherId) {
          const teachers = JSON.parse(localStorage.getItem(STORAGE_KEYS.TEACHERS) || '[]');
          const teacher = teachers.find((t: any) =>
            normalizeScopeValue(t.id) === parentTeacherId,
          );
          if (teacher) {
            contactsList.push({ id: teacher.id, name: teacher.name, role: 'teacher' });
          }
        }
      } else if (currentUserRole === 'teacher') {
        // المعلم يمكنه التواصل مع أولياء أمور أنشأهم هو فقط
        const parents = JSON.parse(localStorage.getItem(STORAGE_KEYS.PARENTS) || '[]');
        const myParents = getTeacherParents(parents, currentUserId);
        myParents.forEach((parent: any) => {
          contactsList.push({ id: parent.id, name: parent.name, role: 'parent' });
        });
      }
    }

    setContacts(contactsList);
    if (contactsList.length > 0 && !selectedContact) {
      setSelectedContact(contactsList[0]);
    }
  };

  const loadMessages = () => {
    if (!selectedContact) return;

    const allMessages: Message[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.PRIVATE_MESSAGES) || '[]');
    
    // تصفية الرسائل بين المستخدم الحالي والشخص المختار فقط
    const conversationMessages = allMessages.filter(msg => 
      (msg.senderId === currentUserId && msg.receiverId === selectedContact.id) ||
      (msg.senderId === selectedContact.id && msg.receiverId === currentUserId)
    );

    // ترتيب حسب الوقت
    conversationMessages.sort((a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime());

    setMessages(conversationMessages);

    // تحديث حالة القراءة
    const updatedMessages = allMessages.map(msg => {
      if (msg.receiverId === currentUserId && msg.senderId === selectedContact.id && !msg.read) {
        return { ...msg, read: true };
      }
      return msg;
    });
    localStorage.setItem(STORAGE_KEYS.PRIVATE_MESSAGES, JSON.stringify(updatedMessages));
  };

  const handleSendMessage = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newMessage.trim() || !selectedContact) return;

    const allMessages: Message[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.PRIVATE_MESSAGES) || '[]');
    
    const message: Message = {
      id: Date.now().toString(),
      senderId: currentUserId,
      senderName: currentUserName,
      senderRole: currentUserRole,
      receiverId: selectedContact.id,
      receiverName: selectedContact.name,
      message: newMessage.trim(),
      timestamp: new Date().toISOString(),
      read: false
    };

    allMessages.push(message);
    localStorage.setItem(STORAGE_KEYS.PRIVATE_MESSAGES, JSON.stringify(allMessages));

    setNewMessage('');
    loadMessages();
  };

  const getUnreadCount = (contactId: string) => {
    const allMessages: Message[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.PRIVATE_MESSAGES) || '[]');
    return allMessages.filter(msg => 
      msg.senderId === contactId && 
      msg.receiverId === currentUserId && 
      !msg.read
    ).length;
  };

  const getRoleIcon = (role: string) => {
    switch(role) {
      case 'admin': return '👨‍💼';
      case 'teacher': return '👨‍🏫';
      case 'parent': return '👨‍👦';
      default: return '👤';
    }
  };

  const getRoleLabel = (role: string) => {
    switch(role) {
      case 'admin': return 'المشرف';
      case 'teacher': return 'معلم';
      case 'parent': return 'ولي أمر';
      default: return '';
    }
  };

  return (
     <div className="dashboard-chat-overlay" style={styles.overlay}>
       <div className="dashboard-chat-container" style={styles.container}>
        {/* Header */}
         <div className="dashboard-chat-header" style={styles.header}>
          <h2 style={styles.headerTitle}>💬 الدردشة الخاصة</h2>
          <button onClick={onClose} style={styles.closeButton}>✖</button>
        </div>

         <div className="dashboard-chat-content" style={styles.content}>
          {/* Contacts Sidebar */}
           <div className="dashboard-chat-contacts" style={styles.sidebar}>
            <h3 style={styles.sidebarTitle}>جهات الاتصال</h3>
            
            {adminContact && currentUserRole === 'teacher' && (
              <div style={styles.contactInfoBox}>
                <div style={styles.contactInfoIcon}>📞</div>
                <div>
                  <div style={styles.contactInfoLabel}>رقم المشرف للتواصل</div>
                  <div style={styles.contactInfoValue}>{adminContact}</div>
                </div>
              </div>
            )}

            <div style={styles.contactsList}>
              {contacts.map(contact => {
                const unreadCount = getUnreadCount(contact.id);
                return (
                  <div
                    key={contact.id}
                    onClick={() => setSelectedContact(contact)}
                    style={{
                      ...styles.contactItem,
                      backgroundColor: selectedContact?.id === contact.id ? '#e0f2fe' : 'white',
                      borderColor: selectedContact?.id === contact.id ? '#0ea5e9' : '#e2e8f0'
                    }}
                  >
                    <div style={styles.contactIcon}>{getRoleIcon(contact.role)}</div>
                    <div style={styles.contactInfo}>
                      <div style={styles.contactName}>{contact.name}</div>
                      <div style={styles.contactRole}>{getRoleLabel(contact.role)}</div>
                    </div>
                    {unreadCount > 0 && (
                      <div style={styles.unreadBadge}>{unreadCount}</div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>

          {/* Chat Area */}
           <div className="dashboard-chat-area" style={styles.chatArea}>
            {selectedContact ? (
              <>
                {/* Chat Header */}
                 <div className="dashboard-chat-header" style={styles.chatHeader}>
                  <div style={styles.chatHeaderIcon}>{getRoleIcon(selectedContact.role)}</div>
                  <div>
                    <div style={styles.chatHeaderName}>{selectedContact.name}</div>
                    <div style={styles.chatHeaderRole}>{getRoleLabel(selectedContact.role)}</div>
                  </div>
                </div>

                {/* Messages */}
                 <div className="dashboard-chat-messages" style={styles.messagesContainer}>
                  {messages.length === 0 ? (
                    <div style={styles.emptyMessages}>
                      <div style={styles.emptyIcon}>💬</div>
                      <p style={styles.emptyText}>لا توجد رسائل بعد</p>
                      <p style={styles.emptySubtext}>ابدأ محادثة الآن!</p>
                    </div>
                  ) : (
                    messages.map(msg => (
                      <div
                        key={msg.id}
                        style={{
                          ...styles.messageWrapper,
                          justifyContent: msg.senderId === currentUserId ? 'flex-end' : 'flex-start'
                        }}
                      >
                        <div
                          style={{
                            ...styles.message,
                            backgroundColor: msg.senderId === currentUserId ? '#0ea5e9' : '#f1f5f9',
                            color: msg.senderId === currentUserId ? 'white' : '#334155',
                            borderRadius: msg.senderId === currentUserId ? '20px 20px 5px 20px' : '20px 20px 20px 5px'
                          }}
                        >
                          <div style={styles.messageText}>{msg.message}</div>
                          <div style={{
                            ...styles.messageTime,
                            color: msg.senderId === currentUserId ? 'rgba(255,255,255,0.8)' : '#94a3b8'
                          }}>
                            {new Date(msg.timestamp).toLocaleString('ar-SA', {
                              hour: '2-digit',
                              minute: '2-digit',
                              day: 'numeric',
                              month: 'short'
                            })}
                          </div>
                        </div>
                      </div>
                    ))
                  )}
                  <div ref={messagesEndRef} />
                </div>

                {/* Input */}
                 <form className="dashboard-chat-input" onSubmit={handleSendMessage} style={styles.inputForm}>
                  <input
                    type="text"
                    value={newMessage}
                    onChange={(e) => setNewMessage(e.target.value)}
                    placeholder="اكتب رسالتك هنا..."
                    style={styles.input}
                  />
                  <button type="submit" style={styles.sendButton}>
                    📤 إرسال
                  </button>
                </form>
              </>
            ) : (
              <div style={styles.emptyMessages}>
                <div style={styles.emptyIcon}>👈</div>
                <p style={styles.emptyText}>اختر جهة اتصال للبدء</p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

const styles: Record<string, React.CSSProperties> = {
  overlay: {
    position: 'fixed',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0,0,0,0.5)',
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 1000,
  },
  container: {
    backgroundColor: 'white',
    borderRadius: '25px',
    width: '90%',
    maxWidth: '1100px',
    height: '80vh',
    display: 'flex',
    flexDirection: 'column',
    boxShadow: '0 20px 60px rgba(0,0,0,0.3)',
  },
  header: {
    padding: '20px 30px',
    borderBottom: '2px solid #e2e8f0',
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: '#f8fafc',
    borderRadius: '25px 25px 0 0',
  },
  headerTitle: {
    fontSize: '24px',
    fontWeight: 'bold',
    color: '#1e293b',
  },
  closeButton: {
    background: '#ef4444',
    color: 'white',
    border: 'none',
    borderRadius: '50%',
    width: '40px',
    height: '40px',
    fontSize: '20px',
    cursor: 'pointer',
    fontWeight: 'bold',
  },
  content: {
    display: 'flex',
    flex: 1,
    overflow: 'hidden',
  },
  sidebar: {
    width: '320px',
    borderRight: '2px solid #e2e8f0',
    padding: '20px',
    overflowY: 'auto',
    backgroundColor: '#f8fafc',
  },
  sidebarTitle: {
    fontSize: '18px',
    fontWeight: 'bold',
    color: '#475569',
    marginBottom: '15px',
  },
  contactInfoBox: {
    backgroundColor: '#dbeafe',
    padding: '15px',
    borderRadius: '15px',
    marginBottom: '20px',
    display: 'flex',
    gap: '12px',
    alignItems: 'center',
  },
  contactInfoIcon: {
    fontSize: '28px',
  },
  contactInfoLabel: {
    fontSize: '12px',
    color: '#1e40af',
    fontWeight: 'bold',
  },
  contactInfoValue: {
    fontSize: '16px',
    color: '#1e40af',
    fontWeight: 'bold',
    direction: 'ltr',
    textAlign: 'left',
  },
  contactsList: {
    display: 'flex',
    flexDirection: 'column',
    gap: '10px',
  },
  contactItem: {
    padding: '15px',
    borderRadius: '15px',
    border: '2px solid',
    cursor: 'pointer',
    display: 'flex',
    gap: '12px',
    alignItems: 'center',
    transition: 'all 0.2s',
  },
  contactIcon: {
    fontSize: '32px',
  },
  contactInfo: {
    flex: 1,
  },
  contactName: {
    fontSize: '16px',
    fontWeight: 'bold',
    color: '#1e293b',
  },
  contactRole: {
    fontSize: '13px',
    color: '#64748b',
  },
  unreadBadge: {
    backgroundColor: '#ef4444',
    color: 'white',
    borderRadius: '50%',
    width: '24px',
    height: '24px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontSize: '12px',
    fontWeight: 'bold',
  },
  chatArea: {
    flex: 1,
    display: 'flex',
    flexDirection: 'column',
  },
  chatHeader: {
    padding: '20px',
    borderBottom: '2px solid #e2e8f0',
    display: 'flex',
    gap: '15px',
    alignItems: 'center',
    backgroundColor: 'white',
  },
  chatHeaderIcon: {
    fontSize: '40px',
  },
  chatHeaderName: {
    fontSize: '20px',
    fontWeight: 'bold',
    color: '#1e293b',
  },
  chatHeaderRole: {
    fontSize: '14px',
    color: '#64748b',
  },
  messagesContainer: {
    flex: 1,
    padding: '20px',
    overflowY: 'auto',
    backgroundColor: '#ffffff',
  },
  emptyMessages: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    height: '100%',
    color: '#94a3b8',
  },
  emptyIcon: {
    fontSize: '64px',
    marginBottom: '15px',
  },
  emptyText: {
    fontSize: '18px',
    fontWeight: 'bold',
    marginBottom: '5px',
  },
  emptySubtext: {
    fontSize: '14px',
  },
  messageWrapper: {
    display: 'flex',
    marginBottom: '15px',
  },
  message: {
    maxWidth: '70%',
    padding: '12px 18px',
    wordWrap: 'break-word',
  },
  messageText: {
    fontSize: '15px',
    lineHeight: '1.5',
    marginBottom: '5px',
  },
  messageTime: {
    fontSize: '11px',
    textAlign: 'right',
  },
  inputForm: {
    padding: '20px',
    borderTop: '2px solid #e2e8f0',
    display: 'flex',
    gap: '15px',
    backgroundColor: '#f8fafc',
  },
  input: {
    flex: 1,
    padding: '15px 20px',
    borderRadius: '25px',
    border: '2px solid #e2e8f0',
    fontSize: '15px',
    outline: 'none',
  },
  sendButton: {
    padding: '15px 30px',
    backgroundColor: '#0ea5e9',
    color: 'white',
    border: 'none',
    borderRadius: '25px',
    fontSize: '16px',
    fontWeight: 'bold',
    cursor: 'pointer',
    transition: 'all 0.2s',
  },
};

export default PrivateChat;
