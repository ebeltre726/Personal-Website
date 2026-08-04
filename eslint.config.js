import js from "@eslint/js";
import globals from "globals";

export default [
  {
    ignores: [
      "dist/",
      "node_modules/"
    ],
  },

  {
  files: ["infrastructure/lambda/**/*.js"],
  languageOptions: {
    globals: {
      ...globals.node,
    },
  },
  },

  {
    languageOptions: {
      globals: {
        ...globals.browser,
      },
    },
    rules: {
      ...js.configs.recommended.rules,
    },
  },
];