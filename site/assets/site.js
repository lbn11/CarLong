(function () {
  var KEY = 'mf_site_lang';
  var root = document.documentElement;
  var btn = document.getElementById('langBtn');

  function apply(lang) {
    root.setAttribute('data-lang', lang);
    root.setAttribute('lang', lang === 'zh' ? 'zh-CN' : 'en');
    if (btn) btn.textContent = lang === 'zh' ? 'English' : '中文';
    try { localStorage.setItem(KEY, lang); } catch (e) {}
  }

  var saved = null;
  try { saved = localStorage.getItem(KEY); } catch (e) {}
  var prefersZh = (navigator.language || '').toLowerCase().indexOf('zh') === 0;
  apply(saved || (prefersZh ? 'zh' : 'en'));

  if (btn) {
    btn.addEventListener('click', function () {
      apply(root.getAttribute('data-lang') === 'zh' ? 'en' : 'zh');
    });
  }
})();
