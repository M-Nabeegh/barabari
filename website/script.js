// Scroll reveal
const revealer = new IntersectionObserver((entries) => {
  for (const entry of entries) {
    if (entry.isIntersecting) {
      entry.target.classList.add('in');
      revealer.unobserve(entry.target);
    }
  }
}, { threshold: 0.15, rootMargin: '0px 0px -40px 0px' });
document.querySelectorAll('[data-reveal]').forEach((el) => revealer.observe(el));

// Gentle 3D tilt on the hero phones
const stack = document.getElementById('phoneStack');
const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
if (stack && !reduceMotion && window.matchMedia('(pointer: fine)').matches) {
  window.addEventListener('pointermove', (event) => {
    const x = event.clientX / window.innerWidth - 0.5;
    const y = event.clientY / window.innerHeight - 0.5;
    stack.style.transform = `perspective(1200px) rotateY(${x * 8}deg) rotateX(${-y * 6}deg)`;
  });
}

// Live split demo — same rule as the app: equal shares, remainder paisa go to the first people.
const amountInput = document.getElementById('demoAmount');
const eachEl = document.getElementById('demoEach');
const splitsEl = document.getElementById('demoSplits');
const people = [...document.querySelectorAll('.person')];
const format = (minor) => {
  const whole = Math.floor(minor / 100);
  const paisa = minor % 100;
  return whole.toLocaleString('en-PK') + (paisa ? '.' + String(paisa).padStart(2, '0') : '');
};

let shown = 0;
function animateNumber(target) {
  const start = shown;
  const began = performance.now();
  const duration = reduceMotion ? 0 : 450;
  const step = (now) => {
    const t = duration ? Math.min(1, (now - began) / duration) : 1;
    const eased = 1 - Math.pow(1 - t, 3);
    const value = Math.round(start + (target - start) * eased);
    eachEl.textContent = format(value);
    if (t < 1) requestAnimationFrame(step);
    else shown = target;
  };
  requestAnimationFrame(step);
}

function renderSplit() {
  const digits = amountInput.value.replace(/[^\d]/g, '').slice(0, 9);
  if (amountInput.value !== digits) amountInput.value = digits;
  const totalMinor = (parseInt(digits || '0', 10)) * 100;
  const chosen = people.filter((p) => p.classList.contains('on'));
  const count = Math.max(chosen.length, 1);
  const base = Math.floor(totalMinor / count);
  let remainder = totalMinor - base * count;
  const shares = chosen.map(() => base + (remainder-- > 0 ? 1 : 0));
  animateNumber(chosen.length ? shares[0] : 0);
  splitsEl.innerHTML = chosen.map((person, index) => {
    const style = person.getAttribute('style');
    const width = totalMinor ? Math.max(4, (shares[index] / totalMinor) * 100) : 0;
    return `<li style="animation-delay:${index * 50}ms">
      <span class="av" style="${style}">${person.textContent.trim()}</span>
      <div><div class="nm">${person.dataset.name}</div><div class="bar"><i style="width:${width}%"></i></div></div>
      <span class="amt">Rs ${format(shares[index])}</span>
    </li>`;
  }).join('');
}

people.forEach((person) => {
  person.setAttribute('aria-pressed', person.classList.contains('on'));
  person.setAttribute('aria-label', person.dataset.name);
  person.addEventListener('click', () => {
    const active = people.filter((p) => p.classList.contains('on'));
    if (person.classList.contains('on') && active.length === 1) return; // keep at least one person
    person.classList.toggle('on');
    person.setAttribute('aria-pressed', person.classList.contains('on'));
    renderSplit();
  });
});
amountInput.addEventListener('input', renderSplit);
renderSplit();

document.getElementById('year').textContent = new Date().getFullYear();
