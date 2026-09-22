'use strict';

const ApiError = require('../utils/ApiError');
const User = require('../models/User');
const CandidateProfile = require('../models/CandidateProfile');
const { Conversation, Message } = require('../models/chat');
const { pairKeyOf } = require('../models/social');
const { areConnected, canViewCandidate, isBlocked } = require('./peopleService');

/**
 * Who may start a conversation with whom:
 *  - accepted connections always can;
 *  - a candidate may message a recruiter (that is how they apply);
 *  - a recruiter may message a candidate the candidate lets them discover,
 *    unless the candidate switched off "Open to connect";
 *  - anyone else needs an accepted connection request first.
 */
async function assertCanMessage(sender, recipientId) {
  if (String(sender._id) === String(recipientId)) {
    throw ApiError.badRequest('You cannot message yourself.');
  }

  const recipient = await User.findById(recipientId);
  if (!recipient || !recipient.isActive) {
    throw ApiError.notFound('That person is no longer on TalentRadar.');
  }
  // Checked before everything else, so a block cannot be talked around.
  if (await isBlocked(sender._id, recipient._id)) {
    throw ApiError.forbidden('You cannot start a conversation with this person.');
  }
  if (await areConnected(sender._id, recipient._id)) return recipient;

  if (sender.role === 'candidate' && recipient.role === 'recruiter') return recipient;

  if (sender.role === 'recruiter' && recipient.role === 'candidate') {
    const profile = await CandidateProfile.findOne({ userId: recipient._id });
    if (profile && profile.openToConnect && (await canViewCandidate(sender, profile))) {
      return recipient;
    }
    throw ApiError.forbidden(
      'This candidate is not accepting messages right now. Send a connection request instead.'
    );
  }

  throw ApiError.forbidden('Connect with this person first to start a conversation.');
}

/** Returns the existing conversation for the pair, or creates it. */
async function openConversation(sender, recipientId, { jobId = null } = {}) {
  await assertCanMessage(sender, recipientId);
  const pairKey = pairKeyOf(sender._id, recipientId);

  let conversation = await Conversation.findOne({ pairKey });
  if (!conversation) {
    try {
      conversation = await Conversation.create({
        participantIds: [sender._id, recipientId],
        pairKey,
        jobId,
      });
    } catch (err) {
      // Two taps at once: the other request created it first.
      if (err.code !== 11000) throw err;
      conversation = await Conversation.findOne({ pairKey });
    }
  }
  return conversation;
}

/** Opens a conversation without the messaging rules (used after a connection is accepted). */
async function ensureConversation(userA, userB) {
  const pairKey = pairKeyOf(userA, userB);
  const existing = await Conversation.findOne({ pairKey });
  if (existing) return existing;
  try {
    return await Conversation.create({ participantIds: [userA, userB], pairKey });
  } catch (err) {
    if (err.code !== 11000) throw err;
    return Conversation.findOne({ pairKey });
  }
}

function assertParticipant(conversation, userId) {
  if (!conversation.participantIds.some((id) => String(id) === String(userId))) {
    throw ApiError.notFound('We could not find that conversation.');
  }
}

async function postMessage(conversation, senderId, { kind = 'text', text = '', invite } = {}) {
  const message = await Message.create({
    conversationId: conversation._id,
    senderId,
    kind,
    text,
    invite,
  });

  const preview =
    kind === 'interview_invite' ? `Interview invite · ${invite.title}` : text.slice(0, 140);

  conversation.lastMessage = { text: preview, senderId, at: message.createdAt };
  conversation.participantIds.forEach((id) => {
    if (String(id) !== String(senderId)) {
      conversation.unread.set(String(id), (conversation.unread.get(String(id)) || 0) + 1);
    }
  });
  conversation.markModified('unread');
  await conversation.save();

  return message;
}

async function markRead(conversation, userId) {
  if ((conversation.unread.get(String(userId)) || 0) === 0) return;
  conversation.unread.set(String(userId), 0);
  conversation.markModified('unread');
  await conversation.save();
}

module.exports = {
  assertCanMessage,
  openConversation,
  ensureConversation,
  assertParticipant,
  postMessage,
  markRead,
};
