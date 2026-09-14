(() => {
  if (document.getElementById('ruphy-tools')) return;
  const snapshot = JSON.parse(document.currentScript.dataset.ruphyState);
  const host = document.createElement('aside');
  host.id = 'ruphy-tools';
  const root = host.attachShadow({ mode: 'open' });
  root.innerHTML = `
    <style>
      :host { position: fixed; right: 24px; bottom: 24px; z-index: 9999; font: 14px/1.5 system-ui, sans-serif; color: #24342b; }
      * { box-sizing: border-box; }
      button, input { font: inherit; }
      #mascot { display: block; margin-left: auto; border: 1px solid #bfd2c3; border-radius: 50%; width: 68px; height: 68px; background: white; cursor: pointer; box-shadow: 0 4px 20px #14342120; }
      #mascot img { width: 48px; height: 48px; object-fit: contain; }
      section { width: 300px; max-width: calc(100vw - 48px); margin-bottom: 12px; padding: 22px; border: 1px solid #cbd8cb; border-radius: 14px; background: #fff; box-shadow: 0 12px 50px #14342125; }
      h2 { margin: 0; font-size: 18px; }
      p { color: #627167; }
      label { display: block; margin: 16px 0 6px; font-weight: 600; }
      input { width: 100%; padding: 10px; border: 1px solid #b4c2b7; border-radius: 6px; }
      #apply { width: 100%; margin-top: 12px; padding: 10px; background: #276044; color: white; border: 0; border-radius: 6px; cursor: pointer; }
      #apply:disabled { opacity: .45; cursor: default; }
      output { display: block; margin-top: 12px; overflow-wrap: anywhere; }
      details { margin-top: 12px; font-size: 12px; }
      pre { white-space: pre-wrap; overflow-wrap: anywhere; max-height: 160px; overflow: auto; }
      [hidden] { display: none !important; }
    </style>
    <section hidden aria-label="Ruphino editor">
      <h2>Ruphino</h2>
      <p>Click the Name or Email field on this page to edit its placeholder.</p>
      <form>
        <label for="placeholder">Placeholder</label>
        <input id="placeholder" name="placeholder" maxlength="200" disabled>
        <button id="apply" disabled>Apply to Rails view</button>
      </form>
      <output role="status">Choose a field</output>
      <details hidden><summary>Last Herb diff</summary><pre></pre></details>
    </section>
    <button id="mascot" aria-label="Toggle Ruphino editor" aria-expanded="false"><img src="/__ruphy/ruphino.png" alt=""></button>`;
  document.body.appendChild(host);
  const panel = root.querySelector('section');
  const mascot = root.querySelector('#mascot');
  const input = root.querySelector('input');
  const apply = root.querySelector('#apply');
  const status = root.querySelector('output');
  let selected = null;
  let busy = false;
  const showChange = (change) => {
    root.querySelector('details').hidden = false;
    root.querySelector('pre').textContent = JSON.stringify(change.diff, null, 2);
  };
  if (snapshot.ok && snapshot.result.last_change) {
    showChange(snapshot.result.last_change);
    status.textContent = 'View saved and reloaded. Choose a field to continue.';
  } else if (!snapshot.ok) {
    status.textContent = snapshot.error;
  }
  mascot.addEventListener('click', () => {
    panel.hidden = !panel.hidden;
    mascot.setAttribute('aria-expanded', String(!panel.hidden));
  });
  document.addEventListener('click', (event) => {
    if (panel.hidden || !snapshot.ok || busy) return;
    const field = snapshot.result.fields.find((field) => event.target.id === field.id);
    if (!field) return;
    selected = field;
    input.disabled = false;
    input.value = field.placeholder;
    apply.disabled = false;
    status.textContent = `Selected ${event.target.labels?.[0]?.textContent || field.id}`;
    input.focus();
  });
  root.querySelector('form').addEventListener('submit', async (event) => {
    event.preventDefault();
    if (!selected || busy) return;
    busy = true;
    apply.disabled = true;
    status.textContent = 'Validating and saving…';
    try {
      const response = await fetch('/__ruphy/mutations', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          operation: 'set_placeholder', target: selected.id,
          value: input.value, revision: snapshot.result.revision,
        }),
      });
      const result = await response.json();
      if (!response.ok || !result.ok) throw new Error(result.error || 'Mutation failed');
      showChange(result.result.change);
      if (result.result.reload) window.location.reload();
      else status.textContent = 'Already saved; no source change needed.';
    } catch (error) {
      status.textContent = error.message;
    } finally {
      busy = false;
      apply.disabled = false;
    }
  });
})();
