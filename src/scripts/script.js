const API_BASE_URL = import.meta.env.VITE_API_URL;
let barsAnimated = false;

const observer = new IntersectionObserver(
  (entries, observer) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        observer.unobserve(entry.target);
        if (entry.target.querySelector('#profGrid') && !barsAnimated) {
          barsAnimated = true;
          entry.target.querySelectorAll('.bar-fill').forEach((bar, i) => {
            bar.style.transitionDelay = `${i * 0.08}s`;
            setTimeout(() => bar.classList.add('animated'), 400); // wait for section fade-in
          });
        }

        if (entry.target.querySelector('.work-grid')) {
          entry.target.querySelectorAll('.project-card').forEach((card, i) => {
            setTimeout(() => card.classList.add('visible'), i * 100);
          });
        }
      } else {
        entry.target.classList.remove('visible');
      }
    });
  },
  { threshold: 0.25 },
);

document.querySelectorAll('section').forEach((section) => {
  observer.observe(section);
});

document.querySelectorAll('.video-wrapper').forEach((wrapper) => {
  const videoId = wrapper.dataset.videoId;
  const videoUrl = wrapper.dataset.videoUrl || `https://www.youtube.com/watch?v=${videoId || ''}`;

  if (!videoId && !wrapper.dataset.videoUrl) return;

  wrapper.setAttribute('role', 'link');
  wrapper.setAttribute('tabindex', '0');
  wrapper.style.cursor = 'pointer';

  const openVideo = (event) => {
    if (event.type === 'keydown' && !['Enter', ' '].includes(event.key)) return;
    if (event.type === 'keydown') event.preventDefault();
    window.open(videoUrl, '_blank', 'noopener,noreferrer');
  };

  wrapper.addEventListener('click', openVideo);
  wrapper.addEventListener('keydown', openVideo);
});

document.getElementById('contactForm').addEventListener('submit', async function (event) {
  event.preventDefault();

  const formData = {
    first: document.getElementById('first').value,
    last: document.getElementById('last').value,
    email: document.getElementById('email').value,
    message: document.getElementById('message').value,
  };

  try {
    const response = await fetch(`${API_BASE_URL}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(formData),
    });

    const result = await response.json();
    if (response.ok) {
      alert('Message sent successfully!');
    } else {
      alert('Error: ' + result.message);
    }
  } catch (error) {
    console.error('Error:', error);
    alert('There was an error sending your message.');
  }
});
