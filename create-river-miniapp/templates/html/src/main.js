import './style.css';

const app = document.querySelector('#app');

const callBridge = async (action, payload = {}) => {
  if (!window.RiverMiniApp || typeof window.RiverMiniApp.call !== 'function') {
    return { ok: false, message: 'Bridge 未注入，当前为普通浏览器模式。' };
  }
  try {
    const result = await window.RiverMiniApp.call(action, payload);
    return { ok: true, result };
  } catch (error) {
    return { ok: false, message: String(error) };
  }
};

app.innerHTML = `
  <main class="container">
    <section class="card">
      <h1>{{APP_NAME}}</h1>
      <p>模板：HTML · 项目：{{PROJECT_NAME}}</p>
      <div class="actions">
        <button id="btn-context">获取上下文</button>
        <button id="btn-title">修改标题</button>
        <button id="btn-close">关闭小程序</button>
      </div>
      <pre id="output">等待操作...</pre>
    </section>
  </main>
`;

const output = document.querySelector('#output');
document.querySelector('#btn-context').addEventListener('click', async () => {
  const data = await callBridge('getContext');
  output.textContent = JSON.stringify(data, null, 2);
});
document.querySelector('#btn-title').addEventListener('click', async () => {
  const data = await callBridge('setTitle', { title: '{{APP_NAME}} 已连接' });
  output.textContent = JSON.stringify(data, null, 2);
});
document.querySelector('#btn-close').addEventListener('click', async () => {
  const data = await callBridge('close');
  output.textContent = JSON.stringify(data, null, 2);
});
