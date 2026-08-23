const BANK = (function () {
  let registered = [];
  return {
    register(domain) {
      if (registered.some((d) => d.id === domain.id)) {
        throw new Error('duplicate domain id: ' + domain.id);
      }
      registered.push(domain);
    },
    domains() {
      return registered.slice();
    },
    all() {
      return registered.flatMap((d) => d.questions);
    },
    byDomain(id) {
      return registered.find((d) => d.id === id);
    },
    reset() {
      registered = [];
    },
  };
})();

if (typeof module !== 'undefined') module.exports = BANK;
if (typeof window !== 'undefined') window.BANK = BANK;
