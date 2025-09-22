module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // Desabilitar validação de case para type e scope (será normalizado pelo parser)
    'type-case': [0],
    'scope-case': [0],
    // Subject pode ser case insensitive
    'subject-case': [0],

    // Tipos válidos (apenas lowercase)
    'type-enum': [
      2,
      'always',
      [
        'feat', // ✨ Nova funcionalidade
        'fix', // 🐛 Correção de bug
        'docs', // 📚 Documentação
        'style', // 💄 Formatação, sem mudança de código
        'refactor', // ♻️ Refatoração de código
        'perf', // ⚡ Melhoria de performance
        'test', // ✅ Adição ou correção de testes
        'build', // 🔧 Mudanças no sistema de build
        'ci', // 🚀 Mudanças na CI/CD
        'chore', // 🔧 Tarefas de manutenção
        'revert', // ⏪ Reverter commit anterior
      ],
    ],

    // Outras regras
    'type-empty': [2, 'never'],
    'subject-empty': [2, 'never'],
    'subject-full-stop': [2, 'never', '.'],
    'header-max-length': [2, 'always', 120], // 120 caracteres máximo
    'body-leading-blank': [1, 'always'],
    'footer-leading-blank': [1, 'always'],
  },
  // Parser customizado para suportar emojis e normalizar case
  parserPreset: {
    parserOpts: {
      headerPattern:
        /^(\p{Emoji})?\s*(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z0-9-]+\))?:\s(.+)$/iu,
      headerCorrespondence: ['emoji', 'type', 'scope', 'subject'],
      // Normalizar type e scope para lowercase
      transform: (commit) => {
        if (commit.type) {
          commit.type = commit.type.toLowerCase();
        }
        if (commit.scope) {
          commit.scope = commit.scope.toLowerCase();
        }
        return commit;
      },
    },
  },
};
