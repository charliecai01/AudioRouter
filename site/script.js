// Scroll-reveal. Only opt into the hidden-until-scrolled-into-view styling once
// we can actually guarantee the reveal will happen — otherwise a slow or failed
// script load would leave whole sections invisible forever.
if ('IntersectionObserver' in window) {
  document.documentElement.classList.add('js-reveal');

  const revealEls = document.querySelectorAll('.reveal');
  const io = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (entry.isIntersecting) {
        entry.target.classList.add('in');
        io.unobserve(entry.target);
      }
    }
  }, { threshold: 0.15 });
  revealEls.forEach((el) => io.observe(el));

  // Belt and suspenders: if for any reason an element never intersects
  // (e.g. it's shorter than the viewport margin math expects), don't leave
  // it invisible forever.
  setTimeout(() => {
    document.querySelectorAll('.reveal:not(.in)').forEach((el) => el.classList.add('in'));
  }, 2500);
}
