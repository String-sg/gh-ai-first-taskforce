import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';
import reactPlugin from 'eslint-plugin-react';
import globals from 'globals';
import prettier from 'eslint-config-prettier';

export default tseslint.config(
  { ignores: ['**/build/**', '**/dist/**', '**/node_modules/**'] },
  { languageOptions: { globals: { ...globals.browser, ...globals.node } } },
  eslint.configs.recommended,
  ...tseslint.configs.recommended,
  { plugins: { react: reactPlugin }, rules: { 'no-console': 'warn' } },
  prettier, // must be last — disables ESLint formatting rules that conflict with oxfmt
);
