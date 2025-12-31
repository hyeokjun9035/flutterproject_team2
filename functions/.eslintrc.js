module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    "ecmaVersion": 2020,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
    "quotes": ["error", "double", {"allowTemplateLiterals": true}],
  },
  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {
     "linebreak-style": 0,
         "indent": 0,
         "object-curly-spacing": 0,
         "max-len": 0,
         "require-jsdoc": 0,
         "valid-jsdoc": 0,
         "quotes": 0,
         "comma-dangle": 0,
         "semi": 0,
         "no-unused-vars": "warn",
         "camelcase": 0,
         "one-var": 0,
         "brace-style": 0,
         "block-spacing": 0,
         "prefer-arrow-callback": 0,
         "no-restricted-globals": 0
      },
    },
  ],
  globals: {},
};
