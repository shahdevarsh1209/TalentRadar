'use strict';

const Job = require('../models/Job');
const User = require('../models/User');
const CandidateProfile = require('../models/CandidateProfile');
const { SavedItem, Connection, pairKeyOf } = require('../models/social');
const { Conversation, Message } = require('../models/chat');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../middleware/asyncHandler');
const { distanceKm, displayDistance } = require('../utils/geo');
const { summarize, canViewCandidate } = require('../services/peopleService');
const {
  openConversation,
  ensureConversation,
  assertParticipant,
  postMessage,
  markRead,
} = require('../services/chatService');
const { viewerContext } = require('./jobsController');

// ── Saved ────────────────────────────────────────────────────────────────────

const listSaved = asyncHandler(async (req, res) => {
  const items = await SavedItem.find({ userId: req.user._id }).sort({ createdAt: -1 });
  const jobIds = items.filter((item) => item.kind === 'job').map((item) => item.refId);
  const personIds = items.filter((item) => item.kind === 'person').map((item) => item.refId);

  const [jobs, people, context] = await Promise.all([
    Job.find({ _id: { $in: jobIds } }),
    summarize(personIds),
    viewerContext(req.user),
  ]);
  const jobById = new Map(jobs.map((job) => [String(job._id), job]));

  const savedJobs = jobIds
    .map((id) => jobById.get(String(id)))
    .filter(Boolean)
    .map((job) => {
      const km = context.point ? distanceKm(context.point, job.location?.approximate) : null;
      return job.toPublic({
        distanceKm: km === null ? null : displayDistance(km, { precise: true }),
        saved: true,
      });
    });

  // A saved candidate who has since gone private drops off the list.
  const visiblePeople = [];
  for (const id of personIds) {
    const summary = people.get(String(id));
    if (!summary) continue;
    if (summary.role === 'candidate') {
      const profile = await CandidateProfile.findOne({ userId: id });
      if (!profile || !(await canViewCandidate(req.user, profile))) continue;
    }
    visiblePeople.push(summary);
  }

  res.json({ success: true, data: { jobs: savedJobs, people: visiblePeople } });
});

const saveItem = asyncHandler(async (req, res) => {
  const { kind, refId } = req.body;
  if (kind === 'job') {
    if (!(await Job.exists({ _id: refId }))) throw ApiError.notFound('This role is no longer listed.');
  } else if (String(refId) === String(req.user._id)) {
    throw ApiError.badRequest('You cannot save your own profile.');
  } else if (!(await User.exists({ _id: refId }))) {
    throw ApiError.notFound('That person is no longer on TalentRadar.');
  }

  await SavedItem.updateOne(
    { userId: req.user._id, kind, refId },
    { $setOnInsert: { userId: req.user._id, kind, refId } },
    { upsert: true }
  );
  res.json({ success: true, data: { saved: true } });
});

const unsaveItem = asyncHandler(async (req, res) => {
  await SavedItem.deleteOne({ userId: req.user._id, kind: req.params.kind, refId: req.params.refId });
  res.json({ success: true, data: { saved: false } });
});

// ── Connections ──────────────────────────────────────────────────────────────

const requestConnection = asyncHandler(async (req, res) => {
  const { recipientId, message } = req.body;
  if (String(recipientId) === String(req.user._id)) {
    throw ApiError.badRequest('You cannot connect with yourself.');
  }
  const recipient = await User.findById(recipientId).catch(() => null);
  if (!recipient || !recipient.isActive) {
    throw ApiError.notFound('That person is no longer on TalentRadar.');
  }
  if (recipient.role === 'candidate') {
    const profile = await CandidateProfile.findOne({ userId: recipient._id });
    if (!profile || !(await canViewCandidate(req.user, profile))) {
      throw ApiError.notFound('This profile is private or no longer available.');
    }
    if (!profile.openToConnect) {
      throw ApiError.forbidden('This person is not accepting connection requests right now.');
    }
  }

  const pairKey = pairKeyOf(req.user._id, recipient._id);
  let connection = await Connection.findOne({ pairKey });

  if (connection?.status === 'accepted') {
    return res.json({ success: true, data: { status: 'connected' } });
  }

  // They already asked us: sending a request back simply accepts theirs.
  if (connection?.status === 'pending' && String(connection.recipientId) === String(req.user._id)) {
    connection.status = 'accepted';
    connection.respondedAt = new Date();
    await connection.save();
    const conversation = await ensureConversation(req.user._id, recipient._id);
    return res.json({
      success: true,
      data: { status: 'connected', conversationId: conversation._id.toString() },
    });
  }

  if (connection) {
    connection.requesterId = req.user._id;
    connection.recipientId = recipient._id;
    connection.message = message || '';
    connection.status = 'pending';
    connection.respondedAt = null;
    await connection.save();
  } else {
    connection = await Connection.create({
      requesterId: req.user._id,
      recipientId: recipient._id,
      pairKey,
      message: message || '',
    });
  }

  res.status(201).json({ success: true, data: { status: 'pending_sent', connectionId: connection._id.toString() } });
});

