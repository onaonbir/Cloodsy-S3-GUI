import { createApp } from 'vue';
import SetupApp from './SetupApp.vue';
import './setup.css';

// The window follows the system theme (the app's own setting is not known here).
const dark = window.matchMedia('(prefers-color-scheme: dark)');
const applyTheme = () => (document.documentElement.dataset.theme = dark.matches ? 'dark' : 'light');
applyTheme();
dark.addEventListener('change', applyTheme);

createApp(SetupApp).mount('#app');
