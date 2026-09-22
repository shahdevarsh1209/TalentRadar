'use strict';

const mongoose = require('mongoose');

const { ObjectId } = mongoose.Schema.Types;

/**
 * One conversation per pair of people. Unread counts are kept per participant
 * so the Chats tab badge is a single indexed read, not a count over messages.
 */
const conversationSchema = new mongoose.Schema(
  {
    participantIds: {
      type: [{ type: ObjectId, ref: 'User' }],
      validate: [(value) => value.length === 2, 'A conversation has two participants'],
      index: true,
    },
    pairKey: { type: String, required: true, unique: true },
    // The job that started it, when there was one ("I'm interested").
    jobId: { type: ObjectId, ref: 'Job', default: null },
    lastMessage: {
      text: { type: String, default: '' },
      senderId: { type: ObjectId, default: null },
      at: { type: Date, default: null },
    },
    unread: { type: Map, of: Number, default: {} },
  },
  { timestamps: true, collection: 'conversations' }
);
conversationSchema.index({ participantIds: 1, updatedAt: -1 });

const interviewInviteSchema = new mongoose.Schema(
  {
    title: { type: String, required: true, trim: true, maxlength: 120 },
    round: { type: String, trim: true, default: 'Round 1', maxlength: 60 },
    scheduledAt: { type: Date, required: true },
    mode: { type: String, enum: ['in_person', 'video', 'phone'], default: 'in_person' },
    location: { type: String, trim: true, default: '', maxlength: 200 },
    status: {
      type: String,
      enum: ['pending', 'accepted', 'reschedule_requested', 'declined'],
      default: 'pending',
    },
    respondedAt: { type: Date, default: null },
  },
  { _id: false }
);

const messageSchema = new mongoose.Schema(
  {
    conversationId: { type: ObjectId, ref: 'Conversation', required: true, index: true },
    senderId: { type: ObjectId, ref: 'User', required: true },
    kind: { type: String, enum: ['text', 'interview_invite', 'system'], default: 'text' },
    text: { type: String, trim: true, default: '', maxlength: 2000 },
    invite: { type: interviewInviteSchema, default: undefined },
  },
  { timestamps: true, collection: 'messages' }
);
messageSchema.index({ conversationId: 1, createdAt: 1 });

messageSchema.methods.toPublic = function toPublic() {
  return {
    messageId: this._id.toString(),
    conversationId: this.conversationId.toString(),
    senderId: this.senderId.toString(),
    kind: this.kind,
    text: this.text,
    invite: this.invite
      ? {
          title: this.invite.title,
          round: this.invite.round,
          scheduledAt: this.invite.scheduledAt,
          mode: this.invite.mode,
          location: this.invite.location,
          status: this.invite.status,
          respondedAt: this.invite.respondedAt,
        }
      : null,
    createdAt: this.createdAt,
  };
};

module.exports = {
  Conversation: mongoose.model('Conversation', conversationSchema),
  Message: mongoose.model('Message', messageSchema),
};