const listConnections = asyncHandler(async (req, res) => {
  const me = req.user._id;
  const [incoming, outgoing, accepted] = await Promise.all([
    Connection.find({ recipientId: me, status: 'pending' }).sort({ createdAt: -1 }),
    Connection.find({ requesterId: me, status: 'pending' }).sort({ createdAt: -1 }),
    Connection.find({ $or: [{ requesterId: me }, { recipientId: me }], status: 'accepted' })
      .sort({ respondedAt: -1 })
      .limit(30),
  ]);

  const otherOf = (connection) =>
    String(connection.requesterId) === String(me) ? connection.recipientId : connection.requesterId;
  const people = await summarize([...incoming, ...outgoing, ...accepted].map(otherOf));

  const shape = (connection, status) => ({
    connectionId: connection._id.toString(),
    person: people.get(String(otherOf(connection))),
    message: connection.message,
    status,
    at: connection.respondedAt || connection.createdAt,
  });

  res.json({
    success: true,
    data: {
      incoming: incoming.map((item) => shape(item, 'pending_received')),
      outgoing: outgoing.map((item) => shape(item, 'pending_sent')),
      connections: accepted.map((item) => shape(item, 'connected')),
    },
  });
});

const respondToConnection = asyncHandler(async (req, res) => {
  const connection = await Connection.findOne({
    _id: req.params.connectionId,
    recipientId: req.user._id,
    status: 'pending',
  }).catch(() => null);
  if (!connection) throw ApiError.notFound('That request is no longer pending.');

  connection.status = req.body.action === 'accept' ? 'accepted' : 'ignored';
  connection.respondedAt = new Date();
  await connection.save();

  let conversationId = null;
  if (connection.status === 'accepted') {
    const conversation = await ensureConversation(connection.requesterId, connection.recipientId);
    conversationId = conversation._id.toString();
    // Their note becomes the first message, so the chat opens with context.
    if (connection.message && !conversation.lastMessage?.at) {
      await postMessage(conversation, connection.requesterId, { text: connection.message });
    }
  }

  res.json({ success: true, data: { status: connection.status, conversationId } });
});

// ── Conversations ────────────────────────────────────────────────────────────

function otherParticipant(conversation, userId) {
  return conversation.participantIds.find((id) => String(id) !== String(userId));
}

function conversationSummary(conversation, userId, people) {
  const other = otherParticipant(conversation, userId);
  return {
    conversationId: conversation._id.toString(),
    person: people.get(String(other)),
    jobId: conversation.jobId ? conversation.jobId.toString() : null,
    lastMessage: conversation.lastMessage?.at
      ? {
          text: conversation.lastMessage.text,
          fromMe: String(conversation.lastMessage.senderId) === String(userId),
          at: conversation.lastMessage.at,
        }
      : null,
    unreadCount: conversation.unread?.get(String(userId)) || 0,
    updatedAt: conversation.updatedAt,
  };
}

const listConversations = asyncHandler(async (req, res) => {
  const conversations = await Conversation.find({ participantIds: req.user._id })
    .sort({ updatedAt: -1 })
    .limit(100);
  const people = await summarize(conversations.map((item) => otherParticipant(item, req.user._id)));
  res.json({
    success: true,
    data: {
      conversations: conversations.map((item) => conversationSummary(item, req.user._id, people)),
    },
  });
});

