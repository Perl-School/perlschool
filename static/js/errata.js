(() => {
  const form = document.getElementById('errataReportForm');
  if (!form || !window.fetch) return;

  const status = document.getElementById('errataReportStatus');
  const submit = form.querySelector('button[type="submit"]');
  const label = submit.textContent;
  let sending = false;

  const showStatus = (message, type) => {
    status.className = `alert alert-${type}`;
    status.textContent = message;
  };

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (sending) return;

    sending = true;
    submit.disabled = true;
    submit.textContent = 'Sending…';
    form.setAttribute('aria-busy', 'true');
    showStatus('Sending your report…', 'info');

    try {
      const response = await fetch(form.action, {
        method: form.method,
        body: new FormData(form),
        headers: { Accept: 'application/json' },
      });

      if (response.ok) {
        form.reset();
        showStatus('Thank you. Your report has been sent and will be reviewed before it appears here.', 'success');
      } else {
        let message = response.status === 429
          ? 'Too many reports have been submitted. Please wait a few minutes and try again.'
          : 'We could not send your report. Please try again, or email hello@perlschool.com.';

        try {
          const data = await response.json();
          if (Array.isArray(data.errors)) {
            const messages = data.errors
              .map(error => error && error.message)
              .filter(message => typeof message === 'string' && message.trim());
            if (messages.length && response.status !== 429) message = messages.join(' ');
          }
        } catch {
          // Keep the fallback message if the service returns a non-JSON error.
        }

        showStatus(message, 'danger');
      }
    } catch {
      showStatus('We could not confirm your report was sent. Please check your connection and try again, or email hello@perlschool.com.', 'danger');
    } finally {
      sending = false;
      submit.disabled = false;
      submit.textContent = label;
      form.removeAttribute('aria-busy');
      status.focus();
    }
  });
})();
