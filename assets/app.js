const menuButton = document.querySelector('.menu-toggle');
menuButton?.addEventListener('click', () => document.body.classList.toggle('menu-open'));
document.addEventListener('keydown', event => {
  if (event.key === 'Escape') document.body.classList.remove('menu-open');
});
document.querySelector('.main-wrap')?.addEventListener('click', () => document.body.classList.remove('menu-open'));

document.querySelectorAll('form[data-confirm]').forEach(form => form.addEventListener('submit', event => {
  if (!confirm(form.dataset.confirm)) event.preventDefault();
}));

const toast = document.createElement('div');
toast.className = 'toast';
toast.setAttribute('role', 'status');
toast.setAttribute('aria-live', 'polite');
document.body.append(toast);
let toastTimer;
function showToast(message, error = false) {
  toast.textContent = message;
  toast.classList.toggle('error', error);
  toast.classList.add('visible');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove('visible'), 3200);
}

document.querySelector('.copy-link')?.addEventListener('click', async event => {
  try {
    await navigator.clipboard.writeText(window.location.href);
    showToast(event.currentTarget.dataset.copied);
  } catch {
    const input = document.createElement('input');
    input.value = window.location.href;
    document.body.append(input);
    input.select();
    document.execCommand('copy');
    input.remove();
    showToast(event.currentTarget.dataset.copied);
  }
});

const themeForm = document.querySelector('.theme-form');
themeForm?.addEventListener('submit', async event => {
  event.preventDefault();
  const button = themeForm.querySelector('button');
  const data = new FormData(themeForm);
  data.set('ajax', '1');
  button.disabled = true;
  try {
    const response = await fetch(themeForm.getAttribute('action'), {method:'POST', body:data, credentials:'same-origin'});
    if (!response.ok) throw Error('Failed');
    const result = await response.json();
    if (!result.ok) throw Error('Failed');
    document.documentElement.dataset.theme = result.theme;
    button.textContent = result.theme === 'dark' ? '☀' : '☾';
  } catch {
    themeForm.submit();
  } finally {
    button.disabled = false;
  }
});

const board = document.querySelector('.board');
if (board) {
  let dragging = null;
  const search = document.querySelector('#board-search');
  const items = [...board.querySelectorAll('[data-issue]')];
  const columns = [...board.querySelectorAll('.board-column')];

  function updateCounts() {
    let shown = 0;
    columns.forEach(column => {
      const visible = [...column.querySelectorAll('[data-issue]')].filter(item => !item.hidden).length;
      column.querySelector('.board-head span').textContent = visible;
      shown += visible;
    });
    document.querySelector('.board-no-results').hidden = shown > 0;
  }

  search?.addEventListener('input', () => {
    const term = search.value.trim().toLocaleLowerCase();
    items.forEach(item => { item.hidden = !item.dataset.search.includes(term); });
    updateCounts();
  });

  async function move(item, status) {
    const previousColumn = item.closest('.board-column');
    const destination = board.querySelector(`.board-column[data-status="${status}"]`);
    if (!destination || previousColumn === destination) return;
    const previousNext = item.nextElementSibling;
    const previousStatus = previousColumn.dataset.status;
    destination.querySelector('.board-cards').prepend(item);
    item.querySelector('.board-status').value = status;
    item.classList.add('moving');
    updateCounts();

    const data = new FormData();
    data.set('csrf', board.dataset.csrf);
    data.set('action', 'issue_status');
    data.set('issue_id', item.dataset.issue);
    data.set('status', status);
    data.set('ajax', '1');
    try {
      const response = await fetch(board.dataset.url, {method:'POST', body:data, credentials:'same-origin'});
      if (!response.ok || !(await response.json()).ok) throw Error('Failed');
      showToast(board.dataset.saved);
    } catch {
      previousColumn.querySelector('.board-cards').insertBefore(item, previousNext);
      item.querySelector('.board-status').value = previousStatus;
      updateCounts();
      showToast(board.dataset.error, true);
    } finally {
      setTimeout(() => item.classList.remove('moving'), 250);
    }
  }

  items.forEach(item => {
    item.addEventListener('dragstart', event => {
      if (event.target.closest('select')) { event.preventDefault(); return; }
      dragging = item;
      item.classList.add('dragging');
      event.dataTransfer.effectAllowed = 'move';
      event.dataTransfer.setData('text/plain', item.dataset.issue);
    });
    item.addEventListener('dragend', () => { item.classList.remove('dragging'); dragging = null; });
    item.querySelector('.board-status').addEventListener('change', event => move(item, event.target.value));
  });
  columns.forEach(column => {
    column.addEventListener('dragover', event => { event.preventDefault(); column.classList.add('drop-target'); });
    column.addEventListener('dragleave', event => {
      if (!column.contains(event.relatedTarget)) column.classList.remove('drop-target');
    });
    column.addEventListener('drop', event => {
      event.preventDefault(); column.classList.remove('drop-target');
      if (dragging) move(dragging, column.dataset.status);
    });
  });
}
