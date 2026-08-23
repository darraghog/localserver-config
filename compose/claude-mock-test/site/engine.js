const ENGINE = (function () {
  function grade(question, selected) {
    const correctIds = question.correct.slice().sort();
    const given = (selected || []).slice().sort();
    const isCorrect =
      correctIds.length === given.length && correctIds.every((id, i) => id === given[i]);
    return { correct: isCorrect, correctIds, selected: given };
  }

  // mulberry32 — small, fast, seedable. Used so tests are deterministic.
  function makeRng(seed) {
    let a = seed >>> 0;
    return function () {
      a = (a + 0x6d2b79f5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function shuffle(array, rng) {
    const out = array.slice();
    for (let i = out.length - 1; i > 0; i--) {
      const j = Math.floor(rng() * (i + 1));
      [out[i], out[j]] = [out[j], out[i]];
    }
    return out;
  }

  function withShuffledOptions(question, rng) {
    return Object.assign({}, question, { options: shuffle(question.options, rng) });
  }

  function sampleExam(domains, n, rng) {
    const pool = domains.filter((d) => d.questions.length > 0);
    const total = pool.reduce((sum, d) => sum + d.questions.length, 0);
    if (n >= total) return shuffle(pool.flatMap((d) => d.questions), rng);

    // Proportional allocation, largest remainder for the leftovers.
    const alloc = pool.map((d) => {
      const exact = (d.questions.length * n) / total;
      const base = Math.floor(exact);
      return { domain: d, take: base, remainder: exact - base };
    });
    let assigned = alloc.reduce((sum, a) => sum + a.take, 0);
    const byRemainder = alloc.slice().sort((x, y) => y.remainder - x.remainder);
    for (let i = 0; assigned < n; i++, assigned++) {
      const slot = byRemainder[i % byRemainder.length];
      // Guard: never take more than the domain actually holds.
      if (slot.take < slot.domain.questions.length) slot.take++;
      else assigned--;
    }

    const picked = alloc.flatMap((a) => shuffle(a.domain.questions, rng).slice(0, a.take));
    return shuffle(picked, rng);
  }

  function scoreExam(questions, answers) {
    const byDomain = {};
    let score = 0;
    for (const q of questions) {
      if (!byDomain[q.domain]) byDomain[q.domain] = { correct: 0, total: 0 };
      byDomain[q.domain].total++;
      if (grade(q, answers[q.id]).correct) {
        byDomain[q.domain].correct++;
        score++;
      }
    }
    return { score, total: questions.length, byDomain };
  }

  const HISTORY_KEY = 'cpa-mock-test-v1';

  function emptyHistory() {
    return { version: 1, questions: {}, lastExam: null };
  }

  function loadHistory(storage) {
    try {
      const raw = storage.getItem(HISTORY_KEY);
      if (!raw) return emptyHistory();
      const parsed = JSON.parse(raw);
      if (!parsed || parsed.version !== 1) return emptyHistory();
      if (typeof parsed.questions !== 'object' || parsed.questions === null) return emptyHistory();
      return {
        version: 1,
        questions: parsed.questions,
        lastExam: parsed.lastExam || null,
      };
    } catch (err) {
      return emptyHistory();
    }
  }

  function saveHistory(storage, history) {
    try {
      storage.setItem(HISTORY_KEY, JSON.stringify(history));
      return true;
    } catch (err) {
      return false;
    }
  }

  function recordAnswer(history, questionId, wasCorrect) {
    const entry = history.questions[questionId] || { seen: 0, correct: 0 };
    entry.seen++;
    if (wasCorrect) entry.correct++;
    history.questions[questionId] = entry;
    return history;
  }

  function recordExam(history, result) {
    history.lastExam = {
      score: result.score,
      total: result.total,
      byDomain: result.byDomain,
    };
    return history;
  }

  return { grade, makeRng, shuffle, withShuffledOptions, sampleExam, scoreExam, HISTORY_KEY, emptyHistory, loadHistory, saveHistory, recordAnswer, recordExam };
})();

if (typeof module !== 'undefined') module.exports = ENGINE;
if (typeof window !== 'undefined') window.ENGINE = ENGINE;
