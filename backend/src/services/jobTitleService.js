'use strict';

const JobTitle = require('../models/JobTitle');
const ApiError = require('../utils/ApiError');

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Ranks a matched title against the query the way a person would expect:
 * a title that starts with what you typed beats one that merely contains it,
 * and a name hit always beats an alias hit. Popularity only breaks ties.
 */
function score(title, query) {
  const name = title.name.toLowerCase();
  const q = query.toLowerCase();
  let base = 0;

  if (name === q) base = 1000;
  else if (name.startsWith(q)) base = 800;
  else if (name.includes(` ${q}`)) base = 600;
  else if (name.includes(q)) base = 400;
  else {
    const alias = (title.aliases || []).find((item) => item.toLowerCase().includes(q));
    if (alias) base = alias.toLowerCase().startsWith(q) ? 300 : 200;
    else if ((title.category || '').toLowerCase().includes(q)) base = 100;
  }

  return base + (title.popularity || 0) / 100;
}

/**
 * @param {string} query   free text the user typed; empty returns popular titles
 * @param {number} limit   max suggestions
 * @param {string} category optional category filter
 */
async function searchJobTitles({ query = '', limit = 20, category } = {}) {
  const trimmed = String(query || '').trim();
  const safeLimit = Math.min(Math.max(Number(limit) || 20, 1), 50);
  const filter = { isActive: true };
  if (category) filter.category = category;

  // No query yet: the selector opens on the most common titles rather than blank.
  if (trimmed.length === 0) {
    const popular = await JobTitle.find(filter).sort({ popularity: -1, name: 1 }).limit(safeLimit);
    return popular.map((title) => title.toPublic());
  }

  const pattern = new RegExp(escapeRegex(trimmed), 'i');
  const matches = await JobTitle.find({
    ...filter,
    $or: [{ name: pattern }, { aliases: pattern }, { category: pattern }],
  }).limit(200);

  return matches
    .map((title) => ({ title, rank: score(title, trimmed) }))
    .sort((a, b) => b.rank - a.rank || a.title.name.localeCompare(b.title.name))
    .slice(0, safeLimit)
    .map((entry) => entry.title.toPublic());
}

/**
 * Turns the codes a client submitted into trusted title references. Unknown
 * codes are rejected so profiles can never hold a title the master does not own.
 */
async function resolveTitleCodes(codes, { fieldLabel = 'job title' } = {}) {
  const unique = [...new Set((codes || []).map((code) => String(code).trim()).filter(Boolean))];
  if (unique.length === 0) {
    throw ApiError.validation(`Please select at least one ${fieldLabel}.`, [
      { field: 'jobTitles', message: `Please select at least one ${fieldLabel}.` },
    ]);
  }

  const found = await JobTitle.find({ code: { $in: unique }, isActive: true });
  if (found.length !== unique.length) {
    const foundCodes = new Set(found.map((title) => title.code));
    const missing = unique.filter((code) => !foundCodes.has(code));
    throw ApiError.validation(
      `We could not recognise one of the selected ${fieldLabel}s. Please pick it again.`,
      missing.map((code) => ({ field: 'jobTitles', message: `Unknown title ${code}` }))
    );
  }

  // Preserve the order the user chose.
  const byCode = new Map(found.map((title) => [title.code, title]));
  return unique.map((code) => {
    const title = byCode.get(code);
    return { code: title.code, name: title.name, category: title.category };
  });
}

async function listCategories() {
  const categories = await JobTitle.distinct('category', { isActive: true });
  return categories.sort();
}

module.exports = { searchJobTitles, resolveTitleCodes, listCategories };
