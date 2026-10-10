/* Dashboard favorites for DVSwitch Mode Buttons. */
(function () {
  'use strict';
  document.addEventListener('DOMContentLoaded', function () {
    const root = document.getElementById('dvs-favorites');
    const modeButtons = document.querySelectorAll('#dvs-mode-buttons button');
    const tuner = document.getElementById('dvs-target-tuner');
    const input = document.getElementById('dvs-target-input');
    const tuneButton = document.getElementById('dvs-target-submit');
    const addFavoriteButton = root.querySelector('.dvs-favorites-add-current');
    const tuneStatus = document.getElementById('dvs-target-message');
    if (!root || !tuner || !input) return;

    const controlLine = root.querySelector('.dvs-favorites-control-line');
    const rxButton = Array.from(document.querySelectorAll('button')).find(function (button) {
      return button.textContent.replace(/\s+/g, ' ').trim().includes('RX Monitor');
    });
    if (controlLine && rxButton) {
      const oldContainer = rxButton.parentElement;
      rxButton.classList.add('dvs-rx-monitor-inline');
      controlLine.insertBefore(rxButton, controlLine.firstChild);
      if (oldContainer && oldContainer !== controlLine && oldContainer.tagName === 'DIV' && !oldContainer.textContent.trim()) oldContainer.remove();
    }

    const favoriteSelect = root.querySelector('.dvs-favorites-select');
    const status = root.querySelector('.dvs-favorites-status');
    const editButton = root.querySelector('.dvs-favorites-edit');
    const editor = root.querySelector('.dvs-favorites-editor');
    const selector = root.querySelector('.dvs-favorites-mode');
    const rows = root.querySelector('.dvs-favorites-rows');
    let activeMode = '';
    let editing = [];

    function validMode(mode) {
      return ['BM', 'TGIF', 'STFU', 'YSF', 'P25', 'NXDN', 'DSTAR'].includes(mode);
    }

    async function load(mode) {
      if (!validMode(mode)) return [];
      const response = await fetch('/dvswitch/dvswitch-mode-buttons.php?favorites=' + encodeURIComponent(mode), { cache: 'no-store' });
      const result = await response.json();
      if (!response.ok || !result.ok || !Array.isArray(result.favorites)) throw new Error(result.error || 'Unable to load favorites.');
      return result.favorites;
    }

    function setActive(mode, network) {
      activeMode = mode === 'DMR' ? (network || '') : mode;
      modeButtons.forEach(function (button) {
        button.classList.toggle('selected', button.dataset.mode === activeMode);
      });
      root.hidden = !validMode(activeMode);
      if (!editor.hidden) return;
      showFavorites();
    }

    async function showFavorites() {
      favoriteSelect.replaceChildren(new Option('Select favorite', ''));
      status.textContent = '';
      if (!validMode(activeMode)) return;
      try {
        const favorites = await load(activeMode);
        favorites.forEach(function (favorite) {
          if (!favorite || typeof favorite.name !== 'string' || typeof favorite.target !== 'string') return;
          const option = document.createElement('option');
          option.value = favorite.target;
          option.textContent = favorite.name + ' (' + favorite.target + ')';
          favoriteSelect.appendChild(option);
        });
      } catch (error) {
        status.textContent = error.message;
      }
    }

    favoriteSelect.addEventListener('change', function () {
      if (!favoriteSelect.value) return;
      input.value = favoriteSelect.value;
      tuner.requestSubmit();
      favoriteSelect.value = '';
    });

    function makeRow(favorite) {
      const row = document.createElement('div');
      row.className = 'dvs-favorite-edit-row';
      const name = document.createElement('input');
      name.type = 'text'; name.maxLength = 32; name.value = favorite.name || '';
      name.placeholder = 'Favorite name'; name.setAttribute('aria-label', 'Favorite name');
      const target = document.createElement('input');
      target.type = 'text'; target.maxLength = 32; target.value = favorite.target || '';
      target.placeholder = 'TG / reflector ID'; target.setAttribute('aria-label', 'Talkgroup or reflector ID');
      const remove = document.createElement('button');
      remove.type = 'button'; remove.className = 'button link'; remove.textContent = 'Delete';
      remove.addEventListener('click', function () { row.remove(); });
      row.append(name, target, remove);
      rows.appendChild(row);
    }

    async function loadEditorMode() {
      rows.replaceChildren();
      status.textContent = '';
      try {
        editing = await load(selector.value);
        editing.forEach(makeRow);
      } catch (error) {
        status.textContent = error.message;
      }
    }

    function enterEdit() {
      selector.value = validMode(activeMode) ? activeMode : 'BM';
      editor.hidden = false;
      editButton.textContent = 'Close Edit';
      loadEditorMode();
    }

    async function addCurrentTargetToFavorites() {
      const target = input.value.trim();
      if (!validMode(activeMode)) {
        status.textContent = 'Select a mode before adding a favorite.';
        return;
      }
      if (!/^[A-Za-z0-9_-]{1,32}$/.test(target)) {
        tuneStatus.textContent = 'Enter a valid ID before adding it to Favorites.';
        input.focus();
        return;
      }
      selector.value = activeMode;
      editor.hidden = false;
      editButton.textContent = 'Close Edit';
      status.textContent = '';
      try {
        editing = await load(selector.value);
        rows.replaceChildren();
        editing.forEach(makeRow);
        if (editing.length >= 30) {
          status.textContent = 'A mode can have up to 30 favorites.';
          return;
        }
        makeRow({ name: '', target: target });
        rows.lastElementChild.children[0].focus();
        status.textContent = 'Name the favorite, then select Save.';
      } catch (error) {
        status.textContent = error.message;
      }
    }

    function closeEdit() {
      editor.hidden = true;
      editButton.textContent = 'Edit';
      showFavorites();
    }

    editButton.addEventListener('click', function () {
      if (editor.hidden) enterEdit(); else closeEdit();
    });
    addFavoriteButton.addEventListener('click', addCurrentTargetToFavorites);
    selector.addEventListener('change', loadEditorMode);
    root.querySelector('.dvs-favorites-add').addEventListener('click', function () {
      if (rows.children.length < 30) makeRow({ name: '', target: '' });
      else status.textContent = 'A mode can have up to 30 favorites.';
    });
    root.querySelector('.dvs-favorites-cancel').addEventListener('click', closeEdit);
    root.querySelector('.dvs-favorites-save').addEventListener('click', async function () {
      const favorites = Array.from(rows.querySelectorAll('.dvs-favorite-edit-row')).map(function (row) {
        return { name: row.children[0].value.trim(), target: row.children[1].value.trim() };
      });
      if (favorites.some(function (favorite) { return !favorite.name || !/^[A-Za-z0-9_-]{1,32}$/.test(favorite.target); })) {
        status.textContent = 'Enter a name and a valid TG / reflector ID for each favorite.';
        return;
      }
      try {
        const response = await fetch('/dvswitch/dvswitch-mode-buttons.php', {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ mode: selector.value, favorites: favorites })
        });
        const result = await response.json();
        if (!response.ok || !result.ok) throw new Error(result.error || 'Unable to save favorites.');
        status.textContent = result.message || 'Favorites saved.';
        if (selector.value === activeMode) showFavorites();
      } catch (error) {
        status.textContent = error.message;
      }
    });

    selector.innerHTML = '<option value="BM">BM</option><option value="TGIF">TGIF</option><option value="STFU">STFU</option><option value="YSF">YSF</option><option value="P25">P25</option><option value="NXDN">NXDN</option><option value="DSTAR">D-Star</option>';
    modeButtons.forEach(function (button) {
      button.addEventListener('click', async function () {
        modeButtons.forEach(function (item) { item.disabled = true; });
        try {
          const response = await fetch('/dvswitch/dvswitch-mode-buttons.php?mode=' + encodeURIComponent(button.dataset.mode));
          const result = await response.json();
          if (!response.ok || !result.ok) throw new Error(result.output || result.error || 'Mode switch failed.');
          setActive(result.mode, result.network);
          tuneStatus.textContent = '';
        } catch (error) {
          window.alert('Mode switch failed: ' + error.message);
        } finally {
          modeButtons.forEach(function (item) { item.disabled = false; });
        }
      });
    });
    tuner.addEventListener('submit', async function (event) {
      event.preventDefault();
      const target = input.value.trim();
      tuneStatus.textContent = '';
      if (!/^[A-Za-z0-9_-]{1,32}$/.test(target)) {
        tuneStatus.textContent = 'Enter a valid ID.';
        return;
      }
      tuneButton.disabled = true;
      input.disabled = true;
      try {
        const response = await fetch('/dvswitch/dvswitch-mode-buttons.php', {
          method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ target: target })
        });
        const result = await response.json();
        if (!response.ok || !result.ok) throw new Error(result.error || 'Tune failed.');
        tuneStatus.textContent = 'Tuned ' + target + ' (' + result.mode + ')';
      } catch (error) {
        tuneStatus.textContent = error.message;
      } finally {
        tuneButton.disabled = false;
        input.disabled = false;
        input.focus();
      }
    });
    let attempts = 0;
    async function refreshMode() {
      try {
        const response = await fetch('/dvswitch/dvswitch-mode-buttons.php?status=1', { cache: 'no-store' });
        const result = await response.json();
        if (result.ok) setActive(result.mode, result.network);
      } catch (error) {}
      if (attempts++ < 4) window.setTimeout(refreshMode, 1500);
    }
    refreshMode();
  });
})();