const startConversation = asyncHandler(async (req, res) => {
  const conversation = await openConversation(req.user, req.body.participantId, {
    jobId: req.body.jobId || null,
  });
  const people = await summarize([req.body.participantId]);
  res.json({ success: true, data: { conversation: conversationSummary(conversation, req.user._id, people) } });
});

async function loadConversation(req) {
  const conversation = await Conversation.findById(req.params.conversationId).catch(() => null);
  if (!conversation) throw ApiError.notFound('We could not find that conversation.');
  assertParticipant(conversation, req.user._id);
  return conversation;
}

/** Messages, oldest first. `after` lets the chat screen poll for new ones cheaply. */
const listMessages = asyncHandler(async (req, res) => {
  const conversation = await loadConversation(req);
  const filter = { conversationId: conversation._id };
  if (req.query.after) filter.createdAt = { $gt: new Date(req.query.after) };

  const messages = await Message.find(filter).sort({ createdAt: 1 }).limit(300);
  await markRead(conversation, req.user._id);
  const people = await summarize([otherParticipant(conversation, req.user._id)]);

  res.json({
    success: true,
    data: {
      conversation: conversationSummary(conversation, req.user._id, people),
      messages: messages.map((message) => message.toPublic()),
    },
  });
});

const sendMessage = asyncHandler(async (req, res) => {
  const conversation = await loadConversation(req);
  const message = await postMessage(conversation, req.user._id, { text: req.body.text });
  res.status(201).json({ success: true, data: { message: message.toPublic() } });
});

/** Recruiters only: the interview-invite card from the design. */
const sendInvite = asyncHandler(async (req, res) => {
  const conversation = await loadConversation(req);
  const message = await postMessage(conversation, req.user._id, {
    kind: 'interview_invite',
    invite: { ...req.body, scheduledAt: new Date(req.body.scheduledAt), status: 'pending' },
  });
  res.status(201).json({ success: true, data: { message: message.toPublic() } });
});

const INVITE_OUTCOME = {
  accept: { status: 'accepted', note: 'accepted the interview invite' },
  reschedule: { status: 'reschedule_requested', note: 'asked to reschedule the interview' },
  decline: { status: 'declined', note: 'declined the interview invite' },
};

const respondToInvite = asyncHandler(async (req, res) => {
  const message = await Message.findById(req.params.messageId).catch(() => null);
  if (!message || message.kind !== 'interview_invite') {
    throw ApiError.notFound('We could not find that invite.');
  }
  const conversation = await Conversation.findById(message.conversationId);
  assertParticipant(conversation, req.user._id);
  if (String(message.senderId) === String(req.user._id)) {
    throw ApiError.badRequest('The person you invited needs to respond to this.');
  }
  if (message.invite.status !== 'pending' && message.invite.status !== 'reschedule_requested') {
    throw ApiError.badRequest('You have already responded to this invite.');
  }

  const outcome = INVITE_OUTCOME[req.body.action];
  message.invite.status = outcome.status;
  message.invite.respondedAt = new Date();
  message.markModified('invite');
  await message.save();

  const people = await summarize([req.user._id]);
  const name = people.get(String(req.user._id))?.name?.split(' ')[0] || 'They';
  await postMessage(conversation, req.user._id, {
    kind: 'system',
    text: `${name} ${outcome.note}.`,
  });

  res.json({ success: true, data: { message: message.toPublic() } });
});

/** Nav badges: unread chats and pending requests, one cheap call. */
const badges = asyncHandler(async (req, res) => {
  const [conversations, pendingRequests] = await Promise.all([
    Conversation.find({ participantIds: req.user._id }).select('unread'),
    Connection.countDocuments({ recipientId: req.user._id, status: 'pending' }),
  ]);
  const unreadChats = conversations.reduce(
    (sum, item) => sum + (item.unread?.get(String(req.user._id)) || 0),
    0
  );
  res.json({ success: true, data: { unreadChats, pendingRequests } });
});

module.exports = {
  listSaved,
  saveItem,
  unsaveItem,
  requestConnection,
  listConnections,
  respondToConnection,
  listConversations,
  startConversation,
  listMessages,
  sendMessage,
  sendInvite,
  respondToInvite,
  badges,
};
