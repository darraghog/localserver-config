(function () {
  const $ = (sel) => document.querySelector(sel);
  const screens = ['home', 'practice', 'exam', 'results'];

  function show(id) {
    for (const s of screens) $('#' + s).hidden = s !== id;
    window.scrollTo(0, 0);
  }

  function storage() {
    try {
      return window.localStorage;
    } catch (err) {
      return { getItem: () => null, setItem: () => {} };
    }
  }

  let history = ENGINE.loadHistory(storage());

  function persist() {
    ENGINE.saveHistory(storage(), history);
  }

  function renderHome() {
    $('#bank-size').textContent = String(BANK.all().length);

    const picker = $('#domain-picker');
    picker.innerHTML = '<legend>Domains</legend>';
    for (const d of BANK.domains()) {
      const label = document.createElement('label');
      label.className = 'domain-option';
      label.innerHTML =
        `<input type="checkbox" value="${d.id}" checked /> ${d.title} ` +
        `<span class="muted">(${d.questions.length})</span>`;
      picker.appendChild(label);
    }

    const last = history.lastExam;
    $('#last-exam').textContent = last
      ? `Last exam: ${last.score}/${last.total}.`
      : 'No exam taken yet.';
  }

  function selectedDomains() {
    return Array.from(document.querySelectorAll('#domain-picker input:checked')).map((i) => i.value);
  }

  function seed() {
    // Date.now() is fine here — the app is not a resumable workflow.
    return Date.now() >>> 0;
  }

  $('#select-all').addEventListener('click', () => {
    document.querySelectorAll('#domain-picker input').forEach((i) => (i.checked = true));
  });
  $('#select-none').addEventListener('click', () => {
    document.querySelectorAll('#domain-picker input').forEach((i) => (i.checked = false));
  });

  function optionInput(q, index, checkedIds) {
    const type = q.type === 'multi' ? 'checkbox' : 'radio';
    const opt = q.options[index];
    const checked = checkedIds.includes(opt.id) ? ' checked' : '';
    return (
      `<label class="option" data-option="${opt.id}">` +
      `<input type="${type}" name="q-${q.id}" value="${opt.id}"${checked} />` +
      `${escapeHtml(opt.text)}</label>`
    );
  }

  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, (c) => (
      { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
    ));
  }

  function renderQuestion(q, checkedIds) {
    const opts = q.options.map((_, i) => optionInput(q, i, checkedIds)).join('');
    return `<p class="stem">${escapeHtml(q.stem)}</p>${opts}`;
  }

  function readSelection(root) {
    return Array.from(root.querySelectorAll('.option input:checked')).map((i) => i.value);
  }

  let practice = null;

  function startPractice() {
    const chosen = UI.selectedDomains();
    const pool = BANK.domains()
      .filter((d) => chosen.includes(d.id))
      .flatMap((d) => d.questions);
    if (pool.length === 0) {
      window.alert('Select at least one domain first.');
      return;
    }
    const rng = ENGINE.makeRng(UI.seed());
    const queue = ENGINE.shuffle(pool, rng).map((q) => ENGINE.withShuffledOptions(q, rng));
    practice = { queue, index: 0 };
    show('practice');
    renderPractice();
  }

  function renderPractice() {
    const q = practice.queue[practice.index];
    $('#practice').innerHTML =
      `<div class="card">` +
      `<p class="progress">Question ${practice.index + 1} of ${practice.queue.length}` +
      ` &middot; ${escapeHtml(BANK.byDomain(q.domain).title)}</p>` +
      renderQuestion(q, []) +
      `<div class="row">` +
      `<button type="button" id="practice-submit" class="primary">Check answer</button>` +
      `<button type="button" id="practice-quit">Back to menu</button>` +
      `</div><div id="practice-feedback"></div></div>`;

    $('#practice-submit').addEventListener('click', submitPractice);
    $('#practice-quit').addEventListener('click', () => {
      UI.renderHome();
      show('home');
    });
  }

  function submitPractice() {
    const q = practice.queue[practice.index];
    const selected = readSelection($('#practice'));
    if (selected.length === 0) {
      window.alert('Choose an answer first.');
      return;
    }
    const result = ENGINE.grade(q, selected);
    ENGINE.recordAnswer(UI.getHistory(), q.id, result.correct);
    UI.persist();

    document.querySelectorAll('#practice .option').forEach((el) => {
      const id = el.dataset.option;
      if (result.correctIds.includes(id)) el.classList.add('is-correct');
      else if (selected.includes(id)) el.classList.add('is-wrong');
      el.querySelector('input').disabled = true;
    });

    const verdict = result.correct
      ? '<span class="verdict-correct">Correct.</span>'
      : '<span class="verdict-wrong">Not quite.</span>';
    const flag = q.verify
      ? '<p class="flag">This question covers version-sensitive material. Re-check it against ' +
        'current Claude documentation before relying on it.</p>'
      : '';
    const isLast = practice.index === practice.queue.length - 1;

    $('#practice-feedback').innerHTML =
      `<div class="feedback">${verdict}` +
      `<p>${escapeHtml(q.explanation)}</p>` +
      `<p class="muted">Notes, page ${q.page}.</p>${flag}` +
      `<button type="button" id="practice-next" class="primary">` +
      `${isLast ? 'Finish' : 'Next question'}</button></div>`;

    $('#practice-submit').disabled = true;
    $('#practice-next').addEventListener('click', () => {
      if (isLast) {
        UI.renderHome();
        show('home');
      } else {
        practice.index++;
        renderPractice();
      }
    });
  }

  $('#start-practice').addEventListener('click', startPractice);

  let exam = null;

  function startExam() {
    const n = Number($('#exam-length').value);
    const rng = ENGINE.makeRng(UI.seed());
    const questions = ENGINE.sampleExam(BANK.domains(), n, rng).map((q) =>
      ENGINE.withShuffledOptions(q, rng)
    );
    exam = {
      questions,
      answers: {},
      index: 0,
    };
    show('exam');
    renderExam();
  }

  function renderExam() {
    const q = exam.questions[exam.index];
    const answered = Object.keys(exam.answers).length;
    const isLast = exam.index === exam.questions.length - 1;

    $('#exam').innerHTML =
      `<div class="card">` +
      `<p class="progress">Question ${exam.index + 1} of ${exam.questions.length}` +
      ` &middot; ${answered} answered</p>` +
      renderQuestion(q, exam.answers[q.id] || []) +
      `<div class="row">` +
      `<button type="button" id="exam-prev"${exam.index === 0 ? ' disabled' : ''}>Previous</button>` +
      `<button type="button" id="exam-next"${isLast ? ' disabled' : ''}>Next</button>` +
      `<button type="button" id="exam-submit" class="primary">Submit paper</button>` +
      `</div></div>`;

    $('#exam-prev').addEventListener('click', () => {
      exam.index--;
      renderExam();
    });
    $('#exam-next').addEventListener('click', () => {
      exam.index++;
      renderExam();
    });
    $('#exam-submit').addEventListener('click', submitExam);
  }

  function submitExam() {
    const unanswered = exam.questions.filter((q) => !(exam.answers[q.id] || []).length).length;
    if (unanswered > 0) {
      const ok = window.confirm(
        `${unanswered} question(s) are unanswered and will be marked wrong. Submit anyway?`
      );
      if (!ok) return;
    }

    const result = ENGINE.scoreExam(exam.questions, exam.answers);
    const previous = UI.getHistory().lastExam;
    for (const q of exam.questions) {
      ENGINE.recordAnswer(UI.getHistory(), q.id, ENGINE.grade(q, exam.answers[q.id]).correct);
    }
    ENGINE.recordExam(UI.getHistory(), result);
    UI.persist();

    renderResults(result, previous);
    show('results');
  }

  function renderResults(result, previous) {
    const pct = result.total ? Math.round((result.score / result.total) * 100) : 0;
    let movement = '';
    if (previous && previous.total) {
      const before = Math.round((previous.score / previous.total) * 100);
      const delta = pct - before;
      const word = delta > 0 ? 'up' : delta < 0 ? 'down' : 'level with';
      movement =
        `<p class="muted">${word} ${delta === 0 ? '' : Math.abs(delta) + ' points from '}` +
        `your previous ${previous.score}/${previous.total} (${before}%).</p>`;
    }

    const rows = Object.entries(result.byDomain)
      .sort((a, b) => a[0].localeCompare(b[0]))
      .map(([id, d]) => {
        const share = d.total ? Math.round((d.correct / d.total) * 100) : 0;
        const title = BANK.byDomain(id) ? BANK.byDomain(id).title : id;
        return (
          `<div class="label">${escapeHtml(title)}</div>` +
          `<div>${d.correct}/${d.total}</div>` +
          `<div class="bar"><span style="width:${share}%"></span></div>` +
          `<div>${share}%</div>`
        );
      })
      .join('');

    const review = exam.questions
      .map((q, i) => {
        const given = exam.answers[q.id] || [];
        const r = ENGINE.grade(q, given);
        const label = (ids) =>
          ids.length
            ? ids.map((id) => escapeHtml(q.options.find((o) => o.id === id).text)).join('; ')
            : 'no answer';
        return (
          `<div class="card"><p class="progress">${i + 1} &middot; ` +
          `${escapeHtml(BANK.byDomain(q.domain).title)}</p>` +
          `<p class="stem">${escapeHtml(q.stem)}</p>` +
          `<p class="${r.correct ? 'verdict-correct' : 'verdict-wrong'}">` +
          `${r.correct ? 'Correct' : 'Incorrect'}</p>` +
          `<p><strong>You chose:</strong> ${label(given)}</p>` +
          `<p><strong>Correct:</strong> ${label(r.correctIds)}</p>` +
          `<p>${escapeHtml(q.explanation)}</p>` +
          `<p class="muted">Notes, page ${q.page}.</p>` +
          (q.verify ? '<p class="flag">Version-sensitive — re-check against current docs.</p>' : '') +
          `</div>`
        );
      })
      .join('');

    $('#results').innerHTML =
      `<div class="card"><h2>${result.score} / ${result.total} &middot; ${pct}%</h2>` +
      movement +
      `<div class="breakdown" style="grid-template-columns:1fr auto 6rem auto">${rows}</div>` +
      `<div class="row"><button type="button" id="results-home" class="primary">` +
      `Back to menu</button></div></div>` +
      `<h2>Review</h2>${review}`;

    $('#results-home').addEventListener('click', () => {
      UI.renderHome();
      show('home');
    });
  }

  $('#start-exam').addEventListener('click', startExam);

  $('#exam').addEventListener('change', () => {
    if (!exam) return;
    const current = exam.questions[exam.index];
    exam.answers[current.id] = readSelection($('#exam'));
  });

  window.UI = { show, renderHome, selectedDomains, seed, persist, getHistory: () => history };
  renderHome();
  show('home');
})();
