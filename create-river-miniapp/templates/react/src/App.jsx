import { useState } from 'react';

export default function App() {
  const [output, setOutput] = useState('等待操作...');

  const callBridge = async (action, payload = {}) => {
    if (!window.RiverMiniApp || typeof window.RiverMiniApp.call !== 'function') {
      setOutput(
        JSON.stringify(
          { ok: false, message: 'Bridge 未注入，当前为普通浏览器模式。' },
          null,
          2,
        ),
      );
      return;
    }
    try {
      const result = await window.RiverMiniApp.call(action, payload);
      setOutput(JSON.stringify({ ok: true, result }, null, 2));
    } catch (error) {
      setOutput(JSON.stringify({ ok: false, message: String(error) }, null, 2));
    }
  };

  return (
    <main className="container">
      <section className="card">
        <h1>{{APP_NAME}}</h1>
        <p>模板：React · 项目：{{PROJECT_NAME}}</p>
        <div className="actions">
          <button type="button" onClick={() => callBridge('getContext')}>
            获取上下文
          </button>
          <button
            type="button"
            onClick={() => callBridge('setTitle', { title: '{{APP_NAME}} 已连接' })}
          >
            修改标题
          </button>
          <button type="button" onClick={() => callBridge('close')}>
            关闭小程序
          </button>
        </div>
        <pre>{output}</pre>
      </section>
    </main>
  );
}
