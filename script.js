let barsAnimated = false;

const observer = new IntersectionObserver((entries, observer) => {
    entries.forEach(entry => {
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
        } else {
            entry.target.classList.remove('visible');
        }
    });
}, { threshold: 0.5 });

document.querySelectorAll('section').forEach(section => {
    observer.observe(section);
});

function showSidebar(){
    const sidebar = document.querySelector('.sidebar');
    sidebar.classList.add('expanded');
    sidebar.style.borderLeft = 'solid rgba(0, 0, 0, 1)';
}

function hideSidebar(){
    const sidebar = document.querySelector('.sidebar');
    sidebar.classList.remove('expanded');
    sidebar.style.borderLeft = 'none';
}

document.getElementById('contactForm').addEventListener('submit', async function(event) {
    event.preventDefault();

    const formData = {
        first: document.getElementById('first').value,
        last: document.getElementById('last').value,
        email: document.getElementById('email').value,
        message: document.getElementById('message').value,
    };

    try {
        const response = await fetch('https://i4ps8dx5qc.execute-api.us-east-1.amazonaws.com/', {
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