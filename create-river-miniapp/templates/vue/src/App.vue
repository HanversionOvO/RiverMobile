<script setup>
import { ref } from 'vue';

const output = ref('等待操作...');

const callBridge = async (action, payload = {}) => {
  if (!window.RiverMiniApp || typeof window.RiverMiniApp.call !== 'function') {
    output.value = JSON.stringify(
      { ok: false, message: 'Bridge 未注入，当前为普通浏览器模式。' },
      null,
      2,
    );
    return;
  }
  try {
    const result = await window.RiverMiniApp.call(action, payload);
    output.value = JSON.stringify({ ok: true, result }, null, 2);
  } catch (error) {
    output.value = JSON.stringify({ ok: false, message: String(error) }, null, 2);
  }
};
</script>

<template>
  <main class="container">
    <section class="card">
      <h1>{{APP_NAME}}</h1>
      <p>模板：Vue · 项目：{{PROJECT_NAME}}</p>
      <div class="actions">
        <button type="button" @click="callBridge('getContext')">获取上下文</button>
        <button type="button" @click="callBridge('setTitle', { title: '{{APP_NAME}} 已连接' })">
          修改标题
        </button>
        <button type="button" @click="callBridge('close')">关闭小程序</button>
      </div>
      <pre>{{ output }}</pre>
    </section>
  </main>
</template>
