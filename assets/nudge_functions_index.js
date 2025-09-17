// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.scheduleRecurringNudges = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    // Get all users
    const usersSnapshot = await admin.firestore().collection('users').get();
    
    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      
      // Get all contacts for this user
      const contactsSnapshot = await admin.firestore()
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .get();
      
      for (const contactDoc of contactsSnapshot.docs) {
        const contact = contactDoc.data();
        
        // Check if it's time for a nudge
        const lastNudged = contact.lastNudged ? new Date(contact.lastNudged) : new Date(0);
        const nextNudge = calculateNextNudge(contact.period, contact.frequency, lastNudged);
        
        if (nextNudge <= new Date()) {
          // Create nudge
          const nudge = {
            id: admin.firestore().collection('nudges').doc().id,
            contactId: contactDoc.id,
            contactName: contact.name,
            scheduledTime: admin.firestore.Timestamp.now(),
            userId: userId,
            period: contact.period,
            frequency: contact.frequency,
            isPushNotification: contact.isVIP || contact.priority <= 2,
            priority: contact.priority,
            isVIP: contact.isVIP,
            isCompleted: false,
            createdAt: admin.firestore.Timestamp.now(),
          };
          
          // Save nudge
          await admin.firestore()
            .collection('users')
            .doc(userId)
            .collection('nudges')
            .doc(nudge.id)
            .set(nudge);
          
          // Send push notification if needed
          if (nudge.isPushNotification) {
            await sendPushNotification(userId, nudge);
          }
          
          // Update contact's lastNudged field
          await contactDoc.ref.update({
            lastNudged: admin.firestore.Timestamp.now(),
          });
        }
      }
    }
  });

function calculateNextNudge(period, frequency, lastNudged) {
  const nextDate = new Date(lastNudged);
  
  switch (period) {
    case 'days':
      nextDate.setDate(nextDate.getDate() + frequency);
      break;
    case 'weeks':
      nextDate.setDate(nextDate.getDate() + (frequency * 7));
      break;
    case 'months':
      nextDate.setMonth(nextDate.getMonth() + frequency);
      break;
    case 'years':
      nextDate.setFullYear(nextDate.getFullYear() + frequency);
      break;
  }
  
  return nextDate;
}

async function sendPushNotification(userId, nudge) {
  // Get user's FCM token
  const userDoc = await admin.firestore().collection('users').doc(userId).get();
  const fcmToken = userDoc.data().fcmToken;
  
  if (!fcmToken) return;
  
  const message = {
    notification: {
      title: 'Time to connect with ${nudge.contactName}',
      body: 'Remember to reach out to ${nudge.contactName}',
    },
    token: fcmToken,
  };
  
  await admin.messaging().send(message);
}